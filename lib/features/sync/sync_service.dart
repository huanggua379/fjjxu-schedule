import '../../data/local/settings_store.dart';
import '../../data/network/api_exception.dart';
import '../../data/repositories/grade_repository.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/entities/entities.dart';
import '../reminder/reminder_service.dart';

/// 一次同步的结果
class SyncResult {
  final bool success;
  final ScheduleDiff diff;
  final List<Grade> newGrades;
  final DateTime? syncedAt;
  final String? errorMessage; // 友好错误信息（失败时）
  final bool usedCache; // 失败时是否回退到缓存

  const SyncResult({
    this.success = false,
    this.diff = const ScheduleDiff(),
    this.newGrades = const [],
    this.syncedAt,
    this.errorMessage,
    this.usedCache = false,
  });
}

/// 同步服务：统一编排“课表 + 成绩”刷新，供手动刷新、启动检查、
/// WorkManager 后台任务复用。失败绝不清空旧数据。
class SyncService {
  SyncService({
    required ScheduleRepository scheduleRepo,
    required GradeRepository gradeRepo,
    required SettingsStore settings,
    required ReminderService reminders,
  })  : _scheduleRepo = scheduleRepo,
        _gradeRepo = gradeRepo,
        _settings = settings,
        _reminders = reminders;

  final ScheduleRepository _scheduleRepo;
  final GradeRepository _gradeRepo;
  final SettingsStore _settings;
  final ReminderService _reminders;

  /// 执行完整同步。[includeGrades] 控制是否同时查成绩。
  Future<SyncResult> sync({
    required Semester semester,
    bool includeGrades = true,
    bool rescheduleReminders = true,
  }) async {
    ScheduleDiff diff = const ScheduleDiff();
    var newGrades = <Grade>[];
    try {
      // 1) 课表
      diff = await _scheduleRepo.refresh(semester);

      // 2) 成绩
      if (includeGrades) {
        try {
          newGrades = await _gradeRepo.refresh();
        } catch (_) {
          // 成绩失败不影响课表同步成功
        }
      }

      // 3) 记录同步时间
      final now = DateTime.now();
      await _settings.setLastSync(now);

      // 4) 重新排程提醒（去重由 ReminderService 保证）
      if (rescheduleReminders) {
        await _reminders.rescheduleAll(semester);
      }

      return SyncResult(success: true, diff: diff, newGrades: newGrades, syncedAt: now);
    } on AppException catch (e) {
      return SyncResult(
        success: false,
        errorMessage: e.message,
        usedCache: true, // 旧数据仍在本地
      );
    } catch (e) {
      return const SyncResult(
        success: false,
        errorMessage: '同步失败，正在使用上次保存的数据',
        usedCache: true,
      );
    }
  }

  /// 判断是否到达自动更新间隔（App 启动/回前台时调用）。
  Future<bool> shouldAutoSync(AppSettings s) async {
    if (!s.autoSync || s.syncIntervalMinutes <= 0) return false;
    final last = s.lastSyncTime;
    if (last == null) return true;
    final elapsed = DateTime.now().difference(last).inMinutes;
    return elapsed >= s.syncIntervalMinutes;
  }
}
