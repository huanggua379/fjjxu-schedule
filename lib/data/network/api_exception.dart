/// 统一的、面向用户的异常类型。绝不把 HTTP/Dart 堆栈直接抛给 UI。
sealed class AppException implements Exception {
  /// 给普通用户看的友好信息
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException([super.message = '网络连接失败，请检查网络后重试']);
}

class TimeoutException extends AppException {
  const TimeoutException([super.message = '请求超时，请稍后重试']);
}

class ServerException extends AppException {
  const ServerException([super.message = '教务系统繁忙或维护中，请稍后重试']);
}

class AuthException extends AppException {
  const AuthException([super.message = '登录状态已失效，请重新登录']);
}

class CredentialException extends AppException {
  const CredentialException([super.message = '学号或密码错误']);
}

class CaptchaRequiredException extends AppException {
  const CaptchaRequiredException(
      [super.message = '教务系统要求验证码，请暂时改用网页登录或稍后再试']);
}

class ParseException extends AppException {
  const ParseException([super.message = '数据解析失败，请稍后重试']);
}

class UnknownException extends AppException {
  const UnknownException([super.message = '出错了，请稍后重试']);
}
