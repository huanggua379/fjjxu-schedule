import '../../core/constants/app_constants.dart';
import '../../domain/entities/entities.dart';
import '../network/api_exception.dart';
import '../network/network_client.dart';

/// 正方·学生个人成绩远程数据源。
/// 接口：POST /jwglxt/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005
/// 返回 {totalCount, items:[...]}；本校成绩构成(平时/期中/实验/期末)通常为 null。
class GradeRemote {
  GradeRemote(this._net);
  final NetworkClient _net;

  /// [sem] 为 null 时拉取全部历史成绩。
  Future<List<Grade>> fetch({Semester? sem}) async {
    try {
      await _net.init();
      final body = <String, dynamic>{
        'xnm': sem?.xnm.toString() ?? '',
        'xqm': sem?.xqm.toString() ?? '',
        '_search': 'false',
        'queryModel.showCount': '500',
        'queryModel.currentPage': '1',
        'queryModel.columnName': '',
        'queryModel.sortName': '',
        'queryModel.sortOrder': '',
        'queryModel.queryShowCount': 'true',
      };
      final resp = await _net.postForm<Map<String, dynamic>>(
        AppConstants.gradeUrl,
        body,
        headers: {'Referer': AppConstants.gradeReferer},
      );
      if (resp.realUri.toString().contains('authserver')) {
        throw const AuthException();
      }
      final data = resp.data;
      if (data == null) throw const ParseException('成绩数据为空');

      final items = (data['items'] as List?) ?? const [];
      final grades = <Grade>[];
      for (final raw in items) {
        final g = _parse(raw as Map);
        if (g != null) grades.add(g);
      }
      return grades;
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkClient.mapError(e);
    }
  }

  Grade? _parse(Map raw) {
    final kcmc = (raw['kcmc'] ?? '') as String;
    if (kcmc.isEmpty) return null;
    final xnm = int.tryParse('${raw['xnm'] ?? 0}') ?? 0;
    final xqm = int.tryParse('${raw['xqm'] ?? 0}') ?? 0;
    final kchId = '${raw['kch_id'] ?? raw['kch'] ?? ''}';
    final jxbId = '${raw['jxb_id'] ?? ''}';
    final id = (raw['row_id'] ?? raw['bh'] ?? '') as String;
    final gradeId = id.isNotEmpty
        ? id
        : '${xnm}_${xqm}_${kchId}_$jxbId';

    String? s(dynamic v) {
      if (v == null) return null;
      final str = v.toString().trim();
      return str.isEmpty ? null : str;
    }

    final termIndex = switch (xqm) {
      3 => 1,
      12 => 2,
      16 => 3,
      _ => 0,
    };
    return Grade(
      gradeId: gradeId,
      courseName: kcmc,
      teacher: (raw['jsxm'] ?? '') as String,
      xnm: xnm,
      xqm: xqm,
      termName: '$xnm-${xnm + 1} 第$termIndex学期',
      credit: s(raw['xf']),
      score: s(raw['cj']),
      gpa: s(raw['jd']),
      hundredScore: s(raw['bfzcj']),
      nature: s(raw['kcxzmc']),
      category: s(raw['kclbmc']),
      assessType: s(raw['khfsmc']),
      examType: s(raw['ksxz']),
      usualScore: s(raw['pscj']),
      midScore: s(raw['qzcj']),
      expScore: s(raw['sycj']),
      finalScore: s(raw['qmcj']),
    );
  }
}
