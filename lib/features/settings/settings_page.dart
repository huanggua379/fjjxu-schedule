import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/hud_card.dart';
import '../../data/local/settings_store.dart' show ThemeModeSetting;
import '../../domain/entities/entities.dart';
import '../auth/auth_controller.dart';
import '../background/background_sync.dart';
import '../course_manage/hidden_courses_page.dart';
import '../grade/grade_controller.dart';
import '../schedule/schedule_controller.dart';
import 'period_times_page.dart';

/// 设置页：学期校准、自动同步、上课提醒、成绩提醒、主题、隐藏课程管理、账户。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final student = ref.watch(authControllerProvider).student;
    final sem = ref.watch(currentSemesterProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          const Text('设置',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          // 账户
          _Section(title: 'ACCOUNT', icon: Icons.person_outline_rounded, child: HudCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (student?.name.isNotEmpty ?? false)
                        ? student!.name.characters.first
                        : '学',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student?.name ?? '未登录',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                        [
                          if ((student?.className ?? '').isNotEmpty) student!.className,
                          if ((student?.id ?? '').isNotEmpty) student!.id,
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _confirmLogout(context, ref),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('退出'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                ),
              ],
            ),
          )),
          const SizedBox(height: 20),

          // 学期
          _Section(
            title: 'SEMESTER',
            icon: Icons.calendar_month_outlined,
            child: HudCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Tile(
                    title: '当前学期',
                    subtitle: sem.displayName,
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondaryLight),
                    onTap: () => _pickSemester(context, ref, sem),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _Tile(
                    title: '开学第一周（周一）',
                    subtitle: s.semesterStartOverride ?? '按校历自动估算，点击校准',
                    trailing: const Icon(Icons.edit_calendar_outlined,
                        size: 20, color: AppColors.textSecondaryLight),
                    onTap: () => _pickSemesterStart(context, ref, s),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _Tile(
                    title: '上下课作息时间',
                    subtitle: '按学校实际作息校准每节起止时间（影响提醒与首页时间）',
                    trailing: const Icon(Icons.schedule_outlined,
                        size: 20, color: AppColors.textSecondaryLight),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PeriodTimesPage()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 同步
          _Section(
            title: 'AUTO SYNC',
            icon: Icons.sync_rounded,
            child: HudCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: s.autoSync,
                    title: const Text('自动同步课表与成绩'),
                    subtitle: Text(s.lastSyncTime == null
                        ? '尚未同步'
                        : '上次：${_fmt(s.lastSyncTime!)}'),
                    onChanged: (v) async {
                      await ctrl.setAutoSync(v);
                      await BackgroundSync.reschedule(
                          enabled: v, intervalMinutes: s.syncIntervalMinutes);
                    },
                  ),
                  if (s.autoSync) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _Tile(
                      title: '同步频率',
                      subtitle: _intervalLabel(s.syncIntervalMinutes),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondaryLight),
                      onTap: () => _pickInterval(context, ref, s),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 提醒
          _Section(
            title: 'REMINDERS',
            icon: Icons.notifications_active_outlined,
            child: HudCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: s.reminderEnabled,
                    title: const Text('上课提醒'),
                    subtitle: const Text('课程开始前提醒'),
                    onChanged: (v) async {
                      await ctrl.setReminderEnabled(v);
                      await _rescheduleReminders(ref, sem);
                    },
                  ),
                  if (s.reminderEnabled) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _Tile(
                      title: '提醒方式',
                      subtitle: s.reminderMode.label,
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondaryLight),
                      onTap: () => _pickRemindMode(context, ref, s, sem),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _Tile(
                      title: '提前时间',
                      subtitle: '${s.reminderMinutesBefore} 分钟',
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondaryLight),
                      onTap: () => _pickLeadTime(context, ref, s, sem),
                    ),
                  ],
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    value: s.gradeNotify,
                    title: const Text('新成绩提醒'),
                    subtitle: const Text('发现新发布的成绩时通知我'),
                    onChanged: ctrl.setGradeNotify,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    value: s.autoQueryGrade,
                    title: const Text('同步时自动查询成绩'),
                    onChanged: ctrl.setAutoQueryGrade,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 课程管理
          _Section(
            title: 'COURSES',
            icon: Icons.layers_outlined,
            child: HudCard(
              padding: EdgeInsets.zero,
              child: _Tile(
                title: '隐藏课程管理',
                subtitle: '恢复被隐藏的整门课程或单次课程',
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondaryLight),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const HiddenCoursesPage()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 外观
          _Section(
            title: 'APPEARANCE',
            icon: Icons.palette_outlined,
            child: HudCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final m in ThemeModeSetting.values)
                    RadioListTile<ThemeModeSetting>(
                      value: m,
                      groupValue: s.themeMode,
                      title: Text(_themeLabel(m)),
                      dense: true,
                      onChanged: (v) => v == null ? null : ctrl.setThemeMode(v),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 数据
          _Section(
            title: 'DATA',
            icon: Icons.storage_outlined,
            child: HudCard(
              padding: EdgeInsets.zero,
              child: _Tile(
                title: '清除本地数据',
                subtitle: '删除缓存的课表/成绩与本地设置（不影响教务系统）',
                titleColor: AppColors.danger,
                trailing: const Icon(Icons.delete_sweep_outlined,
                    color: AppColors.danger),
                onTap: () => _confirmClear(context, ref),
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Center(
            child: Text(
              '${AppConstants.appName} v${AppConstants.appVersion}\n数据仅存储在本机，通过 HTTPS 访问学校教务系统',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryLight,
                  height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  // -------- 交互 --------
  Future<void> _rescheduleReminders(WidgetRef ref, Semester sem) async {
    await ref.read(reminderServiceProvider).rescheduleAll(sem);
  }

  String _themeLabel(ThemeModeSetting m) => switch (m) {
        ThemeModeSetting.system => '跟随系统',
        ThemeModeSetting.light => '浅色',
        ThemeModeSetting.dark => '深色',
      };

  String _intervalLabel(int m) {
    if (m <= 0) return '仅手动';
    if (m < 60) return '每 $m 分钟';
    final h = m / 60;
    return '每 ${h == h.roundToDouble() ? h.toInt() : h.toStringAsFixed(1)} 小时';
  }

  String _fmt(DateTime t) =>
      '${t.month}-${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _pickSemester(BuildContext context, WidgetRef ref, Semester cur) {
    final now = DateTime.now();
    final opts = <Semester>[];
    for (var y = now.year; y >= now.year - 3; y--) {
      for (final q in [AppConstants.termFall, AppConstants.termSpring, AppConstants.termSummer]) {
        opts.add(Semester(xnm: q == AppConstants.termFall ? y : y - 1, xqm: q));
      }
    }
    _sheet(context, '选择学期', [
      for (final o in opts)
        RadioListTile<Semester>(
          value: o,
          groupValue: cur,
          title: Text(o.displayName),
          onChanged: (v) async {
            Navigator.pop(context);
            if (v != null) {
              await ref.read(settingsControllerProvider.notifier).setCurrentSemester(v);
              ref.invalidate(scheduleControllerProvider);
            }
          },
        ),
    ]);
  }

  Future<void> _pickSemesterStart(
      BuildContext context, WidgetRef ref, dynamic s) async {
    final ctrl = ref.read(settingsControllerProvider.notifier);
    DateTime initial = DateTime.now();
    if (s.semesterStartOverride != null) {
      initial = DateTime.tryParse(s.semesterStartOverride) ?? initial;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 2),
      helpText: '选择开学第一周的周一',
    );
    if (picked == null) return;
    final monday = picked.subtract(Duration(days: picked.weekday - 1));
    await ctrl.setSemesterStart(
        '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已校准开学日期，周次与提醒将据此计算')),
      );
    }
  }

  void _pickInterval(BuildContext context, WidgetRef ref, dynamic s) {
    const opts = [15, 30, 60, 180, 360, 720];
    _sheet(context, '同步频率', [
      for (final m in opts)
        RadioListTile<int>(
          value: m,
          groupValue: s.syncIntervalMinutes,
          title: Text(_intervalLabel(m)),
          onChanged: (v) async {
            Navigator.pop(context);
            if (v == null) return;
            await ref.read(settingsControllerProvider.notifier).setSyncInterval(v);
            await BackgroundSync.reschedule(enabled: s.autoSync, intervalMinutes: v);
          },
        ),
    ]);
  }

  void _pickRemindMode(
      BuildContext context, WidgetRef ref, dynamic s, Semester sem) {
    _sheet(context, '提醒方式', [
      for (final m in RemindMode.values)
        RadioListTile<RemindMode>(
          value: m,
          groupValue: s.reminderMode,
          title: Text(m.label),
          subtitle: m == RemindMode.notification ? null : const Text('闹钟模式需要授予精确闹钟权限'),
          onChanged: (v) async {
            Navigator.pop(context);
            if (v == null) return;
            await ref.read(settingsControllerProvider.notifier).setReminderMode(v);
            if (v != RemindMode.notification) {
              await ref.read(reminderServiceProvider).requestExactAlarmPermission();
            }
            await _rescheduleReminders(ref, sem);
          },
        ),
    ]);
  }

  void _pickLeadTime(
      BuildContext context, WidgetRef ref, dynamic s, Semester sem) {
    const opts = [5, 10, 15, 20, 30, 45, 60];
    _sheet(context, '提前提醒时间', [
      for (final m in opts)
        RadioListTile<int>(
          value: m,
          groupValue: s.reminderMinutesBefore,
          title: Text('提前 $m 分钟'),
          onChanged: (v) async {
            Navigator.pop(context);
            if (v == null) return;
            await ref.read(settingsControllerProvider.notifier).setReminderMinutes(v);
            await _rescheduleReminders(ref, sem);
          },
        ),
      ListTile(
        leading: const Icon(Icons.tune_rounded),
        title: const Text('自定义…'),
        onTap: () async {
          Navigator.pop(context);
          await _customLead(context, ref, s, sem);
        },
      ),
    ]);
  }

  Future<void> _customLead(
      BuildContext context, WidgetRef ref, dynamic s, Semester sem) async {
    final c = TextEditingController(text: '${s.reminderMinutesBefore}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义提前时间'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(suffixText: '分钟'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (v == null || v <= 0) return;
    await ref.read(settingsControllerProvider.notifier).setReminderMinutes(v);
    await _rescheduleReminders(ref, sem);
  }

  void _sheet(BuildContext context, String title, List<Widget> children) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              ...children,
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后需重新输入学号密码。已缓存的课表与成绩仍可查看。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
        ],
      ),
    );
    if (ok != true) return;
    // 先改登录态触发路由跳回登录页；后台任务取消失败不应阻塞退出。
    await ref.read(authControllerProvider.notifier).logout();
    try {
      await BackgroundSync.reschedule(enabled: false, intervalMinutes: 0);
    } catch (_) {
      // WorkManager 在部分设备上取消任务可能抛异常，忽略即可。
    }
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除本地数据'),
        content: const Text('将删除本机缓存的课表、成绩与所有本地设置（隐藏、提醒等）。此操作不影响教务系统，也不会退出登录。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(databaseProvider).clearAll();
    ref.invalidate(scheduleControllerProvider);
    ref.invalidate(gradeControllerProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('本地数据已清除')));
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: HudLabel(title, icon: icon),
        ),
        child,
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  const _Tile({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(title,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: titleColor ?? AppColors.textPrimaryLight)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondaryLight)),
      trailing: trailing,
    );
  }
}
