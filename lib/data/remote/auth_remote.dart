import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/schedule_utils.dart';
import '../../domain/entities/entities.dart';
import '../crypto/wisedu_crypto.dart';
import '../network/api_exception.dart';
import '../network/network_client.dart';

/// 登录结果
class AuthResult {
  final bool success;
  final Student? student;
  final AppException? error;
  const AuthResult.ok(this.student)
      : success = true,
        error = null;
  const AuthResult.fail(this.error)
      : success = false,
        student = null;
}

/// 金智 SSO + 正方教务 的认证远程数据源。
class AuthRemote {
  AuthRemote(this._net);
  final NetworkClient _net;

  // 从登录页 HTML 提取 <input> 的 value（兼容属性顺序）
  static final _inputRe = RegExp(r'<input[^>]*>', caseSensitive: false);
  static final _valueRe = RegExp(r'value="([^"]*)"');

  String? _inputValue(String html, String key, {String attr = 'name'}) {
    for (final m in _inputRe.allMatches(html)) {
      final tag = m.group(0)!;
      if (tag.contains('$attr="$key"')) {
        final v = _valueRe.firstMatch(tag);
        return v?.group(1) ?? '';
      }
    }
    return null;
  }

  /// 学号密码登录。成功后 dio 的 cookieJar 已持有正方会话。
  Future<AuthResult> login(String username, String password) async {
    try {
      await _net.init();

      // 1) 取登录页，解析一次性令牌与加密盐
      final pageResp = await _net.get<String>(
        AppConstants.authLoginUrl,
        headers: {'Referer': AppConstants.jwxtBaseUrl},
      );
      final html = pageResp.data ?? '';
      final lt = _inputValue(html, 'lt');
      final execution = _inputValue(html, 'execution');
      final salt = _inputValue(html, 'pwdDefaultEncryptSalt', attr: 'id');
      if (lt == null || execution == null || salt == null || salt.isEmpty) {
        return const AuthResult.fail(
            ServerException('登录页解析失败，教务系统结构可能已变化'));
      }

      // 验证码检测：正常不需要；触发滑块时不绕过
      final slider = _inputValue(html, 'isSliderCaptcha', attr: 'id');
      if (slider != null && slider.isNotEmpty) {
        return const AuthResult.fail(CaptchaRequiredException());
      }

      // 2) 提交登录（password = AES/CBC 密文）。
      //    禁用自动重定向：Dio 对 POST 的 302 不会自动跟随，必须手动跟随，
      //    否则 CAS 票据永不兑现、正方会话建立不起来，登录必失败。
      final encrypted = WiseduCrypto.encryptPassword(password, salt);
      final form = {
        'username': username,
        'password': encrypted,
        'lt': lt,
        'dllt': _inputValue(html, 'dllt') ?? 'userNamePasswordLogin',
        'execution': execution,
        '_eventId': _inputValue(html, '_eventId') ?? 'submit',
        'rmShown': _inputValue(html, 'rmShown') ?? '1',
      };
      var resp = await _net.postForm<String>(
        AppConstants.authLoginUrl,
        form,
        headers: {'Referer': AppConstants.authLoginUrl},
        followRedirects: false,
      );

      // 3) 手动跟随 3xx 重定向链，用 CAS 票据换取正方会话(JSESSIONID)：
      //    authserver 302(ticket=ST-…) -> jwxt?ticket -> ;jsessionid ->
      //    /jwglxt/ticketlogin -> login_slogin -> index_initMenu(200)。
      resp = await _followRedirects(resp);

      // 4) 判定是否登录成功：成功会落到 jwglxt 域，失败回到 authserver/login
      final finalUrl = resp.realUri.toString();
      final body = resp.data ?? '';
      final stillLogin = finalUrl.contains('authserver') &&
          (finalUrl.contains('login') || body.contains('pwdDefaultEncryptSalt'));
      if (stillLogin) {
        if (body.contains('验证码') || body.contains('captcha')) {
          return const AuthResult.fail(CaptchaRequiredException());
        }
        return const AuthResult.fail(CredentialException());
      }

      // 5) 会话已建立，顺带拿学生信息
      final student = await _fetchStudent();
      return AuthResult.ok(student);
    } on AppException catch (e) {
      return AuthResult.fail(e);
    } catch (e) {
      return AuthResult.fail(NetworkClient.mapError(e));
    }
  }

  /// 手动跟随 3xx 重定向链。Dio 对 POST 的 302 不会自动跟随，
  /// CAS 登录必须逐跳 GET 才能用票据换取正方会话。最多跟随 8 跳。
  Future<Response<T>> _followRedirects<T>(Response<T> resp) async {
    var cur = resp;
    var code = cur.statusCode ?? 0;
    var guard = 0;
    while (code >= 300 && code < 400 && guard < 8) {
      final loc = cur.headers.value('location');
      if (loc == null) break;
      final next = Uri.parse(loc).isAbsolute
          ? loc
          : cur.realUri.resolve(loc).toString();
      cur = await _net.get<T>(
        next,
        headers: {'Referer': AppConstants.authLoginUrl},
        followRedirects: false,
      );
      code = cur.statusCode ?? 0;
      guard++;
    }
    return cur;
  }

  /// 通过一次课表请求里的 xsxx 获取学生信息（无独立轻量接口）。
  Future<Student> _fetchStudent() async {
    try {
      await _net.get<String>(AppConstants.menuInitUrl);
      final sem = TermUtils.guessCurrentSemester();
      final r = await _net.postForm<Map<String, dynamic>>(
        AppConstants.scheduleUrl,
        {'xnm': sem.xnm, 'xqm': sem.xqm, 'kzlx': 'ck'},
        headers: {'Referer': AppConstants.scheduleReferer},
      );
      final xsxx = (r.data?['xsxx'] as Map?)?.cast<String, dynamic>();
      if (xsxx != null) {
        return Student(
          name: (xsxx['XM'] ?? '') as String,
          id: (xsxx['XH'] ?? '') as String,
          className: (xsxx['BJMC'] ?? '') as String,
          major: (xsxx['ZYMC'] ?? '') as String,
        );
      }
    } catch (_) {
      // 学生信息获取失败不阻断登录
    }
    return Student.empty;
  }

  /// 校验当前会话是否仍有效（用于启动时判断是否需重新登录）。
  Future<bool> isSessionValid() async {
    try {
      await _net.init();
      final sem = TermUtils.guessCurrentSemester();
      final r = await _net.postForm<String>(
        AppConstants.scheduleUrl,
        {'xnm': sem.xnm, 'xqm': sem.xqm, 'kzlx': 'ck'},
        headers: {'Referer': AppConstants.scheduleReferer},
      );
      final body = r.data ?? '';
      // 未登录会被重定向到登录页或返回空
      return body.trim().isNotEmpty &&
          body.trim() != 'null' &&
          !body.contains('authserver') &&
          !r.realUri.toString().contains('authserver');
    } catch (_) {
      return false;
    }
  }
}
