import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/schedule_utils.dart';
import '../../core/widgets/hud_card.dart';

/// 上下课作息时间编辑页。
///
/// 正方课表接口不返回每节的起止钟表时间，只能按学校实际作息手动校准。
/// 这里编辑的每一节起止时间会写入本地设置，供首页时间显示、课表详情与
/// 上课提醒排程共同使用。修改后会自动重排提醒。
class PeriodTimesPage extends ConsumerStatefulWidget {
  const PeriodTimesPage({super.key});

  @override
  ConsumerState<PeriodTimesPage> createState() => _PeriodTimesPageState();
}

class _PeriodTimesPageState extends ConsumerState<PeriodTimesPage> {
  late List<List<int>> _times;

  @override
  void initState() {
    super.initState();
    _times = [
      for (final r in ref.read(periodTimesProvider)) [r[0], r[1]],
    ];
  }

  String _hhmm(int m) => ScheduleParser.minutesToHHmm(m);

  Future<void> _pick(int index, bool isStart) async {
    final cur = _times[index][isStart ? 0 : 1];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
      helpText: isStart ? '第 ${index + 1} 节 上课时间' : '第 ${index + 1} 节 下课时间',
    );
    if (picked == null) return;
    setState(() {
      _times[index][isStart ? 0 : 1] = picked.hour * 60 + picked.minute;
    });
  }

  void _addSection() {
    setState(() {
      final last = _times.isEmpty ? [8 * 60, 8 * 60 + 45] : _times.last;
      final start = last[1] + 10;
      _times.add([start, start + 45]);
    });
  }

  void _removeLast() {
    if (_times.isEmpty) return;
    setState(() => _times.removeLast());
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认作息'),
        content: const Text('将放弃当前编辑，恢复为内置的默认作息时间。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('恢复')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(periodTimesProvider.notifier).resetToDefault();
    setState(() {
      _times = [
        for (final r in ref.read(periodTimesProvider)) [r[0], r[1]],
      ];
    });
    await _reschedule();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已恢复默认作息')));
    }
  }

  String? _validate() {
    for (var i = 0; i < _times.length; i++) {
      if (_times[i][1] <= _times[i][0]) {
        return '第 ${i + 1} 节的下课时间必须晚于上课时间';
      }
      if (i > 0 && _times[i][0] < _times[i - 1][1]) {
        return '第 ${i + 1} 节的上课时间不能早于第 $i 节的下课时间';
      }
    }
    return null;
  }

  Future<void> _reschedule() async {
    final sem = ref.read(currentSemesterProvider);
    try {
      await ref.read(reminderServiceProvider).rescheduleAll(sem);
    } catch (_) {
      // 提醒排程失败不应阻塞作息保存。
    }
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await ref
        .read(periodTimesProvider.notifier)
        .save([for (final r in _times) [r[0], r[1]]]);
    await _reschedule();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('作息时间已保存，提醒已重新排程')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('上下课作息时间'),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('恢复默认'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check_rounded),
        label: const Text('保存'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
          children: [
            const Text(
              '按学校实际作息校准每节课的起止时间。正方教务系统不返回钟表时间，'
              '校准后首页时间显示与上课提醒会更准确。',
              style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondaryLight,
                  height: 1.5),
            ),
            const SizedBox(height: 16),
            HudCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _times.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    _row(i),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addSection,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('增加一节'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _times.isEmpty ? null : _removeLast,
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    label: const Text('删除末节'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(int i) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text('第 ${i + 1} 节',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: _timeChip(i, true)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded,
                size: 16, color: AppColors.textSecondaryLight),
          ),
          Expanded(child: _timeChip(i, false)),
        ],
      ),
    );
  }

  Widget _timeChip(int i, bool isStart) {
    final m = _times[i][isStart ? 0 : 1];
    return InkWell(
      onTap: () => _pick(i, isStart),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_hhmm(m),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            const SizedBox(width: 4),
            const Icon(Icons.edit_outlined,
                size: 14, color: AppColors.textSecondaryLight),
          ],
        ),
      ),
    );
  }
}
