import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/schedule_utils.dart';
import '../data/local/app_database.dart';
import '../data/local/secure_store.dart';
import '../data/local/settings_store.dart';
import '../data/network/network_client.dart';
import '../data/remote/auth_remote.dart';
import '../data/remote/grade_remote.dart';
import '../data/remote/schedule_remote.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/grade_repository.dart';
import '../data/repositories/schedule_repository.dart';
import '../domain/entities/entities.dart';
import '../features/reminder/reminder_service.dart';
import '../features/sync/sync_service.dart';
import '../data/local/settings_store.dart' show AppSettings, ThemeModeSetting;

// ---------------- 基础设施（单例）----------------
final networkClientProvider = Provider<NetworkClient>((ref) => NetworkClient.instance);
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);
final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore.instance);
final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore.instance);

// ---------------- 远程数据源 ----------------
final authRemoteProvider = Provider<AuthRemote>((ref) => AuthRemote(ref.watch(networkClientProvider)));
final scheduleRemoteProvider = Provider<ScheduleRemote>((ref) => ScheduleRemote(ref.watch(networkClientProvider)));
final gradeRemoteProvider = Provider<GradeRemote>((ref) => GradeRemote(ref.watch(networkClientProvider)));

// ---------------- 服务 ----------------
final reminderServiceProvider = Provider<ReminderService>((ref) => ReminderService(
      db: ref.watch(databaseProvider),
      settings: ref.watch(settingsStoreProvider),
    ));

// ---------------- 仓库 ----------------
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      remote: ref.watch(authRemoteProvider),
      secure: ref.watch(secureStoreProvider),
      settings: ref.watch(settingsStoreProvider),
      net: ref.watch(networkClientProvider),
    ));

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) => ScheduleRepository(
      remote: ref.watch(scheduleRemoteProvider),
      db: ref.watch(databaseProvider),
    ));

final gradeRepositoryProvider = Provider<GradeRepository>((ref) => GradeRepository(
      remote: ref.watch(gradeRemoteProvider),
      db: ref.watch(databaseProvider),
    ));

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(
      scheduleRepo: ref.watch(scheduleRepositoryProvider),
      gradeRepo: ref.watch(gradeRepositoryProvider),
      settings: ref.watch(settingsStoreProvider),
      reminders: ref.watch(reminderServiceProvider),
    ));

// ---------------- 应用设置（可观察、可写）----------------
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  Future<void> load() async {
    state = await ref.read(settingsStoreProvider).load();
  }

  Future<void> update(AppSettings next) async {
    state = next;
    await ref.read(settingsStoreProvider).save(next);
  }

  Future<void> setAutoSync(bool v) => update(state.copyWith(autoSync: v));
  Future<void> setSyncInterval(int minutes) => update(state.copyWith(syncIntervalMinutes: minutes));
  Future<void> setReminderEnabled(bool v) => update(state.copyWith(reminderEnabled: v));
  Future<void> setReminderMode(RemindMode m) => update(state.copyWith(reminderMode: m));
  Future<void> setReminderMinutes(int m) => update(state.copyWith(reminderMinutesBefore: m));
  Future<void> setGradeNotify(bool v) => update(state.copyWith(gradeNotify: v));
  Future<void> setAutoQueryGrade(bool v) => update(state.copyWith(autoQueryGrade: v));
  Future<void> setThemeMode(ThemeModeSetting m) => update(state.copyWith(themeMode: m));
  Future<void> setSemesterStart(String? iso) => update(iso == null
      ? state.copyWith(clearSemesterStart: true)
      : state.copyWith(semesterStartOverride: iso));
  Future<void> setCurrentSemester(Semester s) =>
      update(state.copyWith(currentXnm: s.xnm, currentXqm: s.xqm));
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

// ---------------- 当前学期 ----------------
/// 当前学期：优先用户设置里保存的，否则按日期推断。
final currentSemesterProvider = Provider<Semester>((ref) {
  final s = ref.watch(settingsControllerProvider);
  if (s.currentXnm > 0 && s.currentXqm > 0) {
    return Semester(xnm: s.currentXnm, xqm: s.currentXqm);
  }
  return TermUtils.guessCurrentSemester();
});

/// 学期开始日期（对齐到周一）。优先用户校历校准，否则按规则估算。
final semesterStartProvider = Provider<DateTime>((ref) {
  final s = ref.watch(settingsControllerProvider);
  final sem = ref.watch(currentSemesterProvider);
  DateTime start;
  final override = s.semesterStartOverride;
  if (override != null && override.isNotEmpty && DateTime.tryParse(override) != null) {
    start = DateTime.parse(override);
  } else {
    start = TermUtils.estimateSemesterStart(sem);
  }
  return start.subtract(Duration(days: start.weekday - 1));
});

/// 当前周次（依赖学期开始日期；未知则 null）。
final currentWeekProvider = Provider<int?>((ref) {
  final start = ref.watch(semesterStartProvider);
  return TermUtils.currentWeek(start);
});

// ---------------- 作息时间（每节次起止分钟，可配置）----------------
class PeriodTimesController extends Notifier<List<List<int>>> {
  @override
  List<List<int>> build() {
    Future.microtask(() async {
      state = await ref.read(settingsStoreProvider).getPeriodTimes();
    });
    return AppConstants.defaultPeriodTimes;
  }

  Future<void> save(List<List<int>> times) async {
    state = times;
    await ref.read(settingsStoreProvider).setPeriodTimes(times);
  }

  Future<void> resetToDefault() => save(AppConstants.defaultPeriodTimes);
}

final periodTimesProvider =
    NotifierProvider<PeriodTimesController, List<List<int>>>(
        PeriodTimesController.new);
