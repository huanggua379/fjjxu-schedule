import '../../domain/entities/entities.dart';
import '../local/app_database.dart';
import '../remote/grade_remote.dart';

/// 成绩统计（仅基于校方真实数据；GPA 用校方每门 jd 按学分加权）。
class GradeStats {
  final double? weightedGpa; // 加权平均绩点
  final double? averageScore; // 平均分（百分制/总评）
  final double totalCredits; // 已修学分（有成绩的）
  final int courseCount;
  const GradeStats({
    this.weightedGpa,
    this.averageScore,
    this.totalCredits = 0,
    this.courseCount = 0,
  });

  static GradeStats compute(List<Grade> grades) {
    final valid = grades.where((g) => g.scoreValue != null).toList();
    if (valid.isEmpty) {
      return const GradeStats();
    }
    double creditSum = 0;
    double gpaWeighted = 0;
    double gpaCreditSum = 0;
    double scoreSum = 0;
    for (final g in valid) {
      final xf = g.creditValue ?? 0;
      final jd = g.gpaValue;
      creditSum += xf;
      scoreSum += g.scoreValue!;
      if (jd != null && xf > 0) {
        gpaWeighted += jd * xf;
        gpaCreditSum += xf;
      }
    }
    return GradeStats(
      weightedGpa: gpaCreditSum > 0 ? gpaWeighted / gpaCreditSum : null,
      averageScore: scoreSum / valid.length,
      totalCredits: creditSum,
      courseCount: valid.length,
    );
  }
}

/// 成绩仓库：远程 + 本地缓存 + 新成绩检测（去重，避免重复提醒）。
class GradeRepository {
  GradeRepository({required GradeRemote remote, required AppDatabase db})
      : _remote = remote,
        _db = db;

  final GradeRemote _remote;
  final AppDatabase _db;

  /// 缓存优先读取全部成绩。
  Future<List<Grade>> getCachedGrades() => _db.allGrades();

  /// 刷新成绩，返回“新出现的成绩”（此前本地没有的 gradeId）。
  /// 失败抛异常且不清空旧数据。
  Future<List<Grade>> refresh({Semester? sem}) async {
    final old = await _db.allGrades();
    final oldIds = old.map((g) => g.gradeId).toSet();
    final fresh = await _remote.fetch(sem: sem);
    await _db.replaceGrades(fresh);
    final newly = fresh.where((g) => !oldIds.contains(g.gradeId)).toList();
    return newly;
  }

  /// 按学期分组
  Map<String, List<Grade>> groupByTerm(List<Grade> grades) {
    final map = <String, List<Grade>>{};
    for (final g in grades) {
      map.putIfAbsent(g.termName, () => []).add(g);
    }
    // 学期倒序（最新在前）
    final keys = map.keys.toList()
      ..sort((a, b) {
        final ga = grades.firstWhere((g) => g.termName == a);
        final gb = grades.firstWhere((g) => g.termName == b);
        final cmp = gb.xnm.compareTo(ga.xnm);
        return cmp != 0 ? cmp : gb.xqm.compareTo(ga.xqm);
      });
    return {for (final k in keys) k: map[k]!};
  }

  /// 所有出现过的学期（用于筛选），最新在前。
  List<Semester> availableSemesters(List<Grade> grades) {
    final set = <Semester>{};
    for (final g in grades) {
      if (g.xnm > 0 && g.xqm > 0) set.add(Semester(xnm: g.xnm, xqm: g.xqm));
    }
    final list = set.toList()
      ..sort((a, b) {
        final c = b.xnm.compareTo(a.xnm);
        return c != 0 ? c : b.xqm.compareTo(a.xqm);
      });
    return list;
  }
}
