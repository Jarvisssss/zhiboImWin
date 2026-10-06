/// 构建期注入的配置项（`--dart-define` 或 `--dart-define-from-file=config/env.local.json`）。
///
/// 约束：任何密钥/令牌类配置只允许通过构建期注入，**禁止写入仓库**。
/// 示例文件见 `config/env.example.json`，本地私有文件 `config/env.local.json` 已加入 .gitignore。
abstract final class AppDefines {
  /// 运行环境：`pro`（默认，正式）或 `dev`（测试）。
  static const String env = String.fromEnvironment('ZB_ENV', defaultValue: 'pro');

  /// 登录模式：`app`（兜底，复用 App 主 API 验证码登录）或 `pc`（PC 专用登录接口，后端就绪后启用）。
  static const String authMode = String.fromEnvironment('ZB_AUTH_MODE', defaultValue: 'app');

  /// 访问 `/im/app/login/*` 的鉴权头策略：`userToken`（方案 A，AES）或 `accessToken`（方案 B）。
  static const String authHeader = String.fromEnvironment('ZB_AUTH_HEADER', defaultValue: 'userToken');

  /// 生成 `userToken` 使用的 AES 密钥（32 字节字符串）。方案 B 下无需配置。
  static const String imTokenKey = String.fromEnvironment('ZB_IM_TOKEN_KEY');

  /// 「班主任回复助手」扣子 Bot ID（可选，优先级低于后端 lstAiTch 下发的 scene=reply_assistant）。
  static const String aiReplyBotId = String.fromEnvironment('ZB_AI_REPLY_BOT_ID');

  /// IM SDKAppID，仅在登录前需要预初始化 SDK（如冒烟测试）时使用；登录后以后端返回值为准。
  static const int sdkAppId = int.fromEnvironment('ZB_SDK_APP_ID');

  /// PC 版本检查接口完整地址（可选），为空时使用 `eipHost + /im/app/login/pcVersion`。
  static const String updateCheckUrl = String.fromEnvironment('ZB_UPDATE_CHECK_URL');
}

/// 登录模式（见 docs/backend-requirements.md B1）。
enum AuthMode {
  /// 兜底：App 主 API 验证码登录 + `/im/app/login/getUserSig`（仅限内部联调）。
  appAccount,

  /// 目标：PC 专用登录接口 `/im/im/login/phoneAuditLogin`（`clientType=pc`）。
  pcLogin;

  /// 从构建期字符串解析，未知值回退到 [appAccount]。
  static AuthMode parse(String value) => value.trim().toLowerCase() == 'pc' ? pcLogin : appAccount;
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
