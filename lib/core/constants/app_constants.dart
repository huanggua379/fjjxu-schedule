/// 全局常量：接口地址、功能码、默认配置。
/// 学校教务系统 = 金智(wisedu)SSO + 正方(zfsoft) jwglxt。
class AppConstants {
  AppConstants._();

  static const String appName = '课本';
  static const String appVersion = '1.0.0';

  // ---- 站点 ----
  static const String authBaseUrl = 'https://authserver.fjjxu.edu.cn';
  static const String jwxtBaseUrl = 'https://jwxt.fjjxu.edu.cn';

  static const String ssoService =
      'https://jwxt.fjjxu.edu.cn/sso/jznewsixlogin';
  static final String authLoginUrl =
      '$authBaseUrl/authserver/login?service=${Uri.encodeComponent(ssoService)}';

  static const String menuInitUrl =
      '$jwxtBaseUrl/jwglxt/xtgl/index_initMenu.html?jsdm=xs';

  // 课表（正方）
  static const String scheduleUrl =
      '$jwxtBaseUrl/jwglxt/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151';
  static const String scheduleReferer =
      '$jwxtBaseUrl/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151';

  // 成绩（正方·学生个人成绩，必须带 doType=query）
  static const String gradeUrl =
      '$jwxtBaseUrl/jwglxt/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005';
  static const String gradeReferer =
      '$jwxtBaseUrl/jwglxt/cjcx/cjcx_cxDgXscj.html?gnmkdm=N305005';

  // ---- 学期码（正方约定）----
  static const int termFall = 3; // 第一学期(秋)
  static const int termSpring = 12; // 第二学期(春)
  static const int termSummer = 16; // 第三学期(夏)

  // ---- 网络 ----
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  // ---- 提醒默认 ----
  static const int defaultRemindMinutes = 15;

  // ---- 后台同步 ----
  static const String syncTaskName = 'kebenPeriodicSync';

  // ---- 安全存储 key ----
  static const String ksUsername = 'ks_username';
  static const String ksPassword = 'ks_password';
  static const String ksCookies = 'ks_cookies';

  /// 默认作息时间（节次 -> 起止分钟）。可在设置中调整。
  /// 注意：正方课表接口不返回上下课钟表时间，此处为可配置默认值，
  /// 用户应按福建江夏学院实际作息时间校准（已知限制，见 README）。
  static const List<List<int>> defaultPeriodTimes = [
    [8 * 60, 8 * 60 + 45], // 1
    [9 * 60, 9 * 60 + 45], // 2
    [10 * 60 + 10, 10 * 60 + 55], // 3
    [11 * 60, 11 * 60 + 45], // 4
    [14 * 60, 14 * 60 + 45], // 5
    [14 * 60 + 55, 15 * 60 + 40], // 6
    [16 * 60, 16 * 60 + 45], // 7
    [16 * 60 + 55, 17 * 60 + 40], // 8
    [19 * 60, 19 * 60 + 45], // 9
    [20 * 60, 20 * 60 + 45], // 10
    [21 * 60, 21 * 60 + 45], // 11
    [22 * 60 - 5, 22 * 60 + 40], // 12
  ];
}
