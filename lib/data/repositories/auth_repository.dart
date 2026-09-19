import '../../domain/entities/entities.dart';
import '../local/secure_store.dart';
import '../local/settings_store.dart';
import '../network/api_exception.dart';
import '../network/network_client.dart';
import '../remote/auth_remote.dart';

/// 认证仓库：整合远程登录、凭证安全存储、会话恢复与退出。
class AuthRepository {
  AuthRepository({
    required AuthRemote remote,
    required SecureStore secure,
    required SettingsStore settings,
    required NetworkClient net,
  })  : _remote = remote,
        _secure = secure,
        _settings = settings,
        _net = net;

  final AuthRemote _remote;
  final SecureStore _secure;
  final SettingsStore _settings;
  final NetworkClient _net;

  Student? _cachedStudent;
  Student? get student => _cachedStudent;

  /// 用户主动登录。成功后保存凭证以支持会话失效时静默重登。
  Future<AuthResult> login(String username, String password) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return const AuthResult.fail(CredentialException('请输入学号和密码'));
    }
    final result = await _remote.login(username.trim(), password);
    if (result.success) {
      await _secure.saveCredentials(username.trim(), password);
      await _settings.setLoggedIn(true);
      _cachedStudent = result.student;
    }
    return result;
  }

  /// 启动时恢复登录态：本地标记已登录 + 远端会话仍有效。
  Future<bool> restoreSession() async {
    final loggedIn = await _settings.isLoggedIn();
    if (!loggedIn) return false;
    final valid = await _remote.isSessionValid();
    if (valid) {
      return true;
    }
    // 会话失效，尝试用保存的凭证静默重登
    return await silentRelogin();
  }

  /// 用已保存凭证静默重新登录（会话过期时调用）。
  Future<bool> silentRelogin() async {
    final cred = await _secure.getCredentials();
    if (cred == null) return false;
    final result = await _remote.login(cred.$1, cred.$2);
    if (result.success) {
      _cachedStudent = result.student;
      await _settings.setLoggedIn(true);
      return true;
    }
    return false;
  }

  Future<bool> isLoggedIn() => _settings.isLoggedIn();

  /// 退出登录：清除 cookie、凭证与登录标记（本地缓存数据保留，可离线查看）。
  Future<void> logout({bool clearLocalData = false}) async {
    await _net.clearCookies();
    await _secure.clear();
    await _settings.setLoggedIn(false);
    _cachedStudent = null;
  }
}
