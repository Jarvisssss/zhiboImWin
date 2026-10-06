import 'dart:async';

import 'package:dio/dio.dart';

import '../utils/app_logger.dart';
import 'api_envelope.dart';
import 'api_exception.dart';

/// 请求头提供者：每次请求前调用，保证 token 变化后立即生效。
typedef HeadersProvider = FutureOr<Map<String, String>> Function();

/// 面向业务后端的 HTTP 客户端：统一超时、信封解析、异常映射与脱敏日志。
///
/// 一个实例对应一个后端根地址与一种信封风格（见 [EnvelopeStyle]）。
class ApiClient {
  /// 创建客户端。[dio] 仅用于测试注入自定义 `HttpClientAdapter`。
  ApiClient({
    required String baseUrl,
    required this.style,
    this.headersProvider,
    String userAgent = 'ZhiboTalkDesktop',
    Dio? dio,
    String name = 'ApiClient',
  })  : _log = AppLogger(name),
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..sendTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 30)
      // 统一按纯文本接收后自行解码：部分网关会把 JSON 标成 text/plain。
      ..responseType = ResponseType.plain
      // 所有 HTTP 状态码都进入信封解析，由 ApiException 统一表达错误。
      ..validateStatus = ((_) => true)
      ..headers = {
        'Accept': 'application/json',
        'User-Agent': userAgent,
      };
  }

  /// 信封风格。
  final EnvelopeStyle style;

  /// 额外请求头提供者（如鉴权头）。
  final HeadersProvider? headersProvider;

  final Dio _dio;
  final AppLogger _log;

  /// GET 请求，返回信封中的业务数据。
  Future<Object?> get(
    String path, {
    Map<String, Object?>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) {
    return _send('GET', path, query: query, headers: headers, cancelToken: cancelToken);
  }

  /// POST(JSON) 请求，返回信封中的业务数据。
  Future<Object?> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) {
    return _send('POST', path, body: body, headers: headers, cancelToken: cancelToken);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    final merged = <String, String>{
      if (method != 'GET') 'Content-Type': 'application/json;charset=UTF-8',
      ...?await headersProvider?.call(),
      ...?headers,
    };
    final stopwatch = Stopwatch()..start();
    Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(method: method, headers: merged),
      );
    } on DioException catch (error) {
      _log.warn('$method $path 失败 type=${error.type.name} elapsed=${stopwatch.elapsedMilliseconds}ms');
      throw _mapDioError(error);
    }

    final httpStatus = response.statusCode;
    _log.debug('$method $path -> HTTP $httpStatus ${stopwatch.elapsedMilliseconds}ms');
    final envelope = ApiEnvelope.parse(response.data, style, httpStatus: httpStatus);
    if (envelope.success) return envelope.data;

    final authExpired = envelope.isAuthExpired(style, httpStatus);
    throw ApiException(
      kind: authExpired ? ApiErrorKind.authExpired : ApiErrorKind.business,
      message: authExpired ? '登录状态已失效，请重新登录' : (envelope.message.isEmpty ? '请求失败（HTTP ${httpStatus ?? '-'}）' : envelope.message),
      code: envelope.code,
      httpStatus: httpStatus,
      failCode: envelope.failCode,
    );
  }

  ApiException _mapDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(kind: ApiErrorKind.network, message: '网络超时，请检查网络后重试');
      case DioExceptionType.cancel:
        return const ApiException(kind: ApiErrorKind.network, message: '请求已取消');
      case DioExceptionType.badCertificate:
        return const ApiException(kind: ApiErrorKind.network, message: '证书校验失败，请检查系统时间与网络代理');
      case DioExceptionType.connectionError:
        return const ApiException(kind: ApiErrorKind.network, message: '无法连接服务器，请检查网络');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return ApiException(kind: ApiErrorKind.network, message: '网络异常，请稍后重试', httpStatus: error.response?.statusCode);
    }
  }
}
