import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';

/// 敏感凭证安全存储（学号/密码）。使用平台安全存储：
/// Android Keystore 加密。绝不写入普通日志或明文文件。
class SecureStore {
  SecureStore._();
  static final SecureStore instance = SecureStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveCredentials(String username, String password) async {
    await _storage.write(key: AppConstants.ksUsername, value: username);
    await _storage.write(key: AppConstants.ksPassword, value: password);
  }

  Future<String?> getUsername() => _storage.read(key: AppConstants.ksUsername);
  Future<String?> getPassword() => _storage.read(key: AppConstants.ksPassword);

  Future<(String, String)?> getCredentials() async {
    final u = await getUsername();
    final p = await getPassword();
    if (u == null || p == null || u.isEmpty || p.isEmpty) return null;
    return (u, p);
  }

  Future<void> clear() async {
    await _storage.delete(key: AppConstants.ksUsername);
    await _storage.delete(key: AppConstants.ksPassword);
  }
}
