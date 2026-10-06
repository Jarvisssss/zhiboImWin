import 'package:equatable/equatable.dart';

import 'user_role.dart';

/// 登录会话（持久化到本地，用于下次启动自动登录）。
///
/// 只包含业务 token 与身份信息；**不包含 userSig**，userSig 每次启动由后端重新签发。
class AuthSession extends Equatable {
  /// 创建会话。
  const AuthSession({
    required this.token,
    required this.userId,
    required this.imUserId,
    required this.role,
    this.nick = '',
    this.avatar = '',
  });

  /// 业务 token（`X-Access-Token` 或主 API `Authorization`）。
  final String token;

  /// 主业务用户 ID，方案 A 下作为 `userToken` 的明文。
  final String userId;

  /// IM 账号 ID。
  final String imUserId;

  /// 业务角色。
  final UserRole role;

  /// 昵称（展示用，可为空）。
  final String nick;

  /// 头像地址（展示用，可为空）。
  final String avatar;

  /// 返回替换了部分字段的新会话。
  AuthSession copyWith({
    String? token,
    String? userId,
    String? imUserId,
    UserRole? role,
    String? nick,
    String? avatar,
  }) {
    return AuthSession(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      imUserId: imUserId ?? this.imUserId,
      role: role ?? this.role,
      nick: nick ?? this.nick,
      avatar: avatar ?? this.avatar,
    );
  }

  /// 序列化为可持久化的 JSON。
  Map<String, Object?> toJson() => {
        'token': token,
        'userId': userId,
        'imUserId': imUserId,
        'role': role.rawValue,
        'nick': nick,
        'avatar': avatar,
      };

  /// 从持久化 JSON 恢复；数据缺失/损坏时返回 `null`。
  static AuthSession? tryParse(Object? json) {
    if (json is! Map) return null;
    final token = '${json['token'] ?? ''}';
    final userId = '${json['userId'] ?? ''}';
    final imUserId = '${json['imUserId'] ?? ''}';
    if (token.isEmpty || userId.isEmpty || imUserId.isEmpty) return null;
    return AuthSession(
      token: token,
      userId: userId,
      imUserId: imUserId,
      role: UserRole.fromRaw(json['role']),
      nick: '${json['nick'] ?? ''}',
      avatar: '${json['avatar'] ?? ''}',
    );
  }

  @override
  List<Object?> get props => [token, userId, imUserId, role, nick, avatar];
}
