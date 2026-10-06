import 'dart:async';

import 'package:equatable/equatable.dart';

import '../models/im_sign.dart';
import '../utils/app_logger.dart';
import 'im_error_codes.dart';
import 'im_gateway.dart';

/// IM 连接状态。
enum ImConnectionStatus {
  /// 未启动。
  idle,

  /// 正在连接 / 重连。
  connecting,

  /// 已连接。
  connected,

  /// 登录失败（需要用户处理或重试）。
  failed,

  /// 被其他终端踢下线。
  kickedOut,
}

/// IM 会话状态快照。
class ImSessionState extends Equatable {
  /// 创建状态。
  const ImSessionState(this.status, {this.errorCode, this.message});

  /// 未启动。
  const ImSessionState.idle() : this(ImConnectionStatus.idle);

  /// 连接中。
  const ImSessionState.connecting({String? message}) : this(ImConnectionStatus.connecting, message: message);

  /// 已连接。
  const ImSessionState.connected() : this(ImConnectionStatus.connected);

  /// 状态。
  final ImConnectionStatus status;

  /// 失败时的 IM 错误码。
  final int? errorCode;

  /// 面向用户的提示。
  final String? message;

  /// 是否已连接。
  bool get isConnected => status == ImConnectionStatus.connected;

  @override
  List<Object?> get props => [status, errorCode, message];
}

/// 需要上层（登录态）处理的 IM 事件。
sealed class ImSessionEvent {
  const ImSessionEvent();
}

/// 账号在其他设备登录，当前端被踢下线。
class ImKickedOut extends ImSessionEvent {
  /// 创建事件。
  const ImKickedOut();
}

/// 无法自动恢复的鉴权失败（续期失败/配置错误），需要重新登录。
class ImAuthFailed extends ImSessionEvent {
  /// 创建事件。
  const ImAuthFailed(this.message, {this.code});

  /// 面向用户的提示。
  final String message;

  /// IM 错误码。
  final int? code;
}

/// IM 登录生命周期管理：初始化、登录、userSig 续期、被踢与重连状态。
///
/// 续期策略（遵循官方「其他错误码不要在登录回调里再次 login」的约束）：
/// - 登录失败且错误码属于 [ImErrorCodes.renewable] 时，**只重试一次**：向后端获取新签名后再登录；
/// - 在线期间收到 `onUserSigExpired` 时同样续期并重新登录，且在 [renewWindow] 内最多 [maxRenewalsPerWindow] 次，防止循环；
/// - 其它错误码一律直接上报，不自动重试。
class ImSessionManager {
  /// 创建管理器。
  ///
  /// [renewSign] 向后端重新获取 IM 凭据；[clock] 仅用于测试注入时间。
  ImSessionManager({
    required ImGateway gateway,
    required Future<ImSign> Function() renewSign,
    this.renewWindow = const Duration(minutes: 10),
    this.maxRenewalsPerWindow = 3,
    DateTime Function()? clock,
  })  : _gateway = gateway,
        _renewSign = renewSign,
        _clock = clock ?? DateTime.now;

  /// 续期次数统计窗口。
  final Duration renewWindow;

  /// 窗口内允许的最大续期次数。
  final int maxRenewalsPerWindow;

  final ImGateway _gateway;
  final Future<ImSign> Function() _renewSign;
  final DateTime Function() _clock;
  final AppLogger _log = AppLogger('ImSessionManager');

  final StreamController<ImSessionState> _states = StreamController<ImSessionState>.broadcast();
  final StreamController<ImSessionEvent> _events = StreamController<ImSessionEvent>.broadcast();
  final List<DateTime> _renewTimes = [];

  ImSessionState _state = const ImSessionState.idle();
  int? _initializedSdkAppId;
  ImSign? _current;
  bool _starting = false;
  bool _renewing = false;

  /// 当前状态。
  ImSessionState get state => _state;

  /// 状态变化流。
  Stream<ImSessionState> get states => _states.stream;

  /// 需要上层处理的事件流。
  Stream<ImSessionEvent> get events => _events.stream;

  /// 启动 IM：初始化（必要时）并登录。返回最终状态。
  Future<ImSessionState> start(ImSign sign) async {
    if (_starting) return _state;
    _starting = true;
    try {
      _current = sign;
      _emit(const ImSessionState.connecting());

      if (_initializedSdkAppId != null && _initializedSdkAppId != sign.sdkAppId) {
        await _gateway.unInit();
        _initializedSdkAppId = null;
      }
      if (_initializedSdkAppId == null) {
        final ok = await _gateway.init(sdkAppId: sign.sdkAppId, listener: _buildListener());
        if (!ok) return _fail(-1, 'IM 初始化失败，请重启应用后重试');
        _initializedSdkAppId = sign.sdkAppId;
      }

      var result = await _gateway.login(userId: sign.imUserId, userSig: sign.userSig);
      if (!result.ok && ImErrorCodes.isUserSigExpired(result.code)) {
        _log.warn('登录返回可续期错误码 ${result.code}，尝试续期一次');
        final fresh = await _tryRenew();
        if (fresh == null) {
          return _fail(result.code, ImErrorCodes.describe(result.code), authFailed: true);
        }
        _current = fresh;
        result = await _gateway.login(userId: fresh.imUserId, userSig: fresh.userSig);
      }

      if (result.ok) {
        _emit(const ImSessionState.connected());
        return _state;
      }
      _log.warn('IM 登录失败 code=${result.code}');
      return _fail(
        result.code,
        ImErrorCodes.describe(result.code),
        authFailed: ImErrorCodes.isConfigurationError(result.code) || result.code == ImErrorCodes.accountBlocked,
      );
    } finally {
      _starting = false;
    }
  }

  /// 退出 IM 并回到 idle。
  Future<void> stop() async {
    _current = null;
    try {
      await _gateway.logout();
    } catch (error) {
      _log.warn('退出 IM 异常', error);
    }
    _emit(const ImSessionState.idle());
  }

  /// 释放资源。
  Future<void> dispose() async {
    await _states.close();
    await _events.close();
  }

  ImGatewayListener _buildListener() {
    return ImGatewayListener(
      onConnecting: () {
        if (_state.status != ImConnectionStatus.kickedOut) {
          _emit(const ImSessionState.connecting());
        }
      },
      onConnectSuccess: () {
        if (_state.status != ImConnectionStatus.kickedOut) {
          _emit(const ImSessionState.connected());
        }
      },
      onConnectFailed: (code, message) {
        _log.warn('IM 连接失败 code=$code（SDK 会自动重试）');
        if (_state.status != ImConnectionStatus.kickedOut) {
          _emit(ImSessionState.connecting(message: ImErrorCodes.describe(code)));
        }
      },
      onKickedOffline: () {
        _emit(const ImSessionState(ImConnectionStatus.kickedOut, errorCode: ImErrorCodes.kickedOffByOther, message: '您的账号已在其他设备登录'));
        _events.add(const ImKickedOut());
      },
      onUserSigExpired: () => unawaited(_renewAndRelogin()),
    );
  }

  /// 在线期间 userSig 过期：续期后重新登录。
  Future<void> _renewAndRelogin() async {
    if (_renewing || _current == null) return;
    _renewing = true;
    try {
      final fresh = await _tryRenew();
      if (fresh == null) {
        _fail(ImErrorCodes.userSigExpired, ImErrorCodes.describe(ImErrorCodes.userSigExpired), authFailed: true);
        return;
      }
      _current = fresh;
      final result = await _gateway.login(userId: fresh.imUserId, userSig: fresh.userSig);
      if (result.ok) {
        _emit(const ImSessionState.connected());
      } else {
        _fail(result.code, ImErrorCodes.describe(result.code), authFailed: true);
      }
    } finally {
      _renewing = false;
    }
  }

  /// 受频率限制的续期：窗口内超过上限直接放弃，避免死循环。
  Future<ImSign?> _tryRenew() async {
    final now = _clock();
    _renewTimes.removeWhere((time) => now.difference(time) > renewWindow);
    if (_renewTimes.length >= maxRenewalsPerWindow) {
      _log.warn('userSig 续期过于频繁，已停止自动续期');
      return null;
    }
    _renewTimes.add(now);
    try {
      return await _renewSign();
    } catch (error) {
      _log.warn('userSig 续期失败', error);
      return null;
    }
  }

  ImSessionState _fail(int code, String message, {bool authFailed = false}) {
    _emit(ImSessionState(ImConnectionStatus.failed, errorCode: code, message: message));
    if (authFailed) _events.add(ImAuthFailed(message, code: code));
    return _state;
  }

  void _emit(ImSessionState next) {
    if (next == _state) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
