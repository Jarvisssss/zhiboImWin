/// 腾讯云 IM 错误码分类。
///
/// 依据官方《错误码》与《登录》文档：登录回调返回 `6206`（ERR_USER_SIG_EXPIRED）或
/// `70001`（ERR_SVR_ACCOUNT_USERSIG_EXPIRED）时应使用**新签发**的 userSig 重新登录；
/// 其它错误码**不要**在回调里再次调用 login，避免 SDK 登录进入死循环。
abstract final class ImErrorCodes {
  /// userSig 过期（客户端本地判定）。
  static const int userSigExpired = 6206;

  /// userSig 已过期（服务端判定）。
  static const int svrUserSigExpired = 70001;

  /// userSig 已失效，需重新生成（ERR_SVR_ACCOUNT_INVALID_USERSIG）。
  static const int svrInvalidUserSig = 70052;

  /// 自动登录时本地票据过期，需要用 userSig 手动登录。
  static const int autoLoginTicketExpired = 6226;

  /// 其他终端登录同一账号导致被踢（ERR_LOGIN_KICKED_OFF_BY_OTHER）。
  static const int kickedOffByOther = 6208;

  /// SDK 未登录或已被踢下线。
  static const int notLoggedIn = 6014;

  /// 请求时无网络 / 响应时无网络。
  static const Set<int> networkUnavailable = {6200, 6201};

  /// 账号被拉入黑名单。
  static const int accountBlocked = 70051;

  /// 可通过「重新签发 userSig 后再登录」恢复的错误码集合。
  ///
  /// 注意：与方案文档不同，这里**不含 70014**——它表示 SDKAppID 与签发时不一致，属于配置错误，续期无法解决。
  static const Set<int> renewable = {
    userSigExpired,
    svrUserSigExpired,
    svrInvalidUserSig,
    autoLoginTicketExpired,
  };

  /// 属于应用配置/签发错误的错误码（SDKAppID、密钥、UserID 不匹配等），需要管理员处理。
  static const Set<int> configuration = {70009, 70013, 70014, 70016, 70020};

  /// 是否可通过续期 userSig 恢复。
  static bool isUserSigExpired(int code) => renewable.contains(code);

  /// 是否为配置错误。
  static bool isConfigurationError(int code) => configuration.contains(code);

  /// 把错误码转换为面向用户的提示（不含原始 desc，避免泄露内部信息）。
  static String describe(int code) {
    if (networkUnavailable.contains(code)) return '网络不可用，请检查网络后重试';
    if (isConfigurationError(code)) return '应用配置异常（$code），请联系管理员';
    if (code == accountBlocked) return '账号已被限制登录，请联系管理员';
    if (code == kickedOffByOther) return '账号已在其他设备登录';
    if (isUserSigExpired(code)) return '登录凭证已过期，请重新登录';
    return '连接聊天服务失败（$code）';
  }
}
