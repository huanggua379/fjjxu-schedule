import '../../core/constants/app_constants.dart';
import '../../core/utils/schedule_utils.dart';
import '../../domain/entities/entities.dart';
import '../network/api_exception.dart';
import '../network/network_client.dart';

/// 课表拉取结果
class ScheduleResult {
  final Student student;
  final List<ScheduleEntry> entries;
  final Semester semester;
  const ScheduleResult({
    required this.student,
    required this.entries,
    required this.semester,
  });
}

/// 正方课表远程数据源。
class ScheduleRemote {
  ScheduleRemote(this._net);
  final NetworkClient _net;

  Future<ScheduleResult> fetch(Semester sem) async {
    try {
      await _net.init();
      final resp = await _net.postForm<Map<String, dynamic>>(
        AppConstants.scheduleUrl,
        {'xnm': sem.xnm, 'xqm': sem.xqm, 'kzlx': 'ck'},
        headers: {'Referer': AppConstants.scheduleReferer},
      );

      final data = resp.data;
      if (data == null) {
        throw const ParseException('课表数据为空');
      }
      // 未登录时正方会返回登录页 HTML 或 null
      if (resp.realUri.toString().contains('authserver')) {
        throw const AuthException();
      }

      final xsxx = (data['xsxx'] as Map?)?.cast<String, dynamic>() ?? {};
      final student = Student(
        name: (xsxx['XM'] ?? '') as String,
        id: (xsxx['XH'] ?? '') as String,
        className: (xsxx['BJMC'] ?? '') as String,
        major: (xsxx['ZYMC'] ?? '') as String,
      );

      final entries = <ScheduleEntry>[];
      final kbList = (data['kbList'] as List?) ?? const [];
      for (final raw in kbList) {
        final e = _parseKb(raw as Map, sem);
        if (e != null) entries.add(e);
      }
      // 实践课（sjkList）通常无固定星期节次，单独处理：有周次但星期/节次缺省
      final sjkList = (data['sjkList'] as List?) ?? const [];
      for (final raw in sjkList) {
        final e = _parseSjk(raw as Map, sem);
        if (e != null) entries.add(e);
      }

      return ScheduleResult(student: student, entries: entries, semester: sem);
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkClient.mapError(e);
    }
  }

  ScheduleEntry? _parseKb(Map raw, Semester sem) {
    final kcmc = (raw['kcmc'] ?? '') as String;
    if (kcmc.isEmpty) return null;
    final kchId = '${raw['kch_id'] ?? raw['kch'] ?? ''}';
    final jxbId = '${raw['jxb_id'] ?? ''}';
    final xqj = ScheduleParser.parseWeekday(
        raw['xqjmc'] as String?, int.tryParse('${raw['xqj'] ?? ''}'));
    final (startSec, endSec) = ScheduleParser.parseSections(raw['jc'] as String?);
    final weeks = ScheduleParser.parseWeeks(raw['zcd'] as String?);
    // 缺少星期/节次的排课（如部分实践、实验课）不再直接丢弃：
    // 置为“未排入”(weekday=0/startSection=0)，由课表页专门区域展示，
    // 避免整门课从课表里凭空消失。提醒/今日/周网格都会自动跳过它们。
    final courseId = '${kchId}_$jxbId';
    final entryId = '${courseId}_${xqj}_${raw['jc'] ?? ''}';
    return ScheduleEntry(
      entryId: entryId,
      courseId: courseId,
      courseName: kcmc,
      teacher: (raw['xm'] ?? '') as String,
      weekday: xqj,
      startSection: startSec,
      endSection: endSec == 0 ? startSec : endSec,
      weeks: weeks,
      location: (raw['cdmc'] ?? '') as String,
      campus: (raw['xqmc'] ?? '') as String,
      rawJc: (raw['jc'] ?? '') as String,
      rawWeeks: (raw['zcd'] ?? '') as String,
      credit: raw['xf']?.toString(),
      assessType: ((raw['khfsmc'] ?? '') as String).trim(),
      xnm: sem.xnm,
      xqm: sem.xqm,
    );
  }

  ScheduleEntry? _parseSjk(Map raw, Semester sem) {
    final kcmc = (raw['kcmc'] ?? '') as String;
    if (kcmc.isEmpty) return null;
    final kchId = '${raw['kch_id'] ?? raw['kch'] ?? ''}';
    final jxbId = '${raw['jxb_id'] ?? ''}';
    final weeks = ScheduleParser.parseWeeks(raw['qsjsz'] as String?);
    final courseId = '${kchId}_$jxbId';
    return ScheduleEntry(
      entryId: '${courseId}_sjk_${raw['xksj'] ?? kcmc}',
      courseId: courseId,
      courseName: kcmc,
      teacher: (raw['jsxm'] ?? raw['xm'] ?? '') as String,
      weekday: 0, // 实践课无固定星期
      startSection: 0,
      endSection: 0,
      weeks: weeks,
      location: (raw['cdmc'] ?? raw['xqmc'] ?? '') as String,
      campus: (raw['xqmc'] ?? '') as String,
      rawJc: '',
      rawWeeks: (raw['qsjsz'] ?? '') as String,
      credit: raw['xf']?.toString(),
      assessType: ((raw['khfsmc'] ?? '') as String).trim(),
      xnm: sem.xnm,
      xqm: sem.xqm,
    );
  }
}
