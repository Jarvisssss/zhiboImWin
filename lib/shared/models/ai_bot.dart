import 'package:equatable/equatable.dart';

/// AI Bot 使用场景。
enum AiBotScene {
  /// 学科助教（面向学员答疑）。
  tutor,

  /// 班主任回复助手（面向教师生成回复草稿），见 docs/backend-requirements.md B5。
  replyAssistant;

  /// 由后端 `scene` 字段解析，缺省为 [tutor]。
  static AiBotScene parse(Object? raw) => '${raw ?? ''}' == 'reply_assistant' ? replyAssistant : tutor;
}

/// 扣子 Bot 配置，对应 `GET /im/app/login/lstAiTch` 的单条数据。
class AiBot extends Equatable {
  /// 创建 Bot 配置。
  const AiBot({
    required this.botId,
    required this.name,
    this.avatarUrl = '',
    this.scene = AiBotScene.tutor,
  });

  /// 扣子 Bot ID。
  final String botId;

  /// 展示名称，如「班主任回复助手」「语文助教-语文猩」。
  final String name;

  /// 头像。
  final String avatarUrl;

  /// 使用场景。
  final AiBotScene scene;

  /// 是否为班主任回复助手：`scene=reply_assistant`，或名称含「回复助手」。
  bool get isReplyAssistant => scene == AiBotScene.replyAssistant || name.contains('回复助手');

  /// 从后端 JSON 解析，缺少 botId 时返回 `null`。
  static AiBot? tryParse(Object? json) {
    if (json is! Map) return null;
    final botId = '${json['botId'] ?? ''}';
    if (botId.isEmpty) return null;
    return AiBot(
      botId: botId,
      name: '${json['name'] ?? ''}',
      avatarUrl: '${json['avatarUrl'] ?? ''}',
      scene: AiBotScene.parse(json['scene']),
    );
  }

  @override
  List<Object?> get props => [botId, name, avatarUrl, scene];
}
