import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../app/providers.dart';

/// 后台周期同步（WorkManager）。
///
/// 采用系统级 WorkManager 而非 Timer：进程被杀仍能按周期唤醒，
/// 并遵守 Doze/网络约束。回调运行在独立 isolate，需自建 ProviderContainer，
/// 不能复用前台的 ref。
class BackgroundSync {
  BackgroundSync._();

  /// 前台启动时注册周期任务。周期由设置里的 syncIntervalMinutes 决定，
  /// 关闭自动同步或间隔<=0 时取消任务。
  static Future<void> register() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  /// 根据当前设置刷新周期任务（登录成功、修改设置后调用）。
  static Future<void> reschedule({
    required bool enabled,
    required int intervalMinutes,
  }) async {
    if (!enabled || intervalMinutes <= 0) {
      await Workmanager().cancelByUniqueName(_uniqueName);
      return;
    }
    // WorkManager 周期任务最小间隔 15 分钟
    final freq = Duration(minutes: intervalMinutes < 15 ? 15 : intervalMinutes);
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      _taskName,
      frequency: freq,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      initialDelay: const Duration(minutes: 1),
    );
  }

  static const _uniqueName = 'kebenPeriodicSync';
  static const _taskName = 'syncScheduleAndGrades';
}

/// WorkManager 回调分发器（必须为顶层函数）。
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final container = ProviderContainer();
    try {
      // 后台 isolate 内独立初始化基础设施
      await container.read(networkClientProvider).init();
      await container.read(reminderServiceProvider).init();
      await container.read(settingsControllerProvider.notifier).load();

      final settings = container.read(settingsControllerProvider);
      final loggedIn = await container.read(settingsStoreProvider).isLoggedIn();
      if (!loggedIn) return true; // 未登录，静默跳过

      // 确保会话有效（失效则用安全存储里的凭证静默重登）
      final sessionOk = await container.read(authRepositoryProvider).restoreSession();
      if (!sessionOk) return true; // 凭证失效，等待用户前台重新登录

      final sem = container.read(currentSemesterProvider);
      final result = await container.read(syncServiceProvider).sync(
            semester: sem,
            includeGrades: settings.autoQueryGrade,
          );

      // 新成绩提醒（去重由 SyncService/GradeRepository 保证：仅新出现的）
      if (result.success && settings.gradeNotify && result.newGrades.isNotEmpty) {
        await container.read(reminderServiceProvider).notifyNewGrades(result.newGrades);
      }
      return true;
    } catch (e, s) {
      // 后台任务绝不把堆栈暴露给用户；仅记录到调试日志
      debugPrint('[BackgroundSync] failed: $e\n$s');
      return false; // 交由 WorkManager 按其退避策略重试
    } finally {
      container.dispose();
    }
  });
}
