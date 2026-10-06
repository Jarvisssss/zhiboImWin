import 'package:flutter/material.dart';

import 'app/bootstrap.dart';
import 'app/zhibo_talk_app.dart';
import 'shared/utils/app_logger.dart';

Future<void> main() async {
  AppLogger.install();
  final boot = await bootstrap();
  runApp(ZhiboTalkApp(container: boot.container));
}
