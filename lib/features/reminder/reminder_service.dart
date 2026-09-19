import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../core/utils/schedule_utils.dart';
import '../../data/local/app_database.dart';
import '../../data/local/settings_store.dart';
import '../../domain/entities/entities.dart';

/// 上课提醒服务：通知 / 闹钟(全屏+闹钟铃声) / 两者。
///
/// 去重策略：每次 rescheduleAll 先 cancelAll 再按“稳定 ID”重建，
/// 且 ID 由 entryId+具体日期 派生，App 重启/自动同步都不会产生重复提醒。
///
/// 说明：闹钟模式采用 Android 全屏意图 + 闹钟音频属性(USAGE_ALARM)实现，
/// 效果等价于本地闹钟；未引入额外原生插件以降低构建风险（见 README 已知限制）。
class ReminderService {
  ReminderService({required AppDatabase db, required SettingsStore settings})
      : _db = db,
        _settings = settings;

  final AppDatabase _db;
  final SettingsStore _settings;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;
  String _tzName = 'Asia/Shanghai';

  static const _channelClass = 'keben_class_reminder';
  static const _channelGrade = 'keben_grade';

  /// 排程时间窗：只为未来 N 天内的课程排提醒，避免一次性排太多。
  static const int _horizonDays = 21;

  Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    try {
      _tzName = await FlutterTimezone.getLocalTimezone();
    } catch (_) {
      _tzName = 'Asia/Shanghai';
    }
    try {
      tz.setLocalLocation(tz.getLocation(_tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    }

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    // 通知渠道
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelClass,
          '上课提醒',
          description: '课程开始前的提醒通知',
          importance: Importance.max,
        ));
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelGrade,
          '成绩更新',
          description: '新成绩发布提醒',
          importance: Importance.high,
        ));
    _inited = true;
  }

  /// 请求通知权限（Android 13+）。返回是否被授予。
  Future<bool> requestNotificationPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? false;
    return granted;
  }

  /// 请求精确闹钟权限（Android 12+，闹钟模式需要）。
  Future<bool> requestExactAlarmPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestExactAlarmsPermission() ?? false;
  }

  /// 稳定通知 ID：由字符串哈希到 31 位正整数。
  static int stableId(String s) {
    var h = 0x12345678;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h & 0x7fffffff;
  }

  /// 重新排程某学期所有可见课程的提醒（先全清再重建，天然去重）。
  Future<void> rescheduleAll(Semester sem) async {
    await init();
    await cancelAll();

    final settings = await _settings.load();
    if (!settings.reminderEnabled) return; // 全局关闭

    final entries = await _db.scheduleOf(sem);
    final visible = await _applyHidden(entries, sem);
    final perCourse = await _db.reminderSettings();
    final periodTimes = await _settings.getPeriodTimes();

    final semesterStart = _semesterStart(settings, sem);
    final now = tz.TZDateTime.now(tz.local);
    final horizon = now.add(const Duration(days: _horizonDays));

    // 按 (周, 星期) 分组收集“启用提醒”的排课。
    // 每天再按早/午/晚分段，每段只提醒最早的那一节：
    // 早上第一节之后的同段课程不再单独提醒（下午、晚上同理）。
    final byDay = <String, List<ScheduleEntry>>{};
    for (final e in visible) {
      if (e.weekday == 0 || e.startSection == 0) continue; // 实践课/无固定时间不排
      final cs = perCourse[e.courseId];
      if (cs != null && !cs.enabled) continue;
      for (final week in e.weeks) {
        byDay.putIfAbsent('$week-${e.weekday}', () => []).add(e);
      }
    }

    for (final day in byDay.entries) {
      final parts = day.key.split('-');
      final week = int.parse(parts[0]);
      final weekday = int.parse(parts[1]);

      // 每段(0早/1午/2晚)取开始时间最早的一节
      final firstOfPart = <int, ScheduleEntry>{};
      final partStart = <int, int>{};
      for (final e in day.value) {
        final (s, _) = ScheduleParser.sectionToMinutes(
            e.startSection, e.endSection, periodTimes);
        final p = _dayPart(s);
        final cur = partStart[p];
        if (cur == null || s < cur) {
          partStart[p] = s;
          firstOfPart[p] = e;
        }
      }

      // 该周该星期几的具体日期
      final dayOffset = (week - 1) * 7 + (weekday - 1);
      final date = semesterStart.add(Duration(days: dayOffset));

      for (final e in firstOfPart.values) {
        final cs = perCourse[e.courseId];
        final mode = cs?.mode ?? settings.reminderMode;
        final minutesBefore = (cs != null && cs.minutesBefore > 0)
            ? cs.minutesBefore
            : settings.reminderMinutesBefore;
        final (startMin, _) = ScheduleParser.sectionToMinutes(
            e.startSection, e.endSection, periodTimes);
        final classStart = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
        ).add(Duration(minutes: startMin));
        final fireAt = classStart.subtract(Duration(minutes: minutesBefore));
        if (fireAt.isBefore(now) || fireAt.isAfter(horizon)) continue;

        final id = stableId('${e.entryId}|$week');
        await _scheduleOne(
          id: id,
          fireAt: fireAt,
          e: e,
          mode: mode,
          minutesBefore: minutesBefore,
          startMin: startMin,
        );
      }
    }
  }

  /// 按开始分钟把一天分为早(0)/午(1)/晚(2)三段。
  static int _dayPart(int startMin) {
    if (startMin < 12 * 60) return 0;
    if (startMin < 18 * 60) return 1;
    return 2;
  }

  Future<void> _scheduleOne({
    required int id,
    required tz.TZDateTime fireAt,
    required ScheduleEntry e,
    required RemindMode mode,
    required int minutesBefore,
    required int startMin,
  }) async {
    final timeStr = ScheduleParser.minutesToHHmm(startMin);
    final title = '$minutesBefore分钟后有课';
    final body = '${e.courseName}\n${e.location.isEmpty ? '' : '${e.location}\n'}$timeStr 开始';

    final useAlarm = mode == RemindMode.alarm || mode == RemindMode.both;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelClass,
        '上课提醒',
        channelDescription: '课程开始前的提醒通知',
        importance: Importance.max,
        priority: Priority.max,
        category: useAlarm ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
        audioAttributesUsage: useAlarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        fullScreenIntent: useAlarm,
        visibility: NotificationVisibility.public,
        // 通知不默认展示成绩等敏感信息
      ),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      fireAt,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }

  /// 新成绩提醒（去重由调用方保证：只对“新出现”的成绩发一次）。
  Future<void> notifyNewGrades(List<Grade> newGrades) async {
    await init();
    if (newGrades.isEmpty) return;
    final n = newGrades.length;
    await _plugin.show(
      stableId('grade|${newGrades.map((g) => g.gradeId).join()}'),
      '发现新的成绩',
      '你有 $n 门课程成绩已发布',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelGrade,
          '成绩更新',
          channelDescription: '新成绩发布提醒',
          importance: Importance.high,
          priority: Priority.high,
          // 通知不展示具体分数，保护隐私
        ),
      ),
    );
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  Future<void> cancelCourse(String courseId, Semester sem) async {
    // 简化：取消全部后重建（保证一致性）
    await rescheduleAll(sem);
  }

  // ---- 内部工具 ----
  Future<List<ScheduleEntry>> _applyHidden(
      List<ScheduleEntry> entries, Semester sem) async {
    final hiddenCourses = await _db.hiddenCourseIds();
    return entries.where((e) => !hiddenCourses.contains(e.courseId)).toList();
  }

  DateTime _semesterStart(AppSettings s, Semester sem) {
    final override = s.semesterStartOverride;
    if (override != null && override.isNotEmpty) {
      final d = DateTime.tryParse(override);
      if (d != null) return _toMonday(d);
    }
    return _toMonday(TermUtils.estimateSemesterStart(sem));
  }

  static DateTime _toMonday(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));
}
