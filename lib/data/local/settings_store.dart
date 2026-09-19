import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/entities.dart';

/// 普通（非敏感）应用设置，存 SharedPreferences。
class AppSettings {
  final bool autoSync;
  final int syncIntervalMinutes; // 0 = 仅手动
  final bool reminderEnabled; // 全局上课提醒开关
  final RemindMode reminderMode;
  final int reminderMinutesBefore;
  final bool gradeNotify; // 新成绩提醒
  final bool autoQueryGrade;
  final ThemeModeSetting themeMode; // 0 system,1 light,2 dark
  final String? semesterStartOverride; // yyyy-MM-dd，校历校准
  final DateTime? lastSyncTime;
  final int currentXnm;
  final int currentXqm;

  const AppSettings({
    this.autoSync = true,
    this.syncIntervalMinutes = 180,
    this.reminderEnabled = true,
    this.reminderMode = RemindMode.notification,
    this.reminderMinutesBefore = 15,
    this.gradeNotify = true,
    this.autoQueryGrade = true,
    this.themeMode = ThemeModeSetting.system,
    this.semesterStartOverride,
    this.lastSyncTime,
    this.currentXnm = 0,
    this.currentXqm = 0,
  });

  AppSettings copyWith({
    bool? autoSync,
    int? syncIntervalMinutes,
    bool? reminderEnabled,
    RemindMode? reminderMode,
    int? reminderMinutesBefore,
    bool? gradeNotify,
    bool? autoQueryGrade,
    ThemeModeSetting? themeMode,
    String? semesterStartOverride,
    bool clearSemesterStart = false,
    DateTime? lastSyncTime,
    int? currentXnm,
    int? currentXqm,
  }) =>
      AppSettings(
        autoSync: autoSync ?? this.autoSync,
        syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderMode: reminderMode ?? this.reminderMode,
        reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
        gradeNotify: gradeNotify ?? this.gradeNotify,
        autoQueryGrade: autoQueryGrade ?? this.autoQueryGrade,
        themeMode: themeMode ?? this.themeMode,
        semesterStartOverride: clearSemesterStart
            ? null
            : (semesterStartOverride ?? this.semesterStartOverride),
        lastSyncTime: lastSyncTime ?? this.lastSyncTime,
        currentXnm: currentXnm ?? this.currentXnm,
        currentXqm: currentXqm ?? this.currentXqm,
      );
}

enum ThemeModeSetting { system, light, dark }

/// 设置读写（SharedPreferences）。
class SettingsStore {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _kAutoSync = 'autoSync';
  static const _kSyncInterval = 'syncIntervalMinutes';
  static const _kReminderEnabled = 'reminderEnabled';
  static const _kReminderMode = 'reminderMode';
  static const _kReminderMinutes = 'reminderMinutesBefore';
  static const _kGradeNotify = 'gradeNotify';
  static const _kAutoQueryGrade = 'autoQueryGrade';
  static const _kThemeMode = 'themeMode';
  static const _kSemesterStart = 'semesterStartOverride';
  static const _kLastSync = 'lastSyncTime';
  static const _kXnm = 'currentXnm';
  static const _kXqm = 'currentXqm';
  static const _kLoggedIn = 'loggedIn';
  static const _kPeriodTimes = 'periodTimes';
  static const _kGpaExcluded = 'gpaExcludedGradeIds';

  Future<AppSettings> load() async {
    final sp = await SharedPreferences.getInstance();
    return AppSettings(
      autoSync: sp.getBool(_kAutoSync) ?? true,
      syncIntervalMinutes: sp.getInt(_kSyncInterval) ?? 180,
      reminderEnabled: sp.getBool(_kReminderEnabled) ?? true,
      reminderMode: RemindModeX.fromKey(sp.getString(_kReminderMode)),
      reminderMinutesBefore: sp.getInt(_kReminderMinutes) ?? 15,
      gradeNotify: sp.getBool(_kGradeNotify) ?? true,
      autoQueryGrade: sp.getBool(_kAutoQueryGrade) ?? true,
      themeMode: ThemeModeSetting.values[sp.getInt(_kThemeMode) ?? 0],
      semesterStartOverride: sp.getString(_kSemesterStart),
      lastSyncTime: _parseDate(sp.getString(_kLastSync)),
      currentXnm: sp.getInt(_kXnm) ?? 0,
      currentXqm: sp.getInt(_kXqm) ?? 0,
    );
  }

  Future<void> save(AppSettings s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAutoSync, s.autoSync);
    await sp.setInt(_kSyncInterval, s.syncIntervalMinutes);
    await sp.setBool(_kReminderEnabled, s.reminderEnabled);
    await sp.setString(_kReminderMode, s.reminderMode.key);
    await sp.setInt(_kReminderMinutes, s.reminderMinutesBefore);
    await sp.setBool(_kGradeNotify, s.gradeNotify);
    await sp.setBool(_kAutoQueryGrade, s.autoQueryGrade);
    await sp.setInt(_kThemeMode, s.themeMode.index);
    if (s.semesterStartOverride == null) {
      await sp.remove(_kSemesterStart);
    } else {
      await sp.setString(_kSemesterStart, s.semesterStartOverride!);
    }
    await sp.setInt(_kXnm, s.currentXnm);
    await sp.setInt(_kXqm, s.currentXqm);
    if (s.lastSyncTime != null) {
      await sp.setString(_kLastSync, s.lastSyncTime!.toIso8601String());
    }
  }

  Future<void> setLastSync(DateTime t) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLastSync, t.toIso8601String());
  }

  Future<void> setLoggedIn(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kLoggedIn, v);
  }

  Future<bool> isLoggedIn() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kLoggedIn) ?? false;
  }

  /// 被排除在加权绩点计算之外的成绩 ID 集合（默认空 = 全部参与）。
  Future<Set<String>> getGpaExcluded() async {
    final sp = await SharedPreferences.getInstance();
    return (sp.getStringList(_kGpaExcluded) ?? const []).toSet();
  }

  Future<void> setGpaExcluded(Set<String> ids) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kGpaExcluded, ids.toList());
  }

  /// 每节次的起止分钟偏移（[起, 止]）。未设置时用内置默认作息。
  Future<List<List<int>>> getPeriodTimes() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_kPeriodTimes);
    if (raw == null || raw.isEmpty) return AppConstants.defaultPeriodTimes;
    final out = <List<int>>[];
    for (final item in raw) {
      final p = item.split(',');
      if (p.length == 2) {
        final a = int.tryParse(p[0]);
        final b = int.tryParse(p[1]);
        if (a != null && b != null && b > a) out.add([a, b]);
      }
    }
    return out.isEmpty ? AppConstants.defaultPeriodTimes : out;
  }

  Future<void> setPeriodTimes(List<List<int>> times) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(
        _kPeriodTimes, [for (final r in times) '${r[0]},${r[1]}']);
  }

  Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
  }

  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}
