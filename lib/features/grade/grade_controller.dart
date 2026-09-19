import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/grade_repository.dart';
import '../../domain/entities/entities.dart';

class GradeState {
  final List<Grade> grades;
  final bool loading;
  final String? error;
  final DateTime? lastSync;
  final List<Grade> newlyPublished; // 本次刷新新出现的成绩

  const GradeState({
    this.grades = const [],
    this.loading = false,
    this.error,
    this.lastSync,
    this.newlyPublished = const [],
  });

  GradeState copyWith({
    List<Grade>? grades,
    bool? loading,
    String? error,
    bool clearError = false,
    DateTime? lastSync,
    List<Grade>? newlyPublished,
  }) =>
      GradeState(
        grades: grades ?? this.grades,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        lastSync: lastSync ?? this.lastSync,
        newlyPublished: newlyPublished ?? this.newlyPublished,
      );
}

class GradeController extends Notifier<GradeState> {
  @override
  GradeState build() {
    // 异步加载缓存
    Future.microtask(() => _loadCache());
    return const GradeState(loading: true);
  }

  Future<void> _loadCache() async {
    final repo = ref.read(gradeRepositoryProvider);
    final cached = await repo.getCachedGrades();
    final settings = ref.read(settingsControllerProvider);
    state = state.copyWith(grades: cached, loading: false, lastSync: settings.lastSyncTime);
  }

  /// 刷新成绩；返回新发布的成绩数量（用于提醒）。
  Future<int> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    final repo = ref.read(gradeRepositoryProvider);
    final settings = ref.read(settingsControllerProvider);
    try {
      final newly = await repo.refresh();
      final all = await repo.getCachedGrades();
      final now = DateTime.now();
      state = state.copyWith(
        grades: all,
        loading: false,
        lastSync: now,
        newlyPublished: newly,
      );
      // 新成绩提醒（可关闭）
      if (settings.gradeNotify && newly.isNotEmpty) {
        await ref.read(reminderServiceProvider).notifyNewGrades(newly);
      }
      return newly.length;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: '成绩更新失败，正在显示上次保存的数据',
      );
      return 0;
    }
  }

  void clearNewBadge() {
    state = state.copyWith(newlyPublished: []);
  }
}

final gradeControllerProvider =
    NotifierProvider<GradeController, GradeState>(GradeController.new);

/// 成绩统计（基于当前 grade 列表）。
final gradeStatsProvider = Provider<GradeStats>((ref) {
  final grades = ref.watch(gradeControllerProvider).grades;
  return GradeStats.compute(grades);
});

/// 参与加权绩点计算的科目选择。
/// 状态 = 被"排除"的 gradeId 集合（默认空 = 全部参与），持久化到本地。
class GpaSelectionController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    Future.microtask(() async {
      state = await ref.read(settingsStoreProvider).getGpaExcluded();
    });
    return {};
  }

  Future<void> toggle(String gradeId) async {
    final next = Set<String>.from(state);
    if (!next.remove(gradeId)) next.add(gradeId);
    state = next;
    await ref.read(settingsStoreProvider).setGpaExcluded(next);
  }

  Future<void> setExcluded(Set<String> ids) async {
    state = Set<String>.from(ids);
    await ref.read(settingsStoreProvider).setGpaExcluded(state);
  }

  Future<void> includeAll() => setExcluded({});
}

final gpaSelectionProvider =
    NotifierProvider<GpaSelectionController, Set<String>>(
        GpaSelectionController.new);

/// 仅对"参与计算"的科目求加权绩点等统计。
final selectedGradeStatsProvider = Provider<GradeStats>((ref) {
  final grades = ref.watch(gradeControllerProvider).grades;
  final excluded = ref.watch(gpaSelectionProvider);
  final included =
      grades.where((g) => !excluded.contains(g.gradeId)).toList();
  return GradeStats.compute(included);
});

/// 按学期分组（最新在前）。
final gradesByTermProvider = Provider<Map<String, List<Grade>>>((ref) {
  final grades = ref.watch(gradeControllerProvider).grades;
  return ref.read(gradeRepositoryProvider).groupByTerm(grades);
});

/// 可选学期列表。
final availableSemestersProvider = Provider<List<Semester>>((ref) {
  final grades = ref.watch(gradeControllerProvider).grades;
  return ref.read(gradeRepositoryProvider).availableSemesters(grades);
});
