import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/schedule_utils.dart';
import '../../core/widgets/hud_card.dart';
import '../../domain/entities/entities.dart';
import '../auth/auth_controller.dart';
import '../schedule/schedule_controller.dart';

/// 首页：今日课程 + 当前/下一节课状态 + 快速同步。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sem = ref.watch(currentSemesterProvider);
    final week = ref.watch(currentWeekProvider);
    final scheduleAsync = ref.watch(scheduleControllerProvider(sem));
    final today = ref.watch(todayClassesProvider);
    final student = ref.watch(authControllerProvider).student;
    final periodTimes = ref.watch(periodTimesProvider);

    return GridBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(context, ref, sem),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(student: student, sem: sem, week: week),
                const SizedBox(height: 18),
                _NowCard(today: today, week: week, periodTimes: periodTimes),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const HudLabel("TODAY'S SCHEDULE",
                        icon: Icons.calendar_today_rounded),
                    const Spacer(),
                    Text(
                      '共 ${today.length} 节',
                      style: AppTextStyles.hudLabelMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                scheduleAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => _EmptyHint(
                    icon: Icons.cloud_off_rounded,
                    text: '课表加载失败，下拉可重试',
                  ),
                  data: (_) => today.isEmpty
                      ? const _EmptyHint(
                          icon: Icons.wb_sunny_outlined,
                          text: '今天没有安排课程，好好休息～',
                        )
                      : Column(
                          children: [
                            for (final e in today)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _TodayClassCard(
                                    entry: e, week: week, periodTimes: periodTimes),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref, Semester sem) async {
    final result =
        await ref.read(scheduleControllerProvider(sem).notifier).refresh();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.success) {
      final d = result.diff;
      String msg = '已是最新';
      final parts = <String>[];
      if (d.added.isNotEmpty) parts.add('新增 ${d.added.length} 门');
      if (d.removed.isNotEmpty) parts.add('取消 ${d.removed.length} 门');
      if (d.changed.isNotEmpty) parts.add('${d.changed.length} 项调整');
      if (parts.isNotEmpty) msg = '课表更新：${parts.join('，')}';
      if (result.newGrades.isNotEmpty) {
        msg += '；新成绩 ${result.newGrades.length} 门';
      }
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? '同步失败，正在显示上次数据')),
      );
    }
  }
}

class _Header extends StatelessWidget {
  final Student? student;
  final Semester sem;
  final int? week;
  const _Header({this.student, required this.sem, this.week});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final dateStr = '${now.month.toString().padLeft(2, '0')}月'
        '${now.day.toString().padLeft(2, '0')}日 ${weekdays[now.weekday - 1]}';
    final name = (student?.name.isNotEmpty ?? false) ? student!.name : '同学';
    final hour = now.hour;
    final greet = hour < 6
        ? '夜深了'
        : hour < 11
            ? '早上好'
            : hour < 14
                ? '中午好'
                : hour < 18
                    ? '下午好'
                    : '晚上好';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greet，$name',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(dateStr,
                  style: const TextStyle(
                      color: AppColors.textSecondaryLight, fontSize: 13)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Text(
                week != null ? '第 $week 周' : '周次未校准',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            Text(sem.displayName,
                style: const TextStyle(
                    color: AppColors.textSecondaryLight, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

/// 当前/下一节课状态卡。
class _NowCard extends StatelessWidget {
  final List<ScheduleEntry> today;
  final int? week;
  final List<List<int>> periodTimes;
  const _NowCard({
    required this.today,
    this.week,
    required this.periodTimes,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;

    ScheduleEntry? ongoing;
    ScheduleEntry? next;
    int ongoingEnd = 0;
    for (final e in today) {
      if (week != null && e.weeks.isNotEmpty && !e.weeks.contains(week!)) {
        continue;
      }
      final (s, en) = ScheduleParser.sectionToMinutes(
          e.startSection, e.endSection, periodTimes);
      if (nowMin >= s && nowMin <= en) {
        ongoing = e;
        ongoingEnd = en;
        break;
      }
      if (nowMin < s && (next == null || s < _startMin(next, periodTimes))) {
        next = e;
      }
    }

    return HudCard(
      glowIntensity: 0.12,
      borderColor: AppColors.primary.withOpacity(0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (ongoing != null) const LiveDot(),
              SizedBox(width: ongoing == null ? 0 : 8),
              HudLabel(
                ongoing != null ? 'IN CLASS NOW' : 'NEXT UP',
                icon: ongoing != null
                    ? Icons.play_circle_outline_rounded
                    : Icons.schedule_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (ongoing != null)
            _StatusBody(
              title: ongoing.courseName,
              subtitle: ongoing.location.isEmpty
                  ? ongoing.teacher
                  : '${ongoing.location} · ${ongoing.teacher}',
              time: ScheduleParser.timeRange(ongoing, periodTimes),
              trailing: '剩 ${_remain(nowMin, ongoingEnd)} 分钟',
              accent: AppColors.live,
            )
          else if (next != null)
            _StatusBody(
              title: next.courseName,
              subtitle: next.location.isEmpty
                  ? next.teacher
                  : '${next.location} · ${next.teacher}',
              time: ScheduleParser.timeRange(next, periodTimes),
              trailing: '${_until(nowMin, _startMin(next, periodTimes))} 后开始',
              accent: AppColors.primary,
            )
          else
            const _StatusBody(
              title: '今天没有更多课程',
              subtitle: '好好放松，或预习明天的内容',
              time: '--:--',
              trailing: '',
              accent: AppColors.textSecondaryLight,
            ),
        ],
      ),
    );
  }

  static int _startMin(ScheduleEntry e, List<List<int>> periodTimes) =>
      ScheduleParser.sectionToMinutes(
          e.startSection, e.endSection, periodTimes)
          .$1;

  static int _remain(int nowMin, int endMin) =>
      (endMin - nowMin).clamp(0, 999);

  static String _until(int nowMin, int startMin) {
    final d = startMin - nowMin;
    if (d <= 0) return '即将';
    if (d < 60) return '$d 分钟';
    final h = d ~/ 60;
    final m = d % 60;
    return m == 0 ? '$h 小时' : '$h 小时 $m 分';
  }
}

class _StatusBody extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final String trailing;
  final Color accent;
  const _StatusBody({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.trailing,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 54,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondaryLight)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(time,
                style: AppTextStyles.techNumber
                    .copyWith(fontSize: 18, color: accent)),
            if (trailing.isNotEmpty)
              Text(trailing,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondaryLight)),
          ],
        ),
      ],
    );
  }
}

class _TodayClassCard extends StatelessWidget {
  final ScheduleEntry entry;
  final int? week;
  final List<List<int>> periodTimes;
  const _TodayClassCard({
    required this.entry,
    this.week,
    required this.periodTimes,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final (s, en) = ScheduleParser.sectionToMinutes(
        entry.startSection, entry.endSection, periodTimes);
    final ongoing = nowMin >= s && nowMin <= en;
    final finished = nowMin > en;

    return HudCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderColor: ongoing
          ? AppColors.live.withOpacity(0.5)
          : AppColors.hudLine,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ScheduleParser.minutesToHHmm(s),
                  style: AppTextStyles.techNumber.copyWith(
                      fontSize: 16,
                      color: ongoing
                          ? AppColors.live
                          : finished
                              ? AppColors.textSecondaryLight
                              : AppColors.primary)),
              Text('${entry.startSection}-${entry.endSection}节',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondaryLight)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: finished
                            ? AppColors.textSecondaryLight
                            : AppColors.textPrimaryLight)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (entry.location.isNotEmpty) ...[
                      const Icon(Icons.place_outlined,
                          size: 13, color: AppColors.textSecondaryLight),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(entry.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight)),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (entry.teacher.isNotEmpty)
                      Flexible(
                        child: Text(entry.teacher,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (ongoing)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: LiveDot(size: 8),
            )
          else if (finished)
            const Icon(Icons.check_circle_outline_rounded,
                size: 18, color: AppColors.textSecondaryLight),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.primary.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(text,
              style: const TextStyle(
                  color: AppColors.textSecondaryLight, fontSize: 14)),
        ],
      ),
    );
  }
}
