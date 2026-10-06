import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'dependency_container.dart';

/// 应用启动引导结果。
class BootstrapResult {
  /// 创建引导结果。
  const BootstrapResult({required this.container});

  /// 依赖容器。
  final DependencyContainer container;
}

/// 进程级初始化：Flutter 绑定、桌面窗口、依赖容器与自动登录。
Future<BootstrapResult> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS || Platform.isWindows) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(960, 640),
      center: true,
      title: '猩子Talk',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final container = await DependencyContainer.create();
  await container.authCubit.restore();
  return BootstrapResult(container: container);
}
