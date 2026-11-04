/// 构建期注入的配置项（`--dart-define` 或 `--dart-define-from-file=config/env.local.json`）。
///
/// 约束：任何密钥/令牌类配置只允许通过构建期注入，**禁止写入仓库**。
/// 示例文件见 `config/env.example.json`，本地私有文件 `config/env.local.json` 已加入 .gitignore。
abstract final class AppDefines {
  /// 运行环境：`pro`（默认，正式）或 `dev`（测试）。
  static const String env = String.fromEnvironment('ZB_ENV', defaultValue: 'pro');

  /// 登录模式：`pc`（猩子Talk 小程序同源 `/im/im/login/*` + `clientType=pc`）或 `app`（智博在线 App 主 API，仅内部联调）。
  static const String authMode = String.fromEnvironment('ZB_AUTH_MODE', defaultValue: 'pc');

  /// 访问 `/im/app/login/*` 的鉴权头：`accessToken`（小程序 `X-Access-Token`）或 `userToken`（App AES，需 [imTokenKey]）。
  static const String authHeader = String.fromEnvironment('ZB_AUTH_HEADER', defaultValue: 'accessToken');

  /// 生成 `userToken` 使用的 AES 密钥（32 字节）。仅 `ZB_AUTH_HEADER=userToken` 时需要。
  static const String imTokenKey = String.fromEnvironment('ZB_IM_TOKEN_KEY');

  /// 「班主任回复助手」扣子 Bot ID（可选，优先级低于后端 lstAiTch 下发的 scene=reply_assistant）。
  static const String aiReplyBotId = String.fromEnvironment('ZB_AI_REPLY_BOT_ID');

  /// 腾讯云 IM SDKAppID（`ZB_SDK_APP_ID`）。登录/续期时后端未返回 [sdkAppId] 时使用此值。
  static const int sdkAppId = int.fromEnvironment('ZB_SDK_APP_ID', defaultValue: 1400327457);

  /// 解析 IM SDKAppID：优先使用后端返回值（>0），否则使用 [fallbackSdkAppId] 或构建期 [sdkAppId]。
  static int resolveSdkAppId(int fromBackend, {int? fallbackSdkAppId}) {
    if (fromBackend > 0) return fromBackend;
    final fallback = fallbackSdkAppId ?? sdkAppId;
    return fallback > 0 ? fallback : 0;
  }

  /// PC 版本检查接口完整地址（可选），为空时使用 `eipHost + /im/app/login/pcVersion`。
  static const String updateCheckUrl = String.fromEnvironment('ZB_UPDATE_CHECK_URL');
}

/// 登录模式（见 docs/backend-requirements.md B1）。
enum AuthMode {
  /// 猩子Talk 小程序同源：EIP `/im/im/login/getCaptchaLogin`、`phoneAuditLogin`（PC 传 `clientType=pc`）。
  pcLogin,

  /// 智博在线 App 兜底：主 API `/account/auth/*` + AES `userToken`（仅限内部联调，勿用于猩子Talk 正式环境）。
  appAccount;

  /// 从构建期字符串解析；未知值回退到 [pcLogin]。
  static AuthMode parse(String value) {
    switch (value.trim().toLowerCase()) {
      case 'app':
        return appAccount;
      case 'pc':
      default:
        return pcLogin;
    }
  }
}

/// 访问云校园 `/im/app/login/*` 接口的鉴权头策略（见 docs/backend-requirements.md B2）。
enum AuthHeaderMode {
  /// 方案 A：`userToken = AES-GCM(userId)` + `X-Access-Token: 0`。
  userToken,

  /// 方案 B：直接携带登录得到的 `X-Access-Token`。
  accessToken;

  /// 从构建期字符串解析，未知值回退到 [userToken]。
  static AuthHeaderMode parse(String value) =>
      value.trim().toLowerCase() == 'accesstoken' ? accessToken : userToken;
}

/// 运行环境配置（域名等非敏感信息）。
class AppEnv {
  const AppEnv._({
    required this.name,
    required this.apiHost,
    required this.eipHost,
    required this.cozeBaseUrl,
  });

  /// 测试环境。
  static const AppEnv dev = AppEnv._(
    name: 'dev',
    apiHost: 'https://api-dev.zhibojiaoyu.cn/api',
    eipHost: 'https://eipdev.zhibojiaoyu.cn:16941',
    cozeBaseUrl: 'https://api.coze.cn',
  );

  /// 正式环境。
  static const AppEnv pro = AppEnv._(
    name: 'pro',
    apiHost: 'https://api.zhibojiaoyu.cn/api',
    eipHost: 'https://stu.zhibojiaoyu.cn:16941',
    cozeBaseUrl: 'https://api.coze.cn',
  );

  /// 环境名（dev / pro）。
  final String name;

  /// 主业务 API 根地址（`/account/*` 等，App 账号体系）。
  final String apiHost;

  /// 云校园 IM 业务服务根地址（`/im/app/login/*`、`/im/im/login/*`）。
  final String eipHost;

  /// 扣子 OpenAPI 根地址。
  final String cozeBaseUrl;

  /// 当前构建的环境，由 `--dart-define=ZB_ENV` 决定。
  static AppEnv get current => AppDefines.env.trim().toLowerCase() == 'dev' ? dev : pro;
}
