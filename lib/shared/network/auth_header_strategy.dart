import '../models/auth_session.dart';
import '../security/aes_util.dart';

/// 访问云校园 `/im/app/login/*` 接口时的鉴权头策略（见 docs/backend-requirements.md B2）。
abstract interface class AuthHeaderStrategy {
  /// 根据当前会话构建请求头。
  Map<String, String> build(AuthSession session);
}

/// 方案 A：`userToken = AES-GCM(userId)` + `X-Access-Token: 0`，与 App 完全一致。
class UserTokenHeaderStrategy implements AuthHeaderStrategy {
  /// [secretKey] 为构建期注入的 32 字节 AES 密钥（`ZB_IM_TOKEN_KEY`）。
  UserTokenHeaderStrategy({required this.secretKey});

  /// AES 密钥。
  final String secretKey;

  @override
  Map<String, String> build(AuthSession session) {
    if (!AesUtil.isValidKey(secretKey)) {
      throw StateError('未配置有效的 ZB_IM_TOKEN_KEY（需 32 字节），请参考 README「配置与密钥」');
    }
    return {
      'userToken': AesUtil.encryptUserId(session.userId, secretKey),
      'X-Access-Token': '0',
    };
  }
}

/// 方案 B：直接使用登录得到的业务 token（需后端放开 `/im/app/login/*` 对 token 的支持）。
class AccessTokenHeaderStrategy implements AuthHeaderStrategy {
  /// 创建策略。
  const AccessTokenHeaderStrategy();

  @override
  Map<String, String> build(AuthSession session) => {'X-Access-Token': session.token};
}
