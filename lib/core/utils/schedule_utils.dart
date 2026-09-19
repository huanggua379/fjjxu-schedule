import '../constants/app_constants.dart';
import '../../domain/entities/entities.dart';

/// 正方课表字段解析工具：周次串、节次串、节次->钟表时间。
class ScheduleParser {
  ScheduleParser._();

  /// 解析周次串，如 "2-5周,7-14周" / "1-16周" / "3周" / "1-16周(单)"。
  /// 返回展开后的周次列表。
  static List<int> parseWeeks(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final s = raw.replaceAll('周', '').trim();
    // 单双周标记
    bool onlyOdd = s.contains('单');
    bool onlyEven = s.contains('双');
    final cleaned = s.replaceAll(RegExp(r'[（(单双)）]'), '');
    final weeks = <int>{};
    for (final part in cleaned.split(RegExp(r'[,，、]'))) {
      final p = part.trim();
      if (p.isEmpty) continue;
      final range = p.split(RegExp(r'[-~]'));
      if (range.length == 2) {
        final a = int.tryParse(range[0].trim());
        final b = int.tryParse(range[1].trim());
        if (a != null && b != null) {
          for (var i = a; i <= b; i++) {
            weeks.add(i);
          }
        }
      } else {
        final a = int.tryParse(p);
        if (a != null) weeks.add(a);
      }
    }
    var list = weeks.toList()..sort();
    if (onlyOdd) list = list.where((w) => w.isOdd).toList();
    if (onlyEven) list = list.where((w) => w.isEven).toList();
    return list;
  }

  /// 解析节次串，如 "1-2节" -> (1,2)；"3节" -> (3,3)；"1-2,3-4节" -> (1,4)。
  static (int, int) parseSections(String? raw) {
    if (raw == null || raw.trim().isEmpty) return (0, 0);
    final s = raw.replaceAll('节', '').trim();
    final nums = <int>[];
    for (final part in s.split(RegExp(r'[,，、]'))) {
      final range = part.split(RegExp(r'[-~]'));
      for (final r in range) {
        final n = int.tryParse(r.trim());
        if (n != null) nums.add(n);
      }
    }
    if (nums.isEmpty) return (0, 0);
    nums.sort();
    return (nums.first, nums.last);
  }

  /// 星期中文 -> 1..7
  static int parseWeekday(String? raw, [int? fallback]) {
    if (raw == null) return fallback ?? 0;
    const map = {
      '星期一': 1, '周一': 1, '星期一 ': 1,
      '星期二': 2, '周二': 2,
      '星期三': 3, '周三': 3,
      '星期四': 4, '周四': 4,
      '星期五': 5, '周五': 5,
      '星期六': 6, '周六': 6,
      '星期日': 7, '星期天': 7, '周日': 7,
    };
    return map[raw.trim()] ?? fallback ?? int.tryParse(raw.trim()) ?? 0;
  }

  static const weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  /// 节次(1-based) -> 当天分钟偏移 [起, 止]。超出默认表则按每节45分钟推算。
  static (int, int) sectionToMinutes(
    int startSection,
    int endSection, [
    List<List<int>>? periodTimes,
  ]) {
    final table = periodTimes ?? AppConstants.defaultPeriodTimes;
    int minFor(int sec, bool end) {
      if (sec >= 1 && sec <= table.length) {
        final r = table[sec - 1];
        return end ? r[1] : r[0];
      }
      // 兜底：8:00 起，每节 45 分钟 + 课间
      final base = 8 * 60;
      return base + (sec - 1) * 50 + (end ? 45 : 0);
    }

    return (minFor(startSection, false), minFor(endSection, true));
  }

  /// 分钟偏移 -> "HH:mm"
  static String minutesToHHmm(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// 一次排课的钟表时间区间串，如 "14:00 - 15:40"
  static String timeRange(ScheduleEntry e, [List<List<int>>? periodTimes]) {
    final (a, b) = sectionToMinutes(e.startSection, e.endSection, periodTimes);
    return '${minutesToHHmm(a)} - ${minutesToHHmm(b)}';
  }
}

/// 学期与周次计算
class TermUtils {
  TermUtils._();

  /// 按当前日期推断学期（无校历时用）。9月~次年1月=秋季(第一学期)。
  static Semester guessCurrentSemester([DateTime? now]) {
    now ??= DateTime.now();
    final m = now.month, y = now.year;
    if (m >= 9 || m == 1) {
      return Semester(xnm: m >= 9 ? y : y - 1, xqm: AppConstants.termFall);
    } else if (m >= 2 && m <= 6) {
      return Semester(xnm: y - 1, xqm: AppConstants.termSpring);
    }
    return Semester(xnm: y - 1, xqm: AppConstants.termSummer);
  }

  /// 根据学期开始日期计算当前周次（第几周，1-based）。
  /// 若未知开学日期，返回 null（UI 显示“—”）。
  static int? currentWeek(DateTime semesterStart, [DateTime? now]) {
    now ??= DateTime.now();
    final start = DateTime(semesterStart.year, semesterStart.month, semesterStart.day);
    final today = DateTime(now.year, now.month, now.day);
    if (today.isBefore(start)) return null;
    // 以周一为一周起点
    final startMonday = start.subtract(Duration(days: start.weekday - 1));
    final todayMonday = today.subtract(Duration(days: today.weekday - 1));
    final diffDays = todayMonday.difference(startMonday).inDays;
    return diffDays ~/ 7 + 1;
  }

  /// 默认学期开始日期估算：秋季约 9 月第 1 个周一，春季约 2 月底/3 月第 1 个周一。
  /// 仅在校历缺失时兜底；用户可在设置中校准。
  static DateTime estimateSemesterStart(Semester s) {
    if (s.xqm == AppConstants.termFall) {
      return _firstMonday(DateTime(s.xnm, 9, 1));
    } else if (s.xqm == AppConstants.termSpring) {
      return _firstMonday(DateTime(s.xnm + 1, 2, 24));
    }
    return _firstMonday(DateTime(s.xnm + 1, 7, 1));
  }

  static DateTime _firstMonday(DateTime d) {
    while (d.weekday != DateTime.monday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }
}
