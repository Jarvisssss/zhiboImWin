/// 业务用户角色（与 App `UserRole` / 后端 `userRole` 取值一致）。
///
/// 1 班主任、2 学员、3 高数助教、4 语文助教、5 计算机助教、6 英语助教、7 政治助教、
/// 10 招生班主任、20 群管理员、30/40/50/60 AI 助教（机器人账号）。
enum UserRole {
  /// 班主任。
  headTeacher(1, '班主任'),

  /// 学员。
  student(2, '学员'),

  /// 高数助教。
  mathTeacher(3, '高数助教'),

  /// 语文助教。
  chineseTeacher(4, '语文助教'),

  /// 计算机助教。
  computerTeacher(5, '计算机助教'),

  /// 英语助教。
  englishTeacher(6, '英语助教'),

  /// 政治助教。
  politicsTeacher(7, '政治助教'),

  /// 招生班主任。
  admissionTeacher(10, '招生班主任'),

  /// 群管理员。
  groupAdmin(20, '群管理员'),

  /// AI 高数助教（机器人）。
  aiMathTeacher(30, 'AI高数助教'),

  /// AI 语文助教（机器人）。
  aiChineseTeacher(40, 'AI语文助教'),

  /// AI 计算机助教（机器人）。
  aiComputerTeacher(50, 'AI计算机助教'),

  /// AI 英语助教（机器人）。
  aiEnglishTeacher(60, 'AI英语助教'),

  /// 未定义角色。
  unknown(-1, '');

  const UserRole(this.rawValue, this.displayName);

  /// 后端原始取值。
  final int rawValue;

  /// 展示名称（学员/未知返回空串时调用方自行决定是否展示）。
  final String displayName;

  /// 是否学员。
  bool get isStudent => this == UserRole.student;

  /// 是否 AI 机器人角色。
  bool get isAi => const {
        UserRole.aiMathTeacher,
        UserRole.aiChineseTeacher,
        UserRole.aiComputerTeacher,
        UserRole.aiEnglishTeacher,
      }.contains(this);

  /// 是否允许登录 PC 客户端：仅限真人教职/管理角色，学员、AI 机器人与未知角色一律拒绝。
  bool get canUseDesktop => !(isStudent || isAi || this == UserRole.unknown);

  /// 由后端数值解析，无法识别时返回 [unknown]。
  static UserRole fromRaw(Object? raw) {
    final value = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    if (value == null) return UserRole.unknown;
    for (final role in UserRole.values) {
      if (role.rawValue == value) return role;
    }
    return UserRole.unknown;
  }
}
