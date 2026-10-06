import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

/// 手机号验证码登录页。
class LoginPage extends StatefulWidget {
  /// 创建登录页。
  const LoginPage({required this.cubit, super.key});

  /// 登录流程。
  final AuthCubit cubit;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  int _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLastPhone());
  }

  Future<void> _loadLastPhone() async {
    final phone = await widget.cubit.lastPhone();
    if (!mounted || phone == null || phone.isEmpty) return;
    _phoneController.text = phone;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _countdown = 0);
      } else if (mounted) {
        setState(() => _countdown -= 1);
      }
    });
  }

  Future<void> _sendCode() async {
    final ok = await widget.cubit.sendCode(_phoneController.text);
    if (ok) _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      bloc: widget.cubit,
      listenWhen: (prev, next) => prev.noticeId != next.noticeId && (next.message?.isNotEmpty ?? false),
      listener: (context, state) {
        final msg = state.message;
        if (msg != null && msg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      },
      builder: (context, state) {
        final loading = state.status == AuthStatus.authenticating;
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('猩子Talk', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      '班主任 / 管理人员 PC 客户端',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    if (widget.cubit.isInternalFallbackLogin) ...[
                      const SizedBox(height: 16),
                      const _FallbackBanner(),
                    ],
                    const SizedBox(height: 24),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: '手机号'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '短信验证码'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: state.sendingCode || _countdown > 0 ? null : _sendCode,
                          child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: loading
                          ? null
                          : () => widget.cubit.login(
                                phone: _phoneController.text,
                                code: _codeController.text,
                              ),
                      child: loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('登录'),
                    ),
                    if (state.canRetryRestore) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: loading ? null : widget.cubit.restore,
                        child: const Text('重试自动登录'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FallbackBanner extends StatelessWidget {
  const _FallbackBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '当前为内部联调登录链路（App 主 API），未注册手机号可能被自动建号。正式上线须切换 PC 专用接口，详见 docs/backend-requirements.md。',
        style: TextStyle(fontSize: 13, height: 1.4),
      ),
    );
  }
}
