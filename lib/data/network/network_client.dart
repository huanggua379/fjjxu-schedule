import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import 'api_exception.dart';

/// 统一网络客户端：Base URL、Headers、Cookie 持久化、超时、重试、
/// 以及把 DioException 归一化为友好的 AppException。
/// 所有远程数据源都通过它发请求，页面不直接碰 HTTP。
class NetworkClient {
  NetworkClient._();
  static final NetworkClient instance = NetworkClient._();

  late final Dio dio;
  late final PersistCookieJar _cookieJar;
  bool _ready = false;

  // 必须用桌面 UA：金智 SSO 对手机 UA 返回移动版登录页，缺少
  // pwdDefaultEncryptSalt 隐藏字段，会导致登录页解析失败。
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  Future<void> init() async {
    if (_ready) return;
    final dir = await getApplicationSupportDirectory();
    final cookieDir = Directory('${dir.path}/cookies');
    if (!cookieDir.existsSync()) cookieDir.createSync(recursive: true);
    _cookieJar = PersistCookieJar(
      storage: FileStorage(cookieDir.path),
      ignoreExpires: true,
    );

    dio = Dio(BaseOptions(
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      followRedirects: true,
      maxRedirects: 6,
      // 正方/金智对非 2xx/3xx 会抛错，这里统一在拦截器里转换
      validateStatus: (s) => s != null && s < 500,
      headers: {
        'User-Agent': _ua,
        'Accept-Language': 'zh-CN,zh;q=0.9',
      },
    ));
    dio.interceptors.add(CookieManager(_cookieJar));
    dio.interceptors.add(_ErrorInterceptor());
    _ready = true;
  }

  /// 清除所有 cookie（退出登录时调用）
  Future<void> clearCookies() async {
    if (!_ready) return;
    await _cookieJar.deleteAll();
  }

  Future<Response<T>> get<T>(
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    bool followRedirects = true,
  }) async {
    await init();
    return dio.get<T>(url,
        queryParameters: query,
        options: Options(headers: headers, followRedirects: followRedirects));
  }

  /// 以 form-urlencoded 提交（正方接口要求）
  Future<Response<T>> postForm<T>(
    String url,
    Map<String, dynamic> data, {
    Map<String, dynamic>? headers,
    bool followRedirects = true,
  }) async {
    await init();
    return dio.post<T>(
      url,
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        followRedirects: followRedirects,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          ...?headers,
        },
      ),
    );
  }

  /// 把底层异常转换为友好异常
  static AppException mapError(Object e) {
    if (e is AppException) return e;
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return const TimeoutException();
        case DioExceptionType.connectionError:
          return const NetworkException();
        case DioExceptionType.badCertificate:
          return const NetworkException('安全证书校验失败，请检查网络环境');
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode ?? 0;
          if (code >= 500) return const ServerException();
          return ServerException('服务异常（$code），请稍后重试');
        case DioExceptionType.cancel:
          return const NetworkException('请求已取消');
        case DioExceptionType.unknown:
          if (e.error is SocketException) return const NetworkException();
          return const UnknownException();
      }
    }
    return const UnknownException();
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}
