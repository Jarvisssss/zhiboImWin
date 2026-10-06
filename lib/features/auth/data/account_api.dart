import '../../../shared/network/api_client.dart';
import '../../../shared/network/api_exception.dart';

/// 主业务账号信息（`/account/auth/verifyCodeLogin` 的 `data`）。
class AccountUser {
  /// 创建账号信息。
  const AccountUser({
    required this.id,
    required this.token,
    this.name = '',
    this.avatarUrl = '',
    this.isTeacher = false,
  });

  /// 主业务用户 ID（方案 A 下用于生成 `userToken`）。
  final String id;

  /// 主业务 token。
  final String token;

  /// 昵称。
  final String name;

  /// 头像。
  final String avatarUrl;

  /// 主业务标记的教师身份（与 IM `userRole` 不同源，仅作参考）。
  final bool isTeacher;

  /// 从 JSON 解析；缺少 id/token 或 id 为占位值 `0` 时返回 `null`。
  static AccountUser? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = '${json['id'] ?? ''}';
    final token = '${json['token'] ?? ''}';
    if (id.isEmpty || id == '0' || token.isEmpty) return null;
    return AccountUser(
      id: id,
      token: token,
      name: '${json['name'] ?? ''}',
      avatarUrl: '${json['avatarUrl'] ?? ''}',
      isTeacher: json['isTeacher'] == true,
    );
  }
}

/// 主业务账号接口（兜底登录链路）。
///
/// ⚠️ `verifyCodeLogin` 是「登录/注册统一接口」，未注册手机号会被自动创建账号，
/// 因此该链路仅限内部联调，上线前须切换到 PC 专用登录接口（见 docs/backend-requirements.md 1.3）。
class AccountApi {
  /// [client] 必须是 [EnvelopeStyle.main] 风格、baseUrl 为主业务 API 的客户端。
  AccountApi({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// 发送登录验证码。
  Future<void> sendCode(String phone) async {
    await _client.post('/account/auth/sendCode', body: {'phone': phone});
  }

  /// 验证码登录，返回主业务账号信息。
  Future<AccountUser> verifyCodeLogin(String phone, String verifyCode) async {
    final data = await _client.post(
      '/account/auth/verifyCodeLogin',
      body: {'phone': phone, 'verifyCode': verifyCode},
    );
    final user = AccountUser.tryParse(data);
    if (user == null) {
      throw const ApiException(kind: ApiErrorKind.parse, message: '登录返回数据异常，请稍后重试');
    }
    return user;
  }
}
