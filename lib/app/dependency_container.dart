import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_env.dart';
import 'app_theme.dart';
import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/data/account_api.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/pc_login_api.dart';
import '../features/auth/data/session_store.dart';
import '../shared/im/im_event_hub.dart';
import '../shared/im/im_session_manager.dart';
import '../shared/im/tim_im_gateway.dart';
import '../shared/network/api_client.dart';
import '../shared/network/api_envelope.dart';
import '../shared/network/auth_header_strategy.dart';
import '../shared/services/im_api.dart';

/// 应用级依赖容器（进程内单例，测试时可替换）。
class DependencyContainer {
  /// 创建容器并完成异步初始化。
  static Future<DependencyContainer> create() async {
    final prefs = await SharedPreferences.getInstance();
    final store = PrefsSessionStore(prefs);
    final env = AppEnv.current;

    final mainApi = ApiClient(baseUrl: env.apiHost, style: EnvelopeStyle.main, name: 'MainApi');
    final eipApi = ApiClient(baseUrl: env.eipHost, style: EnvelopeStyle.eip, name: 'EipApi');

    final authMode = AuthMode.parse(AppDefines.authMode);
    final headerMode = AuthHeaderMode.parse(AppDefines.authHeader);
    final AuthHeaderStrategy headerStrategy = switch (headerMode) {
      AuthHeaderMode.accessToken => const AccessTokenHeaderStrategy(),
      AuthHeaderMode.userToken => UserTokenHeaderStrategy(secretKey: AppDefines.imTokenKey),
    };

    late AuthCubit authCubit;
    final imApi = ImApi(
      client: eipApi,
      headerStrategy: headerStrategy,
      sessionProvider: () => authCubit.state.session,
    );

    final AuthRepository authRepository = switch (authMode) {
      AuthMode.pcLogin => PcLoginAuthRepository(
          pcLoginApi: PcLoginApi(client: eipApi),
          imApi: imApi,
          store: store,
        ),
      AuthMode.appAccount => AppAccountAuthRepository(
          accountApi: AccountApi(client: mainApi),
          imApi: imApi,
        ),
    };

    authCubit = AuthCubit(repository: authRepository, store: store);

    final gateway = TimImGateway(theme: buildTuiTheme(ColorScheme.fromSeed(seedColor: kBrandPrimary)));
    final imSessionManager = ImSessionManager(
      gateway: gateway,
      renewSign: () => authCubit.refreshSign(),
    );
    final imEventHub = ImEventHub();

    return DependencyContainer._(
      store: store,
      authCubit: authCubit,
      imApi: imApi,
      imSessionManager: imSessionManager,
      imEventHub: imEventHub,
      gateway: gateway,
    );
  }

  DependencyContainer._({
    required this.store,
    required this.authCubit,
    required this.imApi,
    required this.imSessionManager,
    required this.imEventHub,
    required this.gateway,
  });

  /// 会话存储。
  final SessionStore store;

  /// 登录状态。
  final AuthCubit authCubit;

  /// IM 业务接口。
  final ImApi imApi;

  /// IM 连接管理。
  final ImSessionManager imSessionManager;

  /// IM 事件（未读、新消息）。
  final ImEventHub imEventHub;

  /// IM 网关（UIKit 提示等）。
  final TimImGateway gateway;

  /// 释放资源。
  Future<void> dispose() async {
    await imEventHub.dispose();
    await imSessionManager.dispose();
    await authCubit.close();
  }
}
