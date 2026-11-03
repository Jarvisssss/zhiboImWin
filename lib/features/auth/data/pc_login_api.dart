import '../../../shared/models/user_role.dart';
import '../../../shared/network/api_client.dart';
import '../../../shared/network/api_exception.dart';
import '../../../shared/services/im_api.dart';

/// PC 专用登录接口的响应（见 docs/backend-requirements.md B1）。
class PcLoginResult {
  /// 创建登录结果。
  const PcLoginResult({
    required this.token,
    required this.userId,
    required this.imUserId,
    required this.imUserSig,
    required this.sdkAppId,
    required this.role,
    this.nick = '',
    this.avatar = '',
  });

  /// 业务 token。
  final String token;

  /// 主业务用户 ID。
  final String userId;

  /// IM 账号 ID。
  final String imUserId;

  /// 后端签发的 userSig。
  final String imUserSig;

  /// IM 应用 ID（后端未返回时为 0，由调用方回退到构建期配置）。
  final int sdkAppId;

  /// 业务角色。
  final UserRole role;

  /// 昵称。
  final String nick;

  /// 头像。
  final String avatar;

  /// 解析响应 `result`，缺少关键字段时返回 `null`。
  static PcLoginResult? tryParse(Object? json) {
    if (json is! Map) return null;
    final info = json['userInfo'];
    if (info is! Map) return null;
    final token = '${json['token'] ?? ''}';
    final imUserId = '${info['imUserId'] ?? ''}';
    final imUserSig = '${info['imUserSig'] ?? ''}';
    if (token.isEmpty || imUserId.isEmpty || imUserSig.isEmpty) return null;
    final sdkAppIdRaw = info['sdkAppId'];
    return PcLoginResult(
      token: token,
      // 后端未返回主业务 ID 时退化为 imUserId，仅方案 B（token 鉴权）可用。
      userId: '${info['id'] ?? imUserId}',
      imUserId: imUserId,
      imUserSig: imUserSig,
      sdkAppId: sdkAppIdRaw is num ? sdkAppIdRaw.toInt() : int.tryParse('${sdkAppIdRaw ?? ''}') ?? 0,
      role: UserRole.fromRaw(info['userRole']),
      nick: _readNick(info),
      avatar: '${info['avatar'] ?? ''}',
    );
  }

  /// 与小程序 `userInfo` 字段对齐（`nick` 或 `personInfo`）。
  static String _readNick(Map<dynamic, dynamic> info) {
    final nick = '${info['nick'] ?? ''}';
    if (nick.isNotEmpty) return nick;
    final person = info['personInfo'];
    if (person is Map) {
      final fromPerson = '${person['name'] ?? person['nick'] ?? ''}';
      if (fromPerson.isNotEmpty) return fromPerson;
    }
    if (person is String && person.isNotEmpty) return person;
    return '';
  }
}

/// PC 专用登录接口（目标方案）。`client` 为 [EnvelopeStyle.eip] 风格。
class PcLoginApi {
  /// 创建接口封装。
  PcLoginApi({required ApiClient client}) : _client = client;

  /// 请求体 `clientType`；dev 环境对 `code` 非空校验，PC 暂用同值占位（见 docs/backend-requirements.md B1）。
  static const String clientTypePc = 'pc';

  final ApiClient _client;

  /// 发送登录验证码（沿用小程序接口 `getCaptchaLogin`）。
  Future<void> sendCaptcha(String phone) async {
    await _client.post(ImPaths.miniGetCaptcha, body: {'cel': phone});
  }

  /// 手机号 + 验证码登录（小程序同源 `phoneAuditLogin`，PC 传 [clientTypePc]）。
  Future<PcLoginResult> login({
    required String phone,
    required String captcha,
    required String deviceId,
    required String deviceName,
  }) async {
    final data = await _client.post(
      ImPaths.miniPhoneLogin,
      body: {
        'username': phone,
        'captcha': captcha,
        'code': clientTypePc,
        'clientType': clientTypePc,
        'deviceId': deviceId,
        'deviceName': deviceName,
      },
    );
    final result = PcLoginResult.tryParse(data);
    if (result == null) {
      throw const ApiException(kind: ApiErrorKind.parse, message: '登录返回数据异常，请稍后重试');
    }
    return result;
  }

  /// 退出登录（best effort，失败不影响本地退出）。
  Future<void> logout(String token) async {
    await _client.get(ImPaths.miniLogout, headers: {'X-Access-Token': token});
  }
}
