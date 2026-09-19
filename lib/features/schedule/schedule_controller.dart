import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/entities.dart';
import '../sync/sync_service.dart';

/// 当前学期“可见课表”（已过滤隐藏）。缓存优先，网络刷新后更新。
class ScheduleController extends AutoDisposeFamilyAsyncNotifier<List<ScheduleEntry>, Semester> {
  @override
  Future<List<ScheduleEntry>> build(Semester arg) async {
    final repo = ref.read(scheduleRepositoryProvider);
    final week = ref.watch(currentWeekProvider);
    // 先读缓存（离线可用）
    final cached = await repo.getVisibleSchedule(arg);
    if (cached.isNotEmpty) {
      // 异步返回缓存，立即可用
      Future.microtask(() {});
      return repo.applyHidden(cached, currentWeek: week);
    }
    return repo.applyHidden(cached, currentWeek: week);
  }

  /// 手动/自动刷新：拉取服务器数据，返回同步结果（含差异/新成绩）。
  /// 失败不清空本地数据，仅返回错误信息。
  Future<SyncResult> refresh({bool includeGrades = true}) async {
    final sync = ref.read(syncServiceProvider);
    final result = await sync.sync(semester: arg, includeGrades: includeGrades);
    if (result.success) {
      final repo = ref.read(scheduleRepositoryProvider);
      final week = ref.read(currentWeekProvider);
      final fresh = await repo.getVisibleSchedule(arg);
      state = AsyncData(await repo.applyHidden(fresh, currentWeek: week));
      // 同步成功后刷新设置里的 lastSync
      final sc = ref.read(settingsControllerProvider.notifier);
      await sc.load();
    }
    return result;
  }

  /// 隐藏/恢复操作后刷新本地可见列表（不联网）。
  Future<void> reloadLocal() async {
    final repo = ref.read(scheduleRepositoryProvider);
    final week = ref.read(currentWeekProvider);
    final all = await repo.getRawSchedule(arg);
    state = AsyncData(await repo.applyHidden(all, currentWeek: week));
  }
}

final scheduleControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ScheduleController, List<ScheduleEntry>, Semester>(
        ScheduleController.new);

/// 周课表页面当前选中的周次（默认当前周）。
class SelectedWeekNotifier extends Notifier<int> {
  @override
  int build() => ref.watch(currentWeekProvider) ?? 1;

  void set(int w) => state = w.clamp(0, 30);
  void next() => state = (state + 1).clamp(0, 30);
  void prev() => state = (state - 1).clamp(0, 30);
  void backToCurrent() => state = ref.read(currentWeekProvider) ?? 1;
}

final selectedWeekProvider =
    NotifierProvider<SelectedWeekNotifier, int>(SelectedWeekNotifier.new);

/// 今日课程（按当前周过滤 + 排序）。
final todayClassesProvider = Provider<List<ScheduleEntry>>((ref) {
  final sem = ref.watch(currentSemesterProvider);
  final entries = ref.watch(scheduleControllerProvider(sem)).valueOrNull ?? [];
  final week = ref.watch(currentWeekProvider);
  final now = DateTime.now();
  final todayWeekday = now.weekday; // 1..7
  final list = entries.where((e) {
    if (e.weekday != todayWeekday) return false;
    if (week != null && e.weeks.isNotEmpty && !e.weeks.contains(week)) return false;
    return true;
  }).toList()
    ..sort((a, b) => a.startSection.compareTo(b.startSection));
  return list;
});
