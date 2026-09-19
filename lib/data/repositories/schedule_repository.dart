import '../../domain/entities/entities.dart';
import '../local/app_database.dart';
import '../remote/schedule_remote.dart';

/// 一次同步的差异结果（用于“课程信息发生变化”提示）。
class ScheduleDiff {
  final List<String> added; // 新增课程名
  final List<String> removed; // 删除课程名
  final List<String> changed; // 教室/教师/时间变化描述
  const ScheduleDiff({
    this.added = const [],
    this.removed = const [],
    this.changed = const [],
  });
  bool get isEmpty => added.isEmpty && removed.isEmpty && changed.isEmpty;
}

/// 课表仓库：远程拉取 + 本地缓存 + 用户隐藏过滤。
/// 服务器数据与用户隐藏设置分离：同步只覆盖课表表，隐藏表永不被动。
class ScheduleRepository {
  ScheduleRepository({
    required ScheduleRemote remote,
    required AppDatabase db,
  })  : _remote = remote,
        _db = db;

  final ScheduleRemote _remote;
  final AppDatabase _db;

  /// 缓存优先读取（离线可用），已应用隐藏过滤。
  Future<List<ScheduleEntry>> getVisibleSchedule(Semester sem) async {
    final all = await _db.scheduleOf(sem);
    return applyHidden(all);
  }

  Future<List<ScheduleEntry>> getRawSchedule(Semester sem) =>
      _db.scheduleOf(sem);

  /// 应用隐藏规则：整门隐藏 + 单次隐藏（需结合当前周）。
  Future<List<ScheduleEntry>> applyHidden(
    List<ScheduleEntry> entries, {
    int? currentWeek,
  }) async {
    final hiddenCourses = await _db.hiddenCourseIds();
    final hiddenOcc = await _db.hiddenOccurrenceKeys();
    return entries.where((e) {
      if (hiddenCourses.contains(e.courseId)) return false;
      if (currentWeek != null &&
          hiddenOcc.contains('${e.entryId}#$currentWeek')) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 从服务器刷新课表，返回与上次的差异。失败抛 AppException，且不清空旧数据。
  Future<ScheduleDiff> refresh(Semester sem) async {
    final old = await _db.scheduleOf(sem);
    final result = await _remote.fetch(sem); // 失败会抛异常，旧数据保持不变
    await _db.replaceSchedule(sem, result.entries);
    return _diff(old, result.entries);
  }

  ScheduleDiff _diff(List<ScheduleEntry> old, List<ScheduleEntry> fresh) {
    final oldById = {for (final e in old) e.entryId: e};
    final newById = {for (final e in fresh) e.entryId: e};
    final added = <String>[];
    final removed = <String>[];
    final changed = <String>[];

    for (final id in newById.keys) {
      if (!oldById.containsKey(id)) {
        added.add(newById[id]!.courseName);
      }
    }
    for (final id in oldById.keys) {
      if (!newById.containsKey(id)) {
        removed.add(oldById[id]!.courseName);
      } else {
        final o = oldById[id]!;
        final n = newById[id]!;
        final diffs = <String>[];
        if (o.location != n.location && n.location.isNotEmpty) {
          diffs.add('教室 ${o.location}→${n.location}');
        }
        if (o.teacher != n.teacher && n.teacher.isNotEmpty) {
          diffs.add('教师 ${o.teacher}→${n.teacher}');
        }
        if (o.rawJc != n.rawJc || o.rawWeeks != n.rawWeeks) {
          diffs.add('时间调整');
        }
        if (diffs.isNotEmpty) {
          changed.add('${n.courseName}：${diffs.join('，')}');
        }
      }
    }
    return ScheduleDiff(
      added: added.toSet().toList(),
      removed: removed.toSet().toList(),
      changed: changed.toSet().toList(),
    );
  }

  // ---- 隐藏管理 ----
  Future<void> hideCourse(String courseId) => _db.hideCourse(courseId);
  Future<void> unhideCourse(String courseId) => _db.unhideCourse(courseId);
  Future<void> unhideAllCourses() => _db.unhideAllCourses();
  Future<void> hideOccurrence(String entryId, int week) =>
      _db.hideOccurrence(entryId, week);
  Future<void> unhideOccurrence(String entryId, int week) =>
      _db.unhideOccurrence(entryId, week);
  Future<Set<String>> hiddenCourseIds() => _db.hiddenCourseIds();
}
