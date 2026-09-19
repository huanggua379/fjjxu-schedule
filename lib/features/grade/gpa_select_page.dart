import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hud_card.dart';
import '../../data/repositories/grade_repository.dart';
import '../../domain/entities/entities.dart';
import 'grade_controller.dart';

/// 选择参与加权绩点计算的科目。
/// 勾选 = 参与计算；取消 = 排除。选择实时持久化，底部预览加权绩点。
class GpaSelectPage extends ConsumerWidget {
  const GpaSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = ref.watch(gradeControllerProvider).grades;
    final excluded = ref.watch(gpaSelectionProvider);
    final byTerm = ref.watch(gradesByTermProvider);

    final included =
        grades.where((g) => !excluded.contains(g.gradeId)).toList();
    final preview = GradeStats.compute(included);
    // 有绩点数据、可参与计算的科目总数
    final selectable =
        grades.where((g) => g.gpaValue != null && (g.creditValue ?? 0) > 0);
    final selectedCount =
        selectable.where((g) => !excluded.contains(g.gradeId)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('绩点计算科目'),
        actions: [
          TextButton(
            onPressed: selectable.isEmpty
                ? null
                : () => ref.read(gpaSelectionProvider.notifier).includeAll(),
            child: const Text('全选'),
          ),
        ],
      ),
      body: grades.isEmpty
          ? const Center(
              child: Text('暂无成绩数据',
                  style: TextStyle(color: AppColors.textSecondaryLight)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const _Hint(),
                const SizedBox(height: 12),
                for (final entry in byTerm.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 8),
                    child: HudLabel(entry.key, icon: Icons.folder_outlined),
                  ),
                  for (final g in entry.value)
                    _CourseTile(
                      grade: g,
                      included: !excluded.contains(g.gradeId),
                      selectable:
                          g.gpaValue != null && (g.creditValue ?? 0) > 0,
                      onToggle: () => ref
                          .read(gpaSelectionProvider.notifier)
                          .toggle(g.gradeId),
                    ),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: AppColors.hudLine.withOpacity(0.6)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('加权绩点（已选 $selectedCount 门）',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight)),
                    const SizedBox(height: 2),
                    Text(
                      preview.weightedGpa != null
                          ? preview.weightedGpa!.toStringAsFixed(3)
                          : '—',
                      style: AppTextStyles.techNumber
                          .copyWith(fontSize: 28, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('已修学分 ${preview.totalCredits.toStringAsFixed(1)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight)),
                  const SizedBox(height: 2),
                  Text(
                    preview.averageScore != null
                        ? '平均分 ${preview.averageScore!.toStringAsFixed(1)}'
                        : '平均分 —',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '勾选的科目参与加权绩点计算（按学分加权，使用教务系统提供的每门绩点）。'
              '无绩点数据的科目（如合格/不合格）不计入。',
              style: TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  final Grade grade;
  final bool included;
  final bool selectable;
  final VoidCallback onToggle;
  const _CourseTile({
    required this.grade,
    required this.included,
    required this.selectable,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final dim = selectable && !included;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HudCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: selectable ? included : false,
              onChanged: selectable ? (_) => onToggle() : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(grade.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: dim
                              ? AppColors.textSecondaryLight
                              : null)),
                  const SizedBox(height: 2),
                  Text(
                    selectable
                        ? [
                            if (grade.credit?.isNotEmpty ?? false)
                              '${grade.credit} 学分',
                            if (grade.gpa?.isNotEmpty ?? false)
                              '绩点 ${grade.gpa}',
                            if (grade.score?.isNotEmpty ?? false)
                              '成绩 ${grade.score}',
                          ].join(' · ')
                        : '无绩点数据，不计入',
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
