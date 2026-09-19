import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/schedule_utils.dart';
import '../../core/widgets/hud_card.dart';
import '../../domain/entities/entities.dart';
import '../schedule/schedule_controller.dart';

/// 隐藏课程管理：查看并恢复被隐藏的整门课程 / 单次课程。
/// 仅操作本机隐藏表，不触碰教务系统数据。
class HiddenCoursesPage extends ConsumerStatefulWidget {
  const HiddenCoursesPage({super.key});

  @override
  ConsumerState<HiddenCoursesPage> createState() => _HiddenCoursesPageState();
}

class _HiddenCoursesPageState extends ConsumerState<HiddenCoursesPage> {
  late Future<_HiddenData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HiddenData> _load() async {
    final sem = ref.read(currentSemesterProvider);
    final db = ref.read(databaseProvider);
    final repo = ref.read(scheduleRepositoryProvider);
    final all = await repo.getRawSchedule(sem);
    final hiddenCourses = await db.hiddenCourseIds();
    final occRows = await db.hiddenOccurrences();
    return _HiddenData(all: all, hiddenCourses: hiddenCourses, occRows: occRows);
  }

  Future<void> _reload() async {
    final sem = ref.read(currentSemesterProvider);
    await ref.read(scheduleControllerProvider(sem).notifier).reloadLocal();
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('隐藏课程管理'),
        actions: [
          FutureBuilder<_HiddenData>(
            future: _future,
            builder: (context, snap) {
              final d = snap.data;
              final hasAny = d != null &&
                  (d.hiddenCourses.isNotEmpty || d.occRows.isNotEmpty);
              if (!hasAny) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  final repo = ref.read(scheduleRepositoryProvider);
                  await repo.unhideAllCourses();
                  final db = ref.read(databaseProvider);
                  for (final r in d.occRows) {
                    await db.unhideOccurrence(
                        r['entryId'] as String, r['week'] as int);
                  }
                  await _reload();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已恢复全部隐藏课程')));
                  }
                },
                child: const Text('全部恢复'),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<_HiddenData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          final byId = {for (final e in d.all) e.entryId: e};
          final byCourse = <String, ScheduleEntry>{};
          for (final e in d.all) {
            byCourse.putIfAbsent(e.courseId, () => e);
          }

          final hiddenCourses =
              d.hiddenCourses.where((id) => byCourse.containsKey(id)).toList();
          final hiddenOcc = d.occRows
              .where((r) => byId.containsKey(r['entryId'] as String))
              .toList();

          if (hiddenCourses.isEmpty && hiddenOcc.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_outlined,
                      size: 48, color: AppColors.primary.withOpacity(0.35)),
                  const SizedBox(height: 14),
                  const Text('没有被隐藏的课程',
                      style: TextStyle(color: AppColors.textSecondaryLight)),
                  const SizedBox(height: 6),
                  const Text('在课表中长按某节课即可隐藏',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondaryLight)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              if (hiddenCourses.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 10),
                  child: HudLabel('HIDDEN COURSES',
                      icon: Icons.layers_clear_outlined),
                ),
                for (final id in hiddenCourses)
                  _HiddenCard(
                    title: byCourse[id]!.courseName,
                    subtitle: '整门课程已隐藏 · ${byCourse[id]!.teacher}',
                    onRestore: () async {
                      await ref
                          .read(scheduleRepositoryProvider)
                          .unhideCourse(id);
                      await _reload();
                    },
                  ),
                const SizedBox(height: 20),
              ],
              if (hiddenOcc.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 10),
                  child: HudLabel('HIDDEN OCCURRENCES',
                      icon: Icons.event_busy_outlined),
                ),
                for (final r in hiddenOcc)
                  _occCard(byId[r['entryId'] as String]!, r['week'] as int),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _occCard(ScheduleEntry e, int week) {
    return _HiddenCard(
      title: e.courseName,
      subtitle:
          '第 $week 周 · ${ScheduleParser.weekdayNames[e.weekday]} ${e.rawJc}'
          '${e.location.isEmpty ? '' : ' · ${e.location}'}',
      onRestore: () async {
        await ref.read(databaseProvider).unhideOccurrence(e.entryId, week);
        await _reload();
      },
    );
  }
}

class _HiddenCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRestore;
  const _HiddenCard(
      {required this.title, required this.subtitle, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HudCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onRestore,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('恢复'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HiddenData {
  final List<ScheduleEntry> all;
  final Set<String> hiddenCourses;
  final List<Map<String, dynamic>> occRows;
  const _HiddenData({
    required this.all,
    required this.hiddenCourses,
    required this.occRows,
  });
}
