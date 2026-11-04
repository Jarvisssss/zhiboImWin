import 'package:equatable/equatable.dart';

import '../../config/app_env.dart';
import 'user_role.dart';

/// IM 登录凭据，对应 `GET /im/app/login/getUserSig` 的 `result`。
///
/// 注意：`userSig` 属于敏感信息，只保存在内存，不落盘；需要时随时向后端重新获取。
class ImSign extends Equatable {
  /// 创建 IM 登录凭据。
  const ImSign({
    required this.userSig,
    required this.sdkAppId,
    required this.imUserId,
    required this.userRole,
  });

  /// 后端签发的 userSig。
  final String userSig;

  /// 腾讯云 IM 应用 ID。
  final int sdkAppId;

  /// IM 账号 ID。
  final String imUserId;

  /// 业务角色。
  final UserRole userRole;

  /// 从后端 JSON 解析；字段类型宽松（数字/字符串均可）。缺少关键字段时返回 `null`。
  static ImSign? tryParse(Object? json) {
    if (json is! Map) return null;
    final userSig = '${json['userSig'] ?? json['imUserSig'] ?? ''}';
    final imUserId = '${json['imUserId'] ?? ''}';
    if (userSig.isEmpty || imUserId.isEmpty) {
      return null;
    }
    final sdkAppId = AppDefines.resolveSdkAppId(_asInt(json['sdkAppId']) ?? 0);
    if (sdkAppId <= 0) {
      return null;
    }
    return ImSign(
      userSig: userSig,
      sdkAppId: sdkAppId,
      imUserId: imUserId,
      userRole: UserRole.fromRaw(json['userRole']),
    );
  }

  @override
  List<Object?> get props => [userSig, sdkAppId, imUserId, userRole];

  static int? _asInt(Object? value) => value is num ? value.toInt() : int.tryParse('${value ?? ''}');
}
