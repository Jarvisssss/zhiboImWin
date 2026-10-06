import 'package:equatable/equatable.dart';

import '../../../shared/models/auth_session.dart';
import '../../../shared/models/im_sign.dart';

/// 登录流程状态。
enum AuthStatus {
  /// 启动中，正在读取本地会话。
  initializing,

  /// 未登录（可展示登录页，`message` 携带失败原因）。
  unauthenticated,

  /// 登录 / 自动登录进行中。
  authenticating,

  /// 已登录，`session` 与 `sign` 均有值。
  authenticated,
}

/// 登录状态快照。
class AuthState extends Equatable {
  /// 创建状态。
  const AuthState({
    this.status = AuthStatus.initializing,
    this.session,
    this.sign,
    this.message,
    this.noticeId = 0,
    this.sendingCode = false,
    this.canRetryRestore = false,
  });

  /// 启动中。
  const AuthState.initializing() : this();

  /// 当前状态。
  final AuthStatus status;

  /// 登录会话（仅 authenticated，或自动登录进行中时有值）。
  final AuthSession? session;

  /// IM 登录凭据（仅 authenticated）。
  final ImSign? sign;

  /// 面向用户的提示（失败原因 / 被踢提示）。
  final String? message;

  /// 提示序号：同一文案连续出现时仍能触发 UI 的 `BlocListener`。
  final int noticeId;

  /// 是否正在发送验证码。
  final bool sendingCode;

  /// 自动登录因网络等原因失败，会话仍保留，允许用户点击「重试」。
  final bool canRetryRestore;

  /// 是否已登录。
  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// 复制并替换部分字段；`message` 传入空串表示清除。
  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    ImSign? sign,
    String? message,
    int? noticeId,
    bool? sendingCode,
    bool? canRetryRestore,
    bool clearSession = false,
    bool clearSign = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      sign: clearSign ? null : (sign ?? this.sign),
      message: message == null ? this.message : (message.isEmpty ? null : message),
      noticeId: noticeId ?? this.noticeId,
      sendingCode: sendingCode ?? this.sendingCode,
      canRetryRestore: canRetryRestore ?? this.canRetryRestore,
    );
  }

  @override
  List<Object?> get props => [status, session, sign, message, noticeId, sendingCode, canRetryRestore];
}
