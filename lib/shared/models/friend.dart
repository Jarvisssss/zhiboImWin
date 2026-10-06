import 'package:equatable/equatable.dart';

/// 联系人，对应 `GET /im/app/login/lstUserFriends` 的单条数据。
class Friend extends Equatable {
  /// 创建联系人。
  const Friend({
    required this.userId,
    required this.nick,
    this.faceUrl = '',
    this.roleName = '',
    this.sortNo = 0,
  });

  /// IM 账号 ID。
  final String userId;

  /// 昵称。
  final String nick;

  /// 头像。
  final String faceUrl;

  /// 角色展示名，如「班主任」「学员」。
  final String roleName;

  /// 排序号，越小越靠前。
  final int sortNo;

  /// 从后端 JSON 解析，缺少 userId 时返回 `null`。
  static Friend? tryParse(Object? json) {
    if (json is! Map) return null;
    final userId = '${json['userId'] ?? ''}';
    if (userId.isEmpty) return null;
    return Friend(
      userId: userId,
      nick: '${json['nick'] ?? ''}',
      faceUrl: '${json['faceUrl'] ?? ''}',
      roleName: '${json['roleName'] ?? ''}',
      sortNo: json['sortNo'] is num ? (json['sortNo'] as num).toInt() : int.tryParse('${json['sortNo'] ?? 0}') ?? 0,
    );
  }

  @override
  List<Object?> get props => [userId, nick, faceUrl, roleName, sortNo];
}
