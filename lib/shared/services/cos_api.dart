import '../models/auth_session.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// 猩子Talk 小程序同源 COS 接口（`BASE_URL` = `{eipHost}/im`）。
abstract final class CosPaths {
  /// 大文件 / 大视频本体上传（返回 fileId）。
  static const String upload = '/im/sys/cos/upload';

  /// 按 fileId 解析当前可访问地址。
  static const String queryByFileId = '/im/sys/cos/queryByFileId';
}

/// 与小程序 [utils/upload/cos-upload.js]、[cos-url-resolver.js] 对齐的 COS 能力。
class CosApi {
  /// 创建接口封装。
  CosApi({
    required ApiClient client,
    required AuthSession? Function() sessionProvider,
  })  : _client = client,
        _sessionProvider = sessionProvider;

  final ApiClient _client;
  final AuthSession? Function() _sessionProvider;

  /// 与小程序 `getUserBizPath()` 一致：`xingzi-talk-msg/{imUserId}`。
  static String chatBizPath(AuthSession session) => 'xingzi-talk-msg/${session.imUserId}';

  Map<String, String> _tokenHeaders(AuthSession? explicit) {
    final session = explicit ?? _sessionProvider();
    if (session == null || session.token.isEmpty) {
      throw const ApiException(kind: ApiErrorKind.authExpired, message: '尚未登录或登录已失效');
    }
    return {'X-Access-Token': session.token};
  }

  /// 上传大文件本体，返回 fileId（消息中仅存 fileId，播放时再解析 URL）。
  Future<String> uploadLargeFile(
    String filePath, {
    required String fileName,
    AuthSession? session,
    void Function(int sent, int total)? onProgress,
  }) async {
    final authSession = session ?? _sessionProvider();
    if (authSession == null) {
      throw const ApiException(kind: ApiErrorKind.authExpired, message: '尚未登录或登录已失效');
    }
    final envelope = await _client.uploadMultipart(
      CosPaths.upload,
      filePath: filePath,
      fileFieldName: 'file',
      fields: {
        'biz': chatBizPath(authSession),
        'fileName': fileName,
      },
      headers: _tokenHeaders(authSession),
      onProgress: onProgress,
    );
    final fileId = _extractFileId(envelope.result, envelope.message);
    if (fileId == null) {
      throw const ApiException(kind: ApiErrorKind.business, message: 'COS 上传未返回有效 fileId');
    }
    return fileId;
  }

  /// 解析 fileId 为当前 CDN / 业务访问地址。
  Future<String?> resolveFileHttpUrl(String fileId, {AuthSession? session}) async {
    if (fileId.trim().isEmpty) return null;
    final data = await _client.get(
      CosPaths.queryByFileId,
      query: {'fileId': fileId},
      headers: _tokenHeaders(session),
    );
    if (data is Map) {
      final url = '${data['fileHttpUrl'] ?? data['fileUrl'] ?? data['url'] ?? ''}'.trim();
      if (url.isNotEmpty) return url;
    }
    return null;
  }

  /// 从 `/sys/cos/upload` 响应中提取 fileId（与小程序 `extractFileIdFromResponse` 一致）。
  static String? _extractFileId(Object? result, String message) {
    if (result is Map) {
      for (final key in ['path', 'fileId']) {
        final value = '${result[key] ?? ''}'.trim();
        if (_isNumericFileId(value)) return value;
      }
    }
    final fromMessage = message.trim();
    if (_isNumericFileId(fromMessage)) return fromMessage;
    return null;
  }

  static bool _isNumericFileId(String value) => RegExp(r'^\d+$').hasMatch(value);
}
