import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/cubit/auth_cubit.dart';
import '../features/auth/cubit/auth_state.dart';
import '../features/auth/view/login_page.dart';
import '../features/shell/desktop_shell_page.dart';
import '../shared/chat/large_file_config_bootstrap.dart';
import '../shared/im/im_session_manager.dart';
import '../shared/services/coze/coze_token_manager.dart';
import 'app_theme.dart';
import 'dependency_container.dart';

/// 根 Widget：路由、登录态与 IM 生命周期联动。
class ZhiboTalkApp extends StatefulWidget {
  /// 创建应用。
  const ZhiboTalkApp({required this.container, super.key});

  /// 依赖容器。
  final DependencyContainer container;

  @override
  State<ZhiboTalkApp> createState() => _ZhiboTalkAppState();
}

class _ZhiboTalkAppState extends State<ZhiboTalkApp> {
  late final GoRouter _router;
  StreamSubscription<ImSessionEvent>? _imEvents;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      refreshListenable: _AuthRefreshListenable(widget.container.authCubit),
      redirect: (context, state) {
        final auth = widget.container.authCubit.state;
        final onLogin = state.matchedLocation == '/login';
        if (auth.status == AuthStatus.initializing) {
          return onLogin ? null : '/login';
        }
        if (auth.status == AuthStatus.authenticating) {
          return null;
        }
        if (!auth.isAuthenticated && !onLogin) return '/login';
        if (auth.isAuthenticated && onLogin) return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginPage(cubit: widget.container.authCubit),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => DesktopShellPage(container: widget.container),
        ),
      ],
    );

    _imEvents = widget.container.imSessionManager.events.listen(_onImSessionEvent);
    unawaited(_syncImWithAuth(widget.container.authCubit.state));
  }

  @override
  void dispose() {
    _imEvents?.cancel();
    _router.dispose();
    super.dispose();
  }

  Future<void> _onImSessionEvent(ImSessionEvent event) async {
    final cubit = widget.container.authCubit;
    switch (event) {
      case ImKickedOut():
        await cubit.logout(reason: '您的账号已在其他设备登录');
      case ImAuthFailed(:final message):
        await cubit.handleSessionExpired(message);
    }
  }

  Future<void> _syncImWithAuth(AuthState auth) async {
    final im = widget.container.imSessionManager;
    final hub = widget.container.imEventHub;
    if (auth.isAuthenticated && auth.sign != null) {
      final sign = auth.sign!;
      if (!sign.userRole.canUseDesktop) {
        await widget.container.authCubit.logout(reason: '当前账号无权使用 PC 客户端');
        return;
      }
      ensureLargeFileConfig(widget.container.imApi);
      CozeTokenManager.bind(widget.container.imApi);
      final result = await im.start(sign);
      if (result.status == ImConnectionStatus.connected) {
        await hub.attach();
      }
    } else if (auth.status == AuthStatus.unauthenticated) {
      await hub.detach();
      await im.stop();
      CozeTokenManager.instance.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.container.authCubit,
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (prev, next) =>
            prev.status != next.status || prev.sign?.userSig != next.sign?.userSig,
        listener: (context, state) => unawaited(_syncImWithAuth(state)),
        child: MaterialApp.router(
          title: '猩子Talk',
          theme: buildAppTheme(),
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
        ),
      ),
    );
  }
}

/// 将 [AuthCubit] 状态变化通知 [GoRouter] 刷新 redirect。
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(AuthCubit cubit) : _cubit = cubit {
    _subscription = _cubit.stream.listen((_) => notifyListeners());
  }

  final AuthCubit _cubit;
  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
