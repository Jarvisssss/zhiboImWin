import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// 统一日志封装。
///
/// 日志规范：禁止输出 token / userSig / userToken / 消息正文等敏感信息；
/// 需要定位问题时使用 [AppLogger.redact] 只保留头尾少量字符。
class AppLogger {
  /// 创建名为 [name] 的日志器，通常传类名。
  AppLogger(String name) : _logger = Logger(name);

  final Logger _logger;

  static bool _installed = false;

  /// 安装全局日志输出（只需在 main 中调用一次）。Debug 输出全部级别，Release 仅输出 INFO 及以上。
  static void install({Level? level}) {
    if (_installed) return;
    _installed = true;
    Logger.root.level = level ?? (kReleaseMode ? Level.INFO : Level.ALL);
    Logger.root.onRecord.listen((record) {
      final buffer = StringBuffer()
        ..write('[${record.level.name}] ')
        ..write('${record.loggerName}: ')
        ..write(record.message);
      if (record.error != null) buffer.write(' | error=${record.error}');
      debugPrint(buffer.toString());
      if (record.stackTrace != null && record.level >= Level.SEVERE) {
        debugPrint(record.stackTrace.toString());
      }
    });
  }

  /// 调试日志。
  void debug(Object? message) => _logger.fine(message);

  /// 信息日志。
  void info(Object? message) => _logger.info(message);

  /// 警告日志。
  void warn(Object? message, [Object? error]) => _logger.warning(message, error);

  /// 错误日志。
  void error(Object? message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);

  /// 对敏感字符串脱敏：仅保留前 [keep] 个字符与长度，如 `abcd…(len=128)`。
  static String redact(String? value, {int keep = 4}) {
    if (value == null || value.isEmpty) return '(empty)';
    if (value.length <= keep) return '***(len=${value.length})';
    return '${value.substring(0, keep)}…(len=${value.length})';
  }
}
