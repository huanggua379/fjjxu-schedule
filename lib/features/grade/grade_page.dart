import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hud_card.dart';
import '../../domain/entities/entities.dart';
import 'grade_controller.dart';

/// 成绩页：统计概览 + 按学期分组的成绩列表 + 手动刷新（新成绩提醒）。
class GradePage extends ConsumerWidget {
  const GradePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gradeControllerProvider);
    final stats = ref.watch(gradeStatsProvider);
    final selStats = ref.watch(selectedGradeStatsProvider);
    final excluded = ref.watch(gpaSelectionProvider);
    final byTerm = ref.watch(gradesByTermProvider);
    final newIds = state.newlyPublished.map((g) => g.gradeId).toSet();
    final includedCount = state.grades
        .where((g) =>
            g.gpaValue != null &&
            (g.creditValue ?? 0) > 0 &&
            !excluded.contains(g.gradeId))
        .length;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => _refresh(context, ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('成绩',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                  if (state.loading)
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 14),
              _StatsCard(
                weightedGpa: selStats.weightedGpa,
                averageScore: stats.averageScore,
                totalCredits: stats.totalCredits,
                includedCount: includedCount,
                onSelectCourses: () => context.push('/gpa-select'),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                _WarnBanner(message: state.error!),
              ],
              const SizedBox(height: 20),
              if (state.grades.isEmpty && !state.loading)
                _Empty(
                  onRetry: () => _refresh(context, ref),
                )
              else
                for (final entry in byTerm.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 10),
                    child: Row(
                      children: [
                        HudLabel(entry.key,
                            icon: Icons.folder_outlined),
                        const Spacer(),
                        Text('${entry.value.length} 门',
                            style: AppTextStyles.hudLabelMuted),
                      ],
                    ),
                  ),
                  for (final g in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GradeCard(
                        grade: g,
                        isNew: newIds.contains(g.gradeId),
                        onTap: () => context.push('/grade/${g.gradeId}'),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final n = await ref.read(gradeControllerProvider.notifier).refresh();
    if (!context.mounted) return;
    final st = ref.read(gradeControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (st.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(st.error!)));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(n > 0 ? '发现 $n 门新成绩' : '成绩已是最新')),
      );
    }
  }
}

class _StatsCard extends StatelessWidget {
  final double? weightedGpa;
  final double? averageScore;
  final double totalCredits;
  final int includedCount;
  final VoidCallback onSelectCourses;
  const _StatsCard({
    required this.weightedGpa,
    required this.averageScore,
    required this.totalCredits,
    required this.includedCount,
    required this.onSelectCourses,
  });

  @override
  Widget build(BuildContext context) {
    return HudCard(
      glowIntensity: 0.1,
      borderColor: AppColors.primary.withOpacity(0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HudLabel('OVERVIEW', icon: Icons.insights_rounded),
          const SizedBox(height: 16),
          Row(
            children: [
              _metric('加权绩点',
                  weightedGpa != null ? weightedGpa!.toStringAsFixed(2) : '—',
                  big: true),
              _divider(),
              _metric('平均分',
                  averageScore != null ? averageScore!.toStringAsFixed(1) : '—'),
              _divider(),
              _metric('已修学分',
                  totalCredits > 0 ? totalCredits.toStringAsFixed(1) : '—'),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onSelectCourses,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.primary.withOpacity(0.16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.rule_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('参与计算 $includedCount 门 · 选择科目',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: AppColors.hudLine,
      );

  Widget _metric(String label, String value, {bool big = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.techNumber.copyWith(
                  fontSize: big ? 30 : 24, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondaryLight)),
        ],
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  final Grade grade;
  final bool isNew;
  final VoidCallback onTap;
  const _GradeCard({required this.grade, required this.isNew, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final score = grade.score ?? '—';
    final passed = _passed(grade.scoreValue);
    final scoreColor = grade.scoreValue == null
        ? AppColors.textSecondaryLight
        : passed
            ? AppColors.primary
            : AppColors.danger;

    return HudCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(grade.courseName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.live.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('NEW',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (grade.credit?.isNotEmpty ?? false) '${grade.credit} 学分',
                    if (grade.nature?.isNotEmpty ?? false) grade.nature!,
                    if (grade.gpa?.isNotEmpty ?? false) '绩点 ${grade.gpa}',
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(score,
              style: AppTextStyles.techNumber
                  .copyWith(fontSize: 26, color: scoreColor)),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondaryLight),
        ],
      ),
    );
  }

  static bool _passed(double? v) => v == null ? true : v >= 60;
}

class _WarnBanner extends StatelessWidget {
  final String message;
  const _WarnBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onRetry;
  const _Empty({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined,
              size: 48, color: AppColors.primary.withOpacity(0.35)),
          const SizedBox(height: 14),
          const Text('暂无成绩数据',
              style: TextStyle(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 6),
          const Text('下拉刷新，从教务系统同步成绩',
              style: TextStyle(
                  color: AppColors.textSecondaryLight, fontSize: 12)),
          const SizedBox(height: 18),
          OutlinedButton(
              onPressed: onRetry, child: const Text('立即同步')),
        ],
      ),
    );
  }
}
