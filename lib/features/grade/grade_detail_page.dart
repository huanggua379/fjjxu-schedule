import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hud_card.dart';
import '../../domain/entities/entities.dart';
import 'grade_controller.dart';

/// 成绩详情：仅展示校方真实提供的字段，绝不虚构成绩构成。
class GradeDetailPage extends ConsumerWidget {
  final String gradeId;
  const GradeDetailPage({super.key, required this.gradeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = ref.watch(gradeControllerProvider).grades;
    final grade = grades.where((g) => g.gradeId == gradeId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('成绩详情')),
      body: grade == null
          ? const Center(child: Text('未找到该成绩记录'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                _ScoreHero(grade: grade),
                const SizedBox(height: 18),
                HudCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const HudLabel('COURSE INFO',
                          icon: Icons.info_outline_rounded),
                      const SizedBox(height: 14),
                      _row('课程', grade.courseName),
                      _row('学期', grade.termName),
                      if (_nz(grade.teacher)) _row('任课教师', grade.teacher),
                      if (_nz(grade.credit)) _row('学分', grade.credit!),
                      if (_nz(grade.nature)) _row('课程性质', grade.nature!),
                      if (_nz(grade.category)) _row('课程类别', grade.category!),
                      if (_nz(grade.assessType)) _row('考核方式', grade.assessType!),
                      if (_nz(grade.examType)) _row('考试性质', grade.examType!),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                HudCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const HudLabel('SCORE DETAIL',
                          icon: Icons.analytics_outlined),
                      const SizedBox(height: 14),
                      if (_nz(grade.score)) _row('总评成绩', grade.score!),
                      if (_nz(grade.hundredScore))
                        _row('百分制成绩', grade.hundredScore!),
                      if (_nz(grade.gpa)) _row('绩点（校方）', grade.gpa!),
                      if (grade.hasComponents) ...[
                        const Divider(height: 20),
                        if (_nz(grade.usualScore)) _row('平时', grade.usualScore!),
                        if (_nz(grade.midScore)) _row('期中', grade.midScore!),
                        if (_nz(grade.expScore)) _row('实验', grade.expScore!),
                        if (_nz(grade.finalScore)) _row('期末', grade.finalScore!),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '教务系统未提供成绩构成明细，仅显示总评。',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight,
                                height: 1.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  static bool _nz(String? s) => s != null && s.trim().isNotEmpty;

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondaryLight)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}

class _ScoreHero extends StatelessWidget {
  final Grade grade;
  const _ScoreHero({required this.grade});

  @override
  Widget build(BuildContext context) {
    final v = grade.scoreValue;
    final color = v == null
        ? AppColors.textSecondaryLight
        : v >= 60
            ? AppColors.primary
            : AppColors.danger;
    return HudCard(
      glowIntensity: 0.12,
      borderColor: color.withOpacity(0.25),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(grade.courseName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(grade.termName,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondaryLight)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(grade.score ?? '—',
                  style: AppTextStyles.techNumber
                      .copyWith(fontSize: 40, color: color)),
              if (_nz(grade.gpa))
                Text('绩点 ${grade.gpa}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondaryLight)),
            ],
          ),
        ],
      ),
    );
  }

  static bool _nz(String? s) => s != null && s.trim().isNotEmpty;
}
