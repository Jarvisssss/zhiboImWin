import '../models/ai_bot.dart';
import '../models/auth_session.dart';
import '../models/friend.dart';
import '../models/im_sign.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../network/auth_header_strategy.dart';

/// 云校园 IM 业务服务的接口路径。
///
/// 路径与现有 App / 小程序保持一致。注意两处历史拼写需原样保留：
/// `getCozeAcessToken`（Acess）与小程序协议的 `/im/im/login/*`（上下文路径 `/im` + 控制器路径 `/im/login`）。
abstract final class ImPaths {
  /// 获取/续期 IM userSig（App 协议）。
  static const String getUserSig = '/im/app/login/getUserSig';

  /// 联系人列表（含角色名）。
  static const String listFriends = '/im/app/login/lstUserFriends';

  /// AI 助教 / 回复助手 Bot 列表。
  static const String listAiBots = '/im/app/login/lstAiTch';

  /// 扣子访问令牌（注意后端既有拼写 Acess）。
  static const String cozeToken = '/im/app/login/getCozeAcessToken';

  /// COS 预签名上传凭证。
  static const String presignedUrl = '/im/app/login/generatePresignedUrl';

  /// fileId 解析为可播放/可下载地址。
  static const String queryByFileId = '/im/app/login/queryByFileId';

  /// PC 版本检查（建议接口，见 docs/backend-requirements.md B7）。
  static const String pcVersion = '/im/app/login/pcVersion';

  /// 小程序协议：发送登录验证码。
  static const String miniGetCaptcha = '/im/im/login/getCaptchaLogin';

  /// 小程序协议：手机号登录（PC 以 clientType=pc 调用，见 B1）。
  static const String miniPhoneLogin = '/im/im/login/phoneAuditLogin';

  /// 小程序协议：退出登录。
  static const String miniLogout = '/im/im/login/logout';
}

/// COS 预签名上传凭证：`uploadUrl` 仅用于本次 PUT，`fileId` 才是可写入消息的长期引用。
class PresignedUpload {
  /// 创建凭证。
  const PresignedUpload({required this.uploadUrl, required this.fileId});

  /// 预签名 PUT 地址。
  final String uploadUrl;

  /// 文件 ID。
  final String fileId;
}

/// 云校园 IM 业务接口（App 协议 `/im/app/login/*`）。
class ImApi {
  /// 创建接口封装。
  ///
  /// [sessionProvider] 返回当前登录会话；登录过程中会话尚未入库时，可显式传入 `session` 参数。
  ImApi({
    required ApiClient client,
    required AuthHeaderStrategy headerStrategy,
    required AuthSession? Function() sessionProvider,
  })  : _client = client,
        _headerStrategy = headerStrategy,
        _sessionProvider = sessionProvider;

  final ApiClient _client;
  final AuthHeaderStrategy _headerStrategy;
  final AuthSession? Function() _sessionProvider;

  Map<String, String> _authHeaders(AuthSession? explicit) {
    final session = explicit ?? _sessionProvider();
    if (session == null) {
      throw const ApiException(kind: ApiErrorKind.authExpired, message: '尚未登录或登录已失效');
    }
    return _headerStrategy.build(session);
  }

  /// 获取 IM 登录凭据（userSig、sdkAppId、imUserId、userRole）。
  ///
  /// 后端对「未分配班级 / 已退学」等账号返回空 `result`，此时抛出 business 异常。
  Future<ImSign> fetchUserSig({AuthSession? session}) async {
    final data = await _client.get(ImPaths.getUserSig, headers: _authHeaders(session));
    final sign = ImSign.tryParse(data);
    if (sign == null) {
      throw const ApiException(
        kind: ApiErrorKind.business,
        message: '该账号暂无 IM 使用权限（可能未分配班级或已退学），请联系管理员',
      );
    }
    return sign;
  }

  /// 联系人列表，按 `sortNo` 升序。
  Future<List<Friend>> listFriends({AuthSession? session}) async {
    final data = await _client.get(
      ImPaths.listFriends,
      query: const {'aiTchFlag': 1},
      headers: _authHeaders(session),
    );
    final friends = _asList(data).map(Friend.tryParse).whereType<Friend>().toList()
      ..sort((a, b) => a.sortNo.compareTo(b.sortNo));
    return friends;
  }

  /// AI Bot 列表（学科助教 + 班主任回复助手）。
  Future<List<AiBot>> listAiBots({AuthSession? session}) async {
    final data = await _client.get(ImPaths.listAiBots, headers: _authHeaders(session));
    return _asList(data).map(AiBot.tryParse).whereType<AiBot>().toList();
  }

  /// 扣子访问令牌（短期有效，由 `CozeTokenManager` 缓存）。
  Future<String> fetchCozeToken({AuthSession? session}) async {
    final data = await _client.get(ImPaths.cozeToken, headers: _authHeaders(session));
    final token = data is String ? data.trim() : '';
    if (token.isEmpty) {
      throw const ApiException(kind: ApiErrorKind.business, message: 'AI 服务暂不可用（未获取到访问令牌）');
    }
    return token;
  }

  /// 获取 COS 预签名上传凭证。
  Future<PresignedUpload> generatePresignedUpload(String fileName, {AuthSession? session}) async {
    final data = await _client.get(
      ImPaths.presignedUrl,
      query: {'fileName': fileName},
      headers: _authHeaders(session),
    );
    if (data is Map) {
      final uploadUrl = '${data['uploadUrl'] ?? ''}';
      final fileId = '${data['fileId'] ?? ''}';
      if (uploadUrl.isNotEmpty && fileId.isNotEmpty) {
        return PresignedUpload(uploadUrl: uploadUrl, fileId: fileId);
      }
    }
    throw const ApiException(kind: ApiErrorKind.business, message: '获取上传凭证失败');
  }

  /// 按 fileId 解析当前可访问地址；解析失败返回 `null`。
  Future<String?> resolveFileUrl(String fileId, {AuthSession? session}) async {
    if (fileId.trim().isEmpty) return null;
    final data = await _client.get(
      ImPaths.queryByFileId,
      query: {'fileId': fileId},
      headers: _authHeaders(session),
    );
    final url = data is Map ? '${data['fileHttpUrl'] ?? data['fileUrl'] ?? data['url'] ?? ''}' : '${data ?? ''}';
    final trimmed = url.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<Object?> _asList(Object? data) => data is List ? data : const <Object?>[];
}
