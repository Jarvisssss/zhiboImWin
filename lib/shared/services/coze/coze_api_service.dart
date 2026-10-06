import 'package:dio/dio.dart';

import '../../../config/app_env.dart';
import '../../utils/app_logger.dart';
import 'coze_token_manager.dart';

/// 扣子 REST API 业务异常。
class CozeApiException implements Exception {
  /// 创建异常。
  const CozeApiException(this.code, this.message);

  /// 扣子业务码。
  final int code;

  /// 错误描述。
  final String message;

  @override
  String toString() => 'CozeApiException($code): $message';
}

/// 扣子 REST API 封装（独立 Dio，不走云校园 [ApiClient]）。
class CozeApiService {
  /// 创建服务。
  CozeApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppEnv.current.cozeBaseUrl,
                connectTimeout: const Duration(seconds: 60),
                receiveTimeout: const Duration(seconds: 60),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  final Dio _dio;
  final AppLogger _log = AppLogger('CozeApiService');

  /// 401 自动刷新 Token 后重试（仅重试 1 次）。
  Future<T> _withTokenRefresh<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        CozeTokenManager.instance.invalidate();
        return await request();
      }
      rethrow;
    }
  }

  Future<Options> _authOptions() async {
    final token = await CozeTokenManager.instance.getToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  dynamic _handleResponse(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map) {
      throw CozeApiException(-1, '响应格式异常');
    }
    final code = body['code'] as int? ?? -1;
    if (code != 0) {
      final msg = body['msg'] as String? ?? 'Unknown error';
      _log.warn('Coze API 业务错误 code=$code');
      throw CozeApiException(code, msg);
    }
    return body['data'];
  }

  /// 取消进行中的对话。
  Future<void> cancelChat({required String chatId, required String conversationId}) async {
    return _withTokenRefresh(() async {
      final options = await _authOptions();
      final response = await _dio.post(
        '/v3/chat/cancel',
        data: {'chat_id': chatId, 'conversation_id': conversationId},
        options: options,
      );
      _handleResponse(response);
    });
  }
}
