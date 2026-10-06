import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/auth_session.dart';

/// 登录会话持久化接口。
abstract interface class SessionStore {
  /// 读取已保存的会话，不存在或数据损坏时返回 `null`。
  Future<AuthSession?> load();

  /// 保存会话。
  Future<void> save(AuthSession session);

  /// 清除会话（退出登录 / 登录失效）。
  Future<void> clear();

  /// 读取最近一次登录使用的手机号（仅用于登录页回填）。
  Future<String?> loadLastPhone();

  /// 保存最近一次登录使用的手机号。
  Future<void> saveLastPhone(String phone);

  /// 获取（必要时生成）本机设备 ID，用于后端设备审计。
  Future<String> deviceId();
}

/// 基于 `shared_preferences` 的实现。
///
/// 取舍说明：token 存放在用户目录下的偏好文件中，安全级别与微信小程序本地存储相当；
/// 未使用系统凭据库是因为 `flutter_secure_storage` 在 Windows 需要额外安装 ATL 组件、
/// 在 macOS 需要 Keychain 授权与签名团队，会显著抬高构建门槛。后续如需加固，只需新增 [SessionStore] 实现即可替换。
class PrefsSessionStore implements SessionStore {
  /// 创建存储。
  PrefsSessionStore(this._prefs);

  static const String _sessionKey = 'zb.auth.session.v1';
  static const String _phoneKey = 'zb.auth.lastPhone';
  static const String _deviceKey = 'zb.device.id';

  final SharedPreferences _prefs;

  @override
  Future<AuthSession?> load() async {
    final raw = _prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AuthSession.tryParse(jsonDecode(raw));
    } on FormatException {
      await _prefs.remove(_sessionKey);
      return null;
    }
  }

  @override
  Future<void> save(AuthSession session) async {
    await _prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_sessionKey);
  }

  @override
  Future<String?> loadLastPhone() async => _prefs.getString(_phoneKey);

  @override
  Future<void> saveLastPhone(String phone) async {
    await _prefs.setString(_phoneKey, phone);
  }

  @override
  Future<String> deviceId() async {
    final existing = _prefs.getString(_deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = const Uuid().v4();
    await _prefs.setString(_deviceKey, created);
    return created;
  }
}
