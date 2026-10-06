import 'dart:ui' show VoidCallback;

/// IM SDK 调用结果（与具体 SDK 的返回类型解耦）。
class ImCallResult {
  /// 创建结果。
  const ImCallResult(this.code, [this.desc = '']);

  /// 成功结果。
  static const ImCallResult success = ImCallResult(0);

  /// 错误码，0 表示成功。
  final int code;

  /// SDK 返回的描述（仅用于日志，不直接展示给用户）。
  final String desc;

  /// 是否成功。
  bool get ok => code == 0;
}

/// 网络/账号状态回调集合。
class ImGatewayListener {
  /// 创建回调集合。
  const ImGatewayListener({
    this.onConnecting,
    this.onConnectSuccess,
    this.onConnectFailed,
    this.onKickedOffline,
    this.onUserSigExpired,
  });

  /// 正在连接。
  final VoidCallback? onConnecting;

  /// 连接成功。
  final VoidCallback? onConnectSuccess;

  /// 连接失败（SDK 会自动重试）。
  final void Function(int code, String message)? onConnectFailed;

  /// 在线时被其他终端踢下线。
  final VoidCallback? onKickedOffline;

  /// 在线期间 userSig 过期。
  final VoidCallback? onUserSigExpired;
}

/// IM SDK 抽象：生产环境由 [TimImGateway] 实现，测试使用内存假实现。
abstract interface class ImGateway {
  /// 初始化 SDK，成功返回 `true`。
  Future<bool> init({required int sdkAppId, required ImGatewayListener listener});

  /// 反初始化 SDK（切换 SDKAppID 前调用）。
  Future<void> unInit();

  /// 登录。
  Future<ImCallResult> login({required String userId, required String userSig});

  /// 退出登录。
  Future<ImCallResult> logout();
}
