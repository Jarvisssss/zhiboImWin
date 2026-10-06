import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../config/app_env.dart';
import '../../utils/app_logger.dart';
import 'coze_token_manager.dart';

/// SSE 事件数据。
class SseEvent {
  /// 创建 SSE 事件。
  const SseEvent({required this.event, this.data, this.isDone = false});

  /// 事件名（如 `conversation.message.delta`）。
  final String event;

  /// 解析后的 JSON 数据。
  final Map<String, dynamic>? data;

  /// 是否为流结束标记。
  final bool isDone;
}

/// 扣子 SSE 流式客户端（`dart:io` HttpClient，Dio 不直接支持 event-stream）。
class CozeSSEClient {
  /// 创建客户端。
  CozeSSEClient({this.sseTimeout = const Duration(seconds: 120)});

  /// SSE 连接超时。
  final Duration sseTimeout;

  final AppLogger _log = AppLogger('CozeSSEClient');

  HttpClient? _httpClient;
  StreamSubscription<String>? _subscription;
  bool _isCancelled = false;

  /// 发起流式对话。
  Future<void> connect({
    required String botId,
    required String userId,
    String? conversationId,
    required List<Map<String, dynamic>> messages,
    required void Function(SseEvent event) onEvent,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) async {
    _isCancelled = false;
    _httpClient = HttpClient()..connectionTimeout = sseTimeout;

    final base = AppEnv.current.cozeBaseUrl;
    final uri = conversationId != null
        ? Uri.parse('$base/v3/chat').replace(queryParameters: {'conversation_id': conversationId})
        : Uri.parse('$base/v3/chat');

    try {
      final token = await CozeTokenManager.instance.getToken();
      final request = await _httpClient!.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Accept', 'text/event-stream');

      final body = jsonEncode({
        'stream': true,
        'additional_messages': messages,
        'user_id': userId,
        'bot_id': botId,
      });
      final bodyBytes = utf8.encode(body);
      request.contentLength = bodyBytes.length;
      request.add(bodyBytes);

      final response = await request.close();
      if (response.statusCode == 401) {
        CozeTokenManager.instance.invalidate();
        onError(Exception('Token 已过期'));
        return;
      }
      if (response.statusCode != 200) {
        onError(Exception('HTTP ${response.statusCode}'));
        return;
      }

      var currentEvent = '';
      var currentData = '';

      _subscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (_isCancelled) return;
              if (line.startsWith('event:')) {
                currentEvent = line.substring(6).trim();
              } else if (line.startsWith('data:')) {
                currentData = line.substring(5).trim();
              } else if (line.isEmpty && currentEvent.isNotEmpty) {
                final isDone = currentData == '[DONE]' || currentData == '"[DONE]"';
                if (isDone) {
                  onEvent(const SseEvent(event: 'done', isDone: true));
                } else {
                  try {
                    final data = jsonDecode(currentData) as Map<String, dynamic>;
                    onEvent(SseEvent(event: currentEvent, data: data));
                  } catch (error) {
                    _log.debug('SSE JSON 解析失败 event=$currentEvent');
                  }
                }
                currentEvent = '';
                currentData = '';
              }
            },
            onError: (error) {
              if (!_isCancelled) onError(error);
            },
            onDone: () {
              if (!_isCancelled) onDone();
            },
            cancelOnError: false,
          );
    } catch (error, stack) {
      _log.error('SSE 连接异常', error, stack);
      onError(error);
    }
  }

  /// 取消连接。
  void cancel() {
    _isCancelled = true;
    _subscription?.cancel();
    _subscription = null;
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  /// 是否仍在连接中。
  bool get isConnected => _subscription != null && !_isCancelled;
}
