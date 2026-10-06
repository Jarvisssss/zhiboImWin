import 'dart:io';

import '../../../config/app_env.dart';
import '../../../shared/models/auth_session.dart';
import '../../../shared/models/im_sign.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/network/api_exception.dart';
import '../../../shared/services/im_api.dart';
import '../../../shared/utils/app_logger.dart';
import 'account_api.dart';
import 'pc_login_api.dart';
import 'session_store.dart';

/// 一次成功登录的结果。
class LoginResult {
  /// 创建结果。
  const LoginResult({required this.session, required this.sign});

  /// 需要持久化的登录会话。
  final AuthSession session;

  /// 用于登录 IM 的凭据（仅内存持有）。
  final ImSign sign;
}

/// 登录仓库：屏蔽「兜底链路」与「PC 专用接口」两种实现的差异。
abstract interface class AuthRepository {
  /// 当前使用的登录模式。
  AuthMode get mode;

  /// 发送登录验证码。
  Future<void> sendCode(String phone);

  /// 验证码登录；返回会话与 IM 凭据。学员等不允许的角色会抛出 failCode=3 的 [ApiException]。
  Future<LoginResult> loginWithCode({required String phone, required String code});

  /// 使用已保存的会话重新获取 IM 凭据（启动自动登录 / userSig 续期）。
  Future<ImSign> fetchImSign(AuthSession session);

  /// 退出登录（服务端部分 best effort，不抛异常）。
  Future<void> logout(AuthSession session);
}

/// 角色白名单校验：学员、AI 助教与未知角色一律不允许使用 PC 客户端。
void ensureRoleAllowed(UserRole role) {
  if (!role.canUseDesktop) {
    throw const ApiException(
      kind: ApiErrorKind.business,
      message: '该账号角色暂不支持 PC 客户端，请使用「猩子Talk」小程序或智博在线 App',
      failCode: 3,
    );
  }
}

/// 兜底链路：App 主 API 验证码登录 → `/im/app/login/getUserSig`。仅限内部联调。
class AppAccountAuthRepository implements AuthRepository {
  /// 创建仓库。
  AppAccountAuthRepository({required AccountApi accountApi, required ImApi imApi})
      : _accountApi = accountApi,
        _imApi = imApi;

  final AccountApi _accountApi;
  final ImApi _imApi;

  @override
  AuthMode get mode => AuthMode.appAccount;

  @override
  Future<void> sendCode(String phone) => _accountApi.sendCode(phone);

  @override
  Future<LoginResult> loginWithCode({required String phone, required String code}) async {
    final user = await _accountApi.verifyCodeLogin(phone, code);
    // getUserSig 只需要主业务 userId 即可生成 userToken，此时 IM 身份与角色尚未确定。
    final draft = AuthSession(
      token: user.token,
      userId: user.id,
      imUserId: '',
      role: UserRole.unknown,
      nick: user.name,
      avatar: user.avatarUrl,
    );
    final sign = await _imApi.fetchUserSig(session: draft);
    ensureRoleAllowed(sign.userRole);
    return LoginResult(
      session: draft.copyWith(imUserId: sign.imUserId, role: sign.userRole),
      sign: sign,
    );
  }

  @override
  Future<ImSign> fetchImSign(AuthSession session) async {
    final sign = await _imApi.fetchUserSig(session: session);
    ensureRoleAllowed(sign.userRole);
    return sign;
  }

  @override
  Future<void> logout(AuthSession session) async {
    // App 主账号体系没有服务端登出接口，本地清理即可。
  }
}

/// 目标链路：PC 专用登录接口（`clientType=pc`），响应直接携带 IM 凭据。
class PcLoginAuthRepository implements AuthRepository {
  /// 创建仓库。
  PcLoginAuthRepository({
    required PcLoginApi pcLoginApi,
    required ImApi imApi,
    required SessionStore store,
    int fallbackSdkAppId = AppDefines.sdkAppId,
  })  : _pcLoginApi = pcLoginApi,
        _imApi = imApi,
        _store = store,
        _fallbackSdkAppId = fallbackSdkAppId;

  final PcLoginApi _pcLoginApi;
  final ImApi _imApi;
  final SessionStore _store;
  final int _fallbackSdkAppId;
  final AppLogger _log = AppLogger('PcLoginAuthRepository');

  @override
  AuthMode get mode => AuthMode.pcLogin;

  @override
  Future<void> sendCode(String phone) => _pcLoginApi.sendCaptcha(phone);

  @override
  Future<LoginResult> loginWithCode({required String phone, required String code}) async {
    final result = await _pcLoginApi.login(
      phone: phone,
      captcha: code,
      deviceId: await _store.deviceId(),
      deviceName: describeDevice(),
    );
    ensureRoleAllowed(result.role);
    final sdkAppId = result.sdkAppId > 0 ? result.sdkAppId : _fallbackSdkAppId;
    if (sdkAppId <= 0) {
      throw const ApiException(kind: ApiErrorKind.parse, message: '登录返回缺少 sdkAppId，请联系管理员（见 docs/backend-requirements.md B1）');
    }
    return LoginResult(
      session: AuthSession(
        token: result.token,
        userId: result.userId,
        imUserId: result.imUserId,
        role: result.role,
        nick: result.nick,
        avatar: result.avatar,
      ),
      sign: ImSign(
        userSig: result.imUserSig,
        sdkAppId: sdkAppId,
        imUserId: result.imUserId,
        userRole: result.role,
      ),
    );
  }

  @override
  Future<ImSign> fetchImSign(AuthSession session) async {
    final sign = await _imApi.fetchUserSig(session: session);
    ensureRoleAllowed(sign.userRole);
    return sign;
  }

  @override
  Future<void> logout(AuthSession session) async {
    try {
      await _pcLoginApi.logout(session.token);
    } catch (error) {
      _log.warn('服务端退出失败（已忽略）', error);
    }
  }

  /// 生成设备描述，如 `windows 10.0.26100 / DESKTOP-ABC`，用于服务端审计。
  static String describeDevice() {
    final host = Platform.localHostname;
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion} / $host';
  }
}
