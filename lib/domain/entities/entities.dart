/// 领域实体。与正方接口字段解耦，UI/业务只依赖这些模型。
library;

/// 学生基本信息
class Student {
  final String name;
  final String id;
  final String className;
  final String major;
  final String? college;

  const Student({
    required this.name,
    required this.id,
    this.className = '',
    this.major = '',
    this.college,
  });

  static const Student empty = Student(name: '', id: '');

  bool get isEmpty => id.isEmpty;

  Map<String, dynamic> toMap() => {
        'name': name,
        'id': id,
        'className': className,
        'major': major,
        'college': college,
      };

  factory Student.fromMap(Map<String, dynamic> m) => Student(
        name: (m['name'] ?? '') as String,
        id: (m['id'] ?? '') as String,
        className: (m['className'] ?? '') as String,
        major: (m['major'] ?? '') as String,
        college: m['college'] as String?,
      );
}

/// 学期
class Semester {
  final int xnm; // 学年起始年，如 2026
  final int xqm; // 学期码：3/12/16

  const Semester({required this.xnm, required this.xqm});

  /// 学期序号（1/2/3）
  int get termIndex => switch (xqm) {
        3 => 1,
        12 => 2,
        16 => 3,
        _ => 0,
      };

  /// 显示名，如 “2026-2027 第1学期”
  String get displayName => '$xnm-${xnm + 1} 第$termIndex学期';

  String get shortName => '$xnm-${xnm + 1}-$termIndex';

  @override
  bool operator ==(Object other) =>
      other is Semester && other.xnm == xnm && other.xqm == xqm;

  @override
  int get hashCode => Object.hash(xnm, xqm);
}

/// 一门课程（教学班层面，可能对应多个 ScheduleEntry）
class Course {
  /// 稳定唯一 ID：kch_id + jxb_id（区分同名课/不同教师/不同教学班）
  final String courseId;
  final String name;
  final String teacher;
  final String? credit;
  final String? nature; // 课程性质 kcxzmc
  final String? category; // 课程类别 kclbmc
  final String? assessType; // 考核方式 khfsmc
  final String? teachingClass; // 教学班 jxbmc
  final int xnm;
  final int xqm;

  const Course({
    required this.courseId,
    required this.name,
    required this.teacher,
    this.credit,
    this.nature,
    this.category,
    this.assessType,
    this.teachingClass,
    required this.xnm,
    required this.xqm,
  });
}

/// 课表中的一次排课（某课程在周几第几节、哪些周、何地）
class ScheduleEntry {
  /// 稳定唯一 ID：kch_id + jxb_id + 星期 + 节次（用于隐藏/提醒去重）
  final String entryId;
  final String courseId;
  final String courseName;
  final String teacher;
  final int weekday; // 1..7 (周一..周日)
  final int startSection; // 起始节
  final int endSection; // 结束节
  final List<int> weeks; // 上课周次列表
  final String location; // 教室 cdmc
  final String campus; // 校区 xqmc
  final String rawJc; // 原始节次串，如 "1-2节"
  final String rawWeeks; // 原始周次串，如 "2-5周,7-14周"
  final String? credit;
  final String? assessType;
  final int xnm;
  final int xqm;

  const ScheduleEntry({
    required this.entryId,
    required this.courseId,
    required this.courseName,
    required this.teacher,
    required this.weekday,
    required this.startSection,
    required this.endSection,
    required this.weeks,
    required this.location,
    required this.campus,
    required this.rawJc,
    required this.rawWeeks,
    this.credit,
    this.assessType,
    required this.xnm,
    required this.xqm,
  });

  /// 是否在指定周次上课
  bool occursInWeek(int week) => weeks.contains(week);

  Map<String, dynamic> toMap() => {
        'entryId': entryId,
        'courseId': courseId,
        'courseName': courseName,
        'teacher': teacher,
        'weekday': weekday,
        'startSection': startSection,
        'endSection': endSection,
        'weeks': weeks.join(','),
        'location': location,
        'campus': campus,
        'rawJc': rawJc,
        'rawWeeks': rawWeeks,
        'credit': credit,
        'assessType': assessType,
        'xnm': xnm,
        'xqm': xqm,
      };

  factory ScheduleEntry.fromMap(Map<String, dynamic> m) => ScheduleEntry(
        entryId: m['entryId'] as String,
        courseId: m['courseId'] as String,
        courseName: (m['courseName'] ?? '') as String,
        teacher: (m['teacher'] ?? '') as String,
        weekday: m['weekday'] as int,
        startSection: m['startSection'] as int,
        endSection: m['endSection'] as int,
        weeks: (m['weeks'] as String? ?? '')
            .split(',')
            .where((e) => e.isNotEmpty)
            .map(int.parse)
            .toList(),
        location: (m['location'] ?? '') as String,
        campus: (m['campus'] ?? '') as String,
        rawJc: (m['rawJc'] ?? '') as String,
        rawWeeks: (m['rawWeeks'] ?? '') as String,
        credit: m['credit'] as String?,
        assessType: m['assessType'] as String?,
        xnm: m['xnm'] as int,
        xqm: m['xqm'] as int,
      );

  ScheduleEntry copyWith({String? location, String? teacher}) => ScheduleEntry(
        entryId: entryId,
        courseId: courseId,
        courseName: courseName,
        teacher: teacher ?? this.teacher,
        weekday: weekday,
        startSection: startSection,
        endSection: endSection,
        weeks: weeks,
        location: location ?? this.location,
        campus: campus,
        rawJc: rawJc,
        rawWeeks: rawWeeks,
        credit: credit,
        assessType: assessType,
        xnm: xnm,
        xqm: xqm,
      );
}

/// 成绩
class Grade {
  final String gradeId; // 稳定 ID
  final String courseName;
  final String teacher;
  final int xnm;
  final int xqm;
  final String termName; // 如 2025-2026 / 学期序号
  final String? credit;
  final String? score; // 总评 cj
  final String? gpa; // 绩点 jd（校方提供）
  final String? hundredScore; // 百分制 bfzcj
  final String? nature; // 课程性质
  final String? category; // 课程类别
  final String? assessType; // 考核方式
  final String? examType; // 考试性质 ksxz
  // 成绩构成（本校通常为 null，仅在有数据时展示，绝不虚构）
  final String? usualScore; // 平时 pscj
  final String? midScore; // 期中 qzcj
  final String? expScore; // 实验 sycj
  final String? finalScore; // 期末 qmcj

  const Grade({
    required this.gradeId,
    required this.courseName,
    required this.teacher,
    required this.xnm,
    required this.xqm,
    required this.termName,
    this.credit,
    this.score,
    this.gpa,
    this.hundredScore,
    this.nature,
    this.category,
    this.assessType,
    this.examType,
    this.usualScore,
    this.midScore,
    this.expScore,
    this.finalScore,
  });

  /// 是否有成绩构成明细
  bool get hasComponents =>
      [usualScore, midScore, expScore, finalScore].any((e) => e != null && e.isNotEmpty);

  double? get scoreValue => double.tryParse(score ?? '');
  double? get gpaValue => double.tryParse(gpa ?? '');
  double? get creditValue => double.tryParse(credit ?? '');

  Map<String, dynamic> toMap() => {
        'gradeId': gradeId,
        'courseName': courseName,
        'teacher': teacher,
        'xnm': xnm,
        'xqm': xqm,
        'termName': termName,
        'credit': credit,
        'score': score,
        'gpa': gpa,
        'hundredScore': hundredScore,
        'nature': nature,
        'category': category,
        'assessType': assessType,
        'examType': examType,
        'usualScore': usualScore,
        'midScore': midScore,
        'expScore': expScore,
        'finalScore': finalScore,
      };

  factory Grade.fromMap(Map<String, dynamic> m) => Grade(
        gradeId: m['gradeId'] as String,
        courseName: (m['courseName'] ?? '') as String,
        teacher: (m['teacher'] ?? '') as String,
        xnm: m['xnm'] as int,
        xqm: m['xqm'] as int,
        termName: (m['termName'] ?? '') as String,
        credit: m['credit'] as String?,
        score: m['score'] as String?,
        gpa: m['gpa'] as String?,
        hundredScore: m['hundredScore'] as String?,
        nature: m['nature'] as String?,
        category: m['category'] as String?,
        assessType: m['assessType'] as String?,
        examType: m['examType'] as String?,
        usualScore: m['usualScore'] as String?,
        midScore: m['midScore'] as String?,
        expScore: m['expScore'] as String?,
        finalScore: m['finalScore'] as String?,
      );
}

/// 提醒方式
enum RemindMode { notification, alarm, both }

extension RemindModeX on RemindMode {
  String get label => switch (this) {
        RemindMode.notification => '通知',
        RemindMode.alarm => '闹钟',
        RemindMode.both => '通知 + 闹钟',
      };

  String get key => name;
  static RemindMode fromKey(String? k) => RemindMode.values.firstWhere(
        (e) => e.name == k,
        orElse: () => RemindMode.notification,
      );
}

/// 单门课程的提醒设置（未设置则用全局默认）
class CourseReminderSetting {
  final String courseId;
  final bool enabled;
  final RemindMode mode;
  final int minutesBefore; // <=0 表示用全局默认

  const CourseReminderSetting({
    required this.courseId,
    this.enabled = true,
    this.mode = RemindMode.notification,
    this.minutesBefore = 0,
  });

  Map<String, dynamic> toMap() => {
        'courseId': courseId,
        'enabled': enabled ? 1 : 0,
        'mode': mode.key,
        'minutesBefore': minutesBefore,
      };

  factory CourseReminderSetting.fromMap(Map<String, dynamic> m) =>
      CourseReminderSetting(
        courseId: m['courseId'] as String,
        enabled: (m['enabled'] ?? 1) == 1,
        mode: RemindModeX.fromKey(m['mode'] as String?),
        minutesBefore: (m['minutesBefore'] ?? 0) as int,
      );
}
