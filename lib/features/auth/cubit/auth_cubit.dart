import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../config/app_env.dart';
import '../../../shared/models/im_sign.dart';
import '../../../shared/network/api_exception.dart';
import '../../../shared/utils/app_logger.dart';
import '../data/auth_repository.dart';
import '../data/session_store.dart';
import 'auth_state.dart';

/// 手机号校验（与小程序一致：1 开头的 11 位数字）。
bool isValidPhone(String value) => RegExp(r'^1\d{10}$').hasMatch(value.trim());

/// 登录流程：验证码登录、启动自动登录、退出与登录失效处理。
class AuthCubit extends Cubit<AuthState> {
  /// 创建登录流程。
  AuthCubit({required AuthRepository repository, required SessionStore store})
      : _repository = repository,
        _store = store,
        super(const AuthState.initializing());

  final AuthRepository _repository;
  final SessionStore _store;
  final AppLogger _log = AppLogger('AuthCubit');

  /// 是否处于「内部联调」兜底登录链路（登录页据此展示提示，见 docs/backend-requirements.md 1.3）。
  bool get isInternalFallbackLogin => _repository.mode == AuthMode.appAccount;

  /// 读取最近使用的手机号，用于登录页回填。
  Future<String?> lastPhone() => _store.loadLastPhone();

  /// 启动时恢复登录：读取本地会话并向后端换取新的 IM 凭据。
  Future<void> restore() async {
    emit(const AuthState.initializing());
    final saved = await _store.load();
    if (saved == null) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }
    emit(AuthState(status: AuthStatus.authenticating, session: saved));
    try {
      final sign = await _repository.fetchImSign(saved);
      final session = saved.copyWith(imUserId: sign.imUserId, role: sign.userRole);
      if (session != saved) await _store.save(session);
      emit(AuthState(status: AuthStatus.authenticated, session: session, sign: sign));
    } on ApiException catch (error) {
      final fatal = error.isAuthExpired || error.kind == ApiErrorKind.business;
      if (fatal) await _store.clear();
      _log.warn('自动登录失败 kind=${error.kind.name}');
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          message: error.isAuthExpired ? '登录已过期，请重新登录' : error.message,
          noticeId: state.noticeId + 1,
          // 网络类错误保留会话，让用户可以直接重试而不必重新收验证码。
          session: fatal ? null : saved,
          canRetryRestore: !fatal,
        ),
      );
    }
  }

  /// 发送验证码，成功返回 `true`；失败时通过 [AuthState.message] 通知 UI。
  Future<bool> sendCode(String phone) async {
    final normalized = phone.trim();
    if (!isValidPhone(normalized)) {
      _notice('请输入正确的 11 位手机号');
      return false;
    }
    emit(state.copyWith(sendingCode: true));
    try {
      await _repository.sendCode(normalized);
      emit(state.copyWith(sendingCode: false));
      return true;
    } on ApiException catch (error) {
      emit(state.copyWith(sendingCode: false));
      _notice(error.message);
      return false;
    }
  }

  /// 验证码登录。
  Future<void> login({required String phone, required String code}) async {
    final normalized = phone.trim();
    final verifyCode = code.trim();
    if (!isValidPhone(normalized)) return _notice('请输入正确的 11 位手机号');
    if (verifyCode.length < 4) return _notice('请输入短信验证码');

    emit(state.copyWith(status: AuthStatus.authenticating, message: '', canRetryRestore: false));
    try {
      final result = await _repository.loginWithCode(phone: normalized, code: verifyCode);
      await _store.save(result.session);
      await _store.saveLastPhone(normalized);
      emit(AuthState(status: AuthStatus.authenticated, session: result.session, sign: result.sign, noticeId: state.noticeId));
    } on ApiException catch (error) {
      _log.warn('登录失败 kind=${error.kind.name} failCode=${error.failCode}');
      emit(state.copyWith(status: AuthStatus.unauthenticated, clearSession: true, clearSign: true));
      _notice(error.message);
    }
  }

  /// 为 IM 续期重新获取凭据（不改变登录状态，避免触发 IM 重新启动）。
  Future<ImSign> refreshSign() async {
    final session = state.session;
    if (session == null) {
      throw const ApiException(kind: ApiErrorKind.authExpired, message: '尚未登录');
    }
    return _repository.fetchImSign(session);
  }

  /// 退出登录，可携带原因（被踢、登录失效等）。
  Future<void> logout({String? reason}) async {
    final session = state.session;
    emit(
      AuthState(
        status: AuthStatus.unauthenticated,
        message: reason,
        noticeId: state.noticeId + (reason == null ? 0 : 1),
      ),
    );
    await _store.clear();
    if (session != null) unawaited(_repository.logout(session));
  }

  /// 业务接口返回登录失效时调用，统一回到登录页。
  Future<void> handleSessionExpired([String message = '登录已过期，请重新登录']) => logout(reason: message);

  void _notice(String message) {
    emit(state.copyWith(message: message, noticeId: state.noticeId + 1));
  }
}
