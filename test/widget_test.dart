import 'package:flutter_test/flutter_test.dart';
import 'package:keben/core/utils/schedule_utils.dart';
import 'package:keben/domain/entities/entities.dart';

void main() {
  group('ScheduleParser.parseWeeks', () {
    test('展开区间与多段', () {
      expect(ScheduleParser.parseWeeks('2-5周,7-8周'), [2, 3, 4, 5, 7, 8]);
    });

    test('单双周过滤', () {
      expect(ScheduleParser.parseWeeks('1-6周(单)'), [1, 3, 5]);
      expect(ScheduleParser.parseWeeks('1-6周(双)'), [2, 4, 6]);
    });

    test('空输入返回空', () {
      expect(ScheduleParser.parseWeeks(''), isEmpty);
      expect(ScheduleParser.parseWeeks(null), isEmpty);
    });
  });

  group('ScheduleParser.parseSections', () {
    test('区间与单节', () {
      expect(ScheduleParser.parseSections('1-2节'), (1, 2));
      expect(ScheduleParser.parseSections('3节'), (3, 3));
      expect(ScheduleParser.parseSections('1-2,3-4节'), (1, 4));
    });
  });

  test('parseWeekday 中文映射', () {
    expect(ScheduleParser.parseWeekday('星期三'), 3);
    expect(ScheduleParser.parseWeekday('周日'), 7);
  });

  test('minutesToHHmm 格式化', () {
    expect(ScheduleParser.minutesToHHmm(8 * 60 + 5), '08:05');
    expect(ScheduleParser.minutesToHHmm(14 * 60), '14:00');
  });

  test('TermUtils.currentWeek 以周一为起点', () {
    final start = DateTime(2026, 9, 7); // 周一
    expect(TermUtils.currentWeek(start, DateTime(2026, 9, 7)), 1);
    expect(TermUtils.currentWeek(start, DateTime(2026, 9, 13)), 1); // 周日仍第1周
    expect(TermUtils.currentWeek(start, DateTime(2026, 9, 14)), 2); // 下周一
    expect(TermUtils.currentWeek(start, DateTime(2026, 9, 1)), isNull); // 开学前
  });

  test('ScheduleEntry.occursInWeek', () {
    const e = ScheduleEntry(
      entryId: 'x',
      courseId: 'c',
      courseName: 'n',
      teacher: 't',
      weekday: 1,
      startSection: 1,
      endSection: 2,
      weeks: [1, 2, 3],
      location: '',
      campus: '',
      rawJc: '1-2节',
      rawWeeks: '1-3周',
      xnm: 2026,
      xqm: 3,
    );
    expect(e.occursInWeek(2), isTrue);
    expect(e.occursInWeek(4), isFalse);
  });

  test('Grade 仅在真实字段存在时报告构成明细', () {
    const g = Grade(
      gradeId: '1',
      courseName: 'c',
      teacher: 't',
      xnm: 2026,
      xqm: 3,
      termName: '2026-2027 第1学期',
      score: '88',
      gpa: '3.7',
    );
    expect(g.hasComponents, isFalse);
    expect(g.scoreValue, 88);
    expect(g.gpaValue, 3.7);
  });
}
