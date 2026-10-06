import 'dart:async';

import '../../utils/app_logger.dart';
import '../im_api.dart';

/// 扣子 API Token 管理（单例）：内存缓存 + 过期检测 + 并发刷新合并。
class CozeTokenManager {
  CozeTokenManager._();

  static final CozeTokenManager instance = CozeTokenManager._();

  static const Duration _cacheTtl = Duration(minutes: 30);

  final AppLogger _log = AppLogger('CozeTokenManager');

  ImApi? _imApi;
  String? _accessToken;
  DateTime? _fetchTime;
  Completer<String>? _refreshCompleter;

  /// 绑定云校园 [ImApi]（登录成功后调用）。
  static void bind(ImApi imApi) {
    instance._imApi = imApi;
  }

  /// 获取有效 Token，过期则自动刷新。
  Future<String> getToken() async {
    if (_accessToken != null && !_isExpired()) {
      return _accessToken!;
    }
    return _refreshToken();
  }

  /// 强制失效（收到 401 时调用）。
  void invalidate() {
    _accessToken = null;
    _fetchTime = null;
  }

  /// 清理（退出登录时调用）。
  void clear() {
    _imApi = null;
    invalidate();
    _refreshCompleter = null;
  }

  bool _isExpired() {
    if (_fetchTime == null) return true;
    return DateTime.now().difference(_fetchTime!) > _cacheTtl;
  }

  Future<String> _refreshToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    final api = _imApi;
    if (api == null) {
      throw StateError('CozeTokenManager 尚未绑定 ImApi');
    }
    _refreshCompleter = Completer<String>();
    try {
      final token = await api.fetchCozeToken();
      _accessToken = token;
      _fetchTime = DateTime.now();
      _log.info('Coze token 已刷新');
      _refreshCompleter!.complete(token);
      return token;
    } catch (error, stack) {
      _log.error('Coze token 刷新失败', error, stack);
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.completeError(error);
      }
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }
}
