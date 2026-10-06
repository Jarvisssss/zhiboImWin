/// 接口异常类别。
enum ApiErrorKind {
  /// 网络层错误：超时、断网、证书、DNS 等。
  network,

  /// HTTP 层错误：非 JSON 响应、网关错误等。
  http,

  /// 业务错误：服务端返回 success=false / code 非成功。
  business,

  /// 登录态失效：需要重新登录。
  authExpired,

  /// 响应结构不符合约定。
  parse,
}

/// 统一的接口异常，`message` 面向用户可直接展示，不包含任何 token/密钥。
class ApiException implements Exception {
  /// 创建异常。
  const ApiException({
    required this.kind,
    required this.message,
    this.code,
    this.httpStatus,
    this.failCode,
  });

  /// 异常类别。
  final ApiErrorKind kind;

  /// 可展示的错误描述。
  final String message;

  /// 业务码（信封中的 code）。
  final int? code;

  /// HTTP 状态码。
  final int? httpStatus;

  /// 登录接口返回的 `result.failCode`（0 登录失败 / 1 用户不存在或验证码错误 / 2 微信 ID 获取失败 / 3 角色不允许）。
  final int? failCode;

  /// 是否需要重新登录。
  bool get isAuthExpired => kind == ApiErrorKind.authExpired;

  /// 是否网络问题（可提示用户检查网络后重试）。
  bool get isNetwork => kind == ApiErrorKind.network;

  @override
  String toString() => 'ApiException(kind=$kind, code=$code, http=$httpStatus, failCode=$failCode, message=$message)';
}
