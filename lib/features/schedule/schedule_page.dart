import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/schedule_utils.dart';
import '../../domain/entities/entities.dart';
import '../schedule/schedule_controller.dart';

/// 周课表矩阵：横滑切换周次，高亮今天/当前节次，长按课程可隐藏。
class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  static const int _maxSections = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sem = ref.watch(currentSemesterProvider);
    final curWeek = ref.watch(currentWeekProvider);
    final selWeek = ref.watch(selectedWeekProvider);
    final entriesAsync = ref.watch(scheduleControllerProvider(sem));

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _TopBar(sem: sem, curWeek: curWeek, selWeek: selWeek),
          _DateStrip(selWeek: selWeek, curWeek: curWeek),
          const Divider(height: 1),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _RetryHint(
                onRetry: () => ref.invalidate(scheduleControllerProvider(sem)),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return _EmptySchedule(
                    onRefresh: () => ref
                        .read(scheduleControllerProvider(sem).notifier)
                        .refresh(),
                  );
                }
                final inWeek = entries
                    .where((e) => e.weeks.isEmpty || e.weeks.contains(selWeek))
                    .toList();
                final weekEntries = inWeek
                    .where((e) => e.weekday >= 1 && e.startSection >= 1)
                    .toList();
                final unplaced = inWeek
                    .where((e) => e.weekday < 1 || e.startSection < 1)
                    .toList();
                // 节次行数按真实数据动态扩展（floor 12，cap 100），
                // 避免高节次课程被网格裁掉而“看不见”。
                var maxSec = _maxSections;
                for (final e in weekEntries) {
                  if (e.endSection > maxSec) maxSec = e.endSection;
                }
                if (maxSec > 100) maxSec = 100;
                return Column(
                  children: [
                    Expanded(
                      child: _WeekGrid(
                        entries: weekEntries,
                        selWeek: selWeek,
                        curWeek: curWeek,
                        maxSections: maxSec,
                        onLongPress: (e) =>
                            _showEntrySheet(context, ref, e, sem, selWeek),
                      ),
                    ),
                    if (unplaced.isNotEmpty)
                      _UnplacedStrip(
                        entries: unplaced,
                        onTap: (e) =>
                            _showEntrySheet(context, ref, e, sem, selWeek),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEntrySheet(
    BuildContext context,
    WidgetRef ref,
    ScheduleEntry e,
    Semester sem,
    int week,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.courseName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${ScheduleParser.weekdayNames[e.weekday]} ${e.rawJc} · ${e.rawWeeks}\n'
                      '${e.location.isEmpty ? '未安排教室' : e.location}'
                      '${e.teacher.isEmpty ? '' : ' · ${e.teacher}'}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: Text('隐藏这一节（仅第 $week 周）'),
                subtitle: const Text('只在本机隐藏，不影响教务系统'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(scheduleRepositoryProvider)
                      .hideOccurrence(e.entryId, week);
                  await ref
                      .read(scheduleControllerProvider(sem).notifier)
                      .reloadLocal();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已隐藏第 $week 周的《${e.courseName}》')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.layers_clear_outlined),
                title: const Text('隐藏整门课程'),
                subtitle: const Text('该课程所有节次都不再显示'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(scheduleRepositoryProvider)
                      .hideCourse(e.courseId);
                  await ref
                      .read(scheduleControllerProvider(sem).notifier)
                      .reloadLocal();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已隐藏《${e.courseName}》，可在设置中恢复'),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends ConsumerWidget {
  final Semester sem;
  final int? curWeek;
  final int selWeek;
  const _TopBar({required this.sem, this.curWeek, required this.selWeek});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semStart = ref.watch(semesterStartProvider);
    final monday = semStart.add(Duration(days: (selWeek - 1) * 7));
    final sunday = monday.add(const Duration(days: 6));
    final range =
        '${monday.month}月${monday.day}日 - ${sunday.month}月${sunday.day}日';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('课表',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(range,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                Text(sem.displayName,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondaryLight)),
              ],
            ),
          ),
          _WeekPill(
            icon: Icons.chevron_left_rounded,
            onTap: selWeek > 1
                ? () => ref.read(selectedWeekProvider.notifier).prev()
                : null,
          ),
          GestureDetector(
            onTap: () => _pickWeek(context, ref, curWeek),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selWeek == (curWeek ?? -1) ? '本周' : '第 $selWeek 周',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded,
                      color: AppColors.primary, size: 20),
                ],
              ),
            ),
          ),
          _WeekPill(
            icon: Icons.chevron_right_rounded,
            onTap: () => ref.read(selectedWeekProvider.notifier).next(),
          ),
        ],
      ),
    );
  }

  void _pickWeek(BuildContext context, WidgetRef ref, int? curWeek) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择周次',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var w = 1; w <= 25; w++)
                    ChoiceChip(
                      label: Text(w == (curWeek ?? -1) ? '第$w周·本周' : '第$w周'),
                      selected: selWeek == w,
                      onSelected: (_) {
                        ref.read(selectedWeekProvider.notifier).set(w);
                        Navigator.pop(ctx);
                      },
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

class _WeekPill extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _WeekPill({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: (enabled ? AppColors.primary : AppColors.textSecondaryLight)
                .withOpacity(enabled ? 0.3 : 0.2),
          ),
        ),
        child: Icon(icon,
            size: 22,
            color: enabled ? AppColors.primary : AppColors.textSecondaryLight),
      ),
    );
  }
}

class _DateStrip extends ConsumerWidget {
  final int selWeek;
  final int? curWeek;
  const _DateStrip({required this.selWeek, this.curWeek});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semStart = ref.watch(semesterStartProvider);
    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 40), // 对齐左侧节次列
          for (var d = 1; d <= 7; d++)
            Expanded(child: _dayCell(semStart, d, today)),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime semStart, int weekday, DateTime today) {
    final date = semStart.add(Duration(days: (selWeek - 1) * 7 + (weekday - 1)));
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    return Column(
      children: [
        Text(ScheduleParser.weekdayNames[weekday].replaceFirst('周', ''),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isToday ? AppColors.primary : AppColors.textSecondaryLight)),
        const SizedBox(height: 3),
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday ? AppColors.primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text('${date.day}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isToday ? Colors.white : AppColors.textSecondaryLight)),
        ),
      ],
    );
  }
}

class _WeekGrid extends ConsumerWidget {
  final List<ScheduleEntry> entries;
  final int selWeek;
  final int? curWeek;
  final int maxSections;
  final void Function(ScheduleEntry) onLongPress;
  const _WeekGrid({
    required this.entries,
    required this.selWeek,
    this.curWeek,
    required this.maxSections,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 依据当前周次高亮“今天”的列
    final todayWeekday =
        (selWeek == (curWeek ?? -1)) ? DateTime.now().weekday : -1;
    final periodTimes = ref.watch(periodTimesProvider);

    return LayoutBuilder(
      builder: (context, c) {
        const gutter = 40.0;
        final colW = (c.maxWidth - gutter) / 7;
        final rowH = ((c.maxHeight) / maxSections).clamp(56.0, 92.0);
        final gridH = rowH * maxSections;

        return GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -200) ref.read(selectedWeekProvider.notifier).next();
            if (v > 200) ref.read(selectedWeekProvider.notifier).prev();
          },
          child: SingleChildScrollView(
            child: SizedBox(
              height: gridH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 节次列
                  SizedBox(
                    width: gutter,
                    child: Column(
                      children: [
                        for (var s = 1; s <= maxSections; s++)
                          SizedBox(
                            height: rowH,
                            child: Center(
                              child: Text('$s',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryLight,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 7 天
                  for (var d = 1; d <= 7; d++)
                    SizedBox(
                      width: colW,
                      height: gridH,
                      child: Stack(
                        children: [
                          // 背景列（今天高亮）
                          Positioned.fill(
                            child: ColoredBox(
                              color: d == todayWeekday
                                  ? AppColors.primary.withOpacity(0.04)
                                  : Colors.transparent,
                            ),
                          ),
                          // 网格线
                          for (var s = 1; s <= maxSections; s++)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: rowH * s,
                              child: Container(
                                  height: 0.6, color: AppColors.gridLine),
                            ),
                          // 课程块
                          for (final e in entries.where((e) => e.weekday == d))
                            _courseBlock(context, e, colW, rowH, periodTimes),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _courseBlock(BuildContext context, ScheduleEntry e, double colW,
      double rowH, List<List<int>> periodTimes) {
    final span = (e.endSection - e.startSection + 1).clamp(1, maxSections);
    final top = (e.startSection - 1) * rowH;
    final height = span * rowH - 3;
    final color = _colorFor(e.courseId);
    return Positioned(
      left: 1.5,
      right: 1.5,
      top: top + 1.5,
      height: height,
      child: GestureDetector(
        onLongPress: () => onLongPress(e),
        onTap: () => _showDetail(context, e, periodTimes),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(e.courseName,
                  maxLines: span >= 2 ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: span >= 2 ? 11.5 : 10.5,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: color)),
              if (span >= 2) ...[
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    e.location.isEmpty ? '' : '@${e.location}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9.5, color: color.withOpacity(0.85)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(
      BuildContext context, ScheduleEntry e, List<List<int>> periodTimes) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.courseName,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _kv('时间',
                  '${ScheduleParser.weekdayNames[e.weekday]} ${e.rawJc}（${ScheduleParser.timeRange(e, periodTimes)}）'),
              _kv('周次', e.rawWeeks),
              _kv('教室', e.location.isEmpty ? '未安排' : '${e.campus} ${e.location}'),
              _kv('教师', e.teacher.isEmpty ? '—' : e.teacher),
              if (e.credit?.isNotEmpty ?? false) _kv('学分', e.credit!),
              if (e.assessType?.isNotEmpty ?? false) _kv('考核', e.assessType!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondaryLight)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  /// 依据 courseId 稳定地分配一种蓝色系配色（同课程同色，不同课程略有区分）。
  static Color _colorFor(String courseId) {
    const palette = [
      AppColors.primary,
      AppColors.accent,
      AppColors.primaryDark,
      Color(0xFF3B82F6),
      Color(0xFF0891B2),
      Color(0xFF6366F1),
      Color(0xFF0EA5E9),
    ];
    final h = courseId.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    return palette[h % palette.length];
  }
}

class _UnplacedStrip extends StatelessWidget {
  final List<ScheduleEntry> entries;
  final void Function(ScheduleEntry) onTap;
  const _UnplacedStrip({required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.gridLine)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text('实践课 · 未排入周课表',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              const Spacer(),
              Text('${entries.length} 门',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondaryLight)),
            ],
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 132),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final e in entries)
                  _UnplacedTile(entry: e, onTap: () => onTap(e)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnplacedTile extends StatelessWidget {
  final ScheduleEntry entry;
  final VoidCallback onTap;
  const _UnplacedTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (entry.rawWeeks.trim().isNotEmpty) entry.rawWeeks.trim(),
      if (entry.location.isNotEmpty) entry.location,
      if (entry.teacher.isNotEmpty) entry.teacher,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  if (sub.isNotEmpty)
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textSecondaryLight),
          ],
        ),
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptySchedule({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_outlined,
              size: 46, color: AppColors.primary.withOpacity(0.4)),
          const SizedBox(height: 12),
          const Text('还没有课表数据',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('点击下方按钮从教务系统加载本学期课表',
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondaryLight)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('加载课表'),
          ),
        ],
      ),
    );
  }
}

class _RetryHint extends StatelessWidget {
  final VoidCallback onRetry;
  const _RetryHint({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 44, color: AppColors.primary.withOpacity(0.4)),
          const SizedBox(height: 12),
          const Text('课表加载失败',
              style: TextStyle(color: AppColors.textSecondaryLight)),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
