import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

/// 金智(wisedu)统一身份认证密码加密的 Dart 复刻。
///
/// 等价于登录页 encrypt.js：
///   encryptAES(data, key) = _gas( _rds(64) + data, key, _rds(16) )
///   _gas: AES / CBC / PKCS7，key=pwdDefaultEncryptSalt(trim,utf8)，
///         iv=16位随机 ASCII 串，输出 Base64。
/// 服务端解密后丢弃前 64 位随机前缀得到真实密码。
class WiseduCrypto {
  WiseduCrypto._();

  static const _chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final _rng = Random.secure();

  /// 生成 n 位随机 ASCII 串（等价 _rds）。
  static String randomString(int n) {
    final sb = StringBuffer();
    for (var i = 0; i < n; i++) {
      sb.write(_chars[_rng.nextInt(_chars.length)]);
    }
    return sb.toString();
  }

  /// 加密登录密码，返回 Base64 密文。
  static String encryptPassword(String password, String salt) {
    final keyStr = salt.trim();
    final keyBytes = Uint8List.fromList(utf8.encode(keyStr));
    if (![16, 24, 32].contains(keyBytes.length)) {
      throw ArgumentError('加密盐长度异常(${keyBytes.length})，登录页结构可能已变化');
    }
    final ivStr = randomString(16);
    final ivBytes = Uint8List.fromList(utf8.encode(ivStr));

    // 明文 = 64 位随机串 + 密码
    final plain = randomString(64) + password;

    final key = Key(keyBytes);
    final iv = IV(ivBytes);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
    final encrypted = encrypter.encrypt(plain, iv: iv);
    return encrypted.base64;
  }
}
