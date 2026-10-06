import 'dart:convert';

/// 三端（小程序 / App / PC）共用的自定义消息协议（`TIMCustomElem.data` 中的 `businessID`）。
///
/// 这里只做「解析 + 摘要」，不负责渲染：`rich_media_message` 与 `large_file_message` 的气泡由 UIKit 分支渲染，
/// 其余小程序独有的消息由 `DesktopCustomMessageBuilder` 渲染。任何协议变更必须三端同步（见 README「多端互通约束」）。
sealed class CustomMessageProtocol {
  /// 基类构造。
  const CustomMessageProtocol();

  /// 协议标识。
  String get businessId;

  /// 用于会话预览、系统通知与 AI 上下文的简短文案（可能为空串，表示无需展示）。
  String get summary;

  /// 是否为「不应出现在聊天列表」的信令消息（如对方正在输入）。
  bool get isSignaling => false;

  /// 解析 `customElem.data`（以及小程序 `group_create` / `consultion` 使用的 `extension`）。
  ///
  /// 永不抛出异常：无法识别时返回 [UnknownCustomMessage]。
  static CustomMessageProtocol parse(String? data, {String? extension}) {
    final raw = data?.trim() ?? '';
    if (raw.isEmpty) return const UnknownCustomMessage();

    // 小程序的「建群 / 咨询」消息：data 是纯字符串标识，真实内容放在 extension。
    if (raw == GroupCreateMessage.marker) return GroupCreateMessage(text: _extensionText(extension));
    if (raw == ConsultationMessage.marker) return ConsultationMessage(text: _extensionText(extension));

    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return UnknownCustomMessage(raw: raw);
    }
    if (json is! Map) return UnknownCustomMessage(raw: raw);

    final compatibleText = _string(json['compatibleText']);
    // businessID 可能是字符串，也可能是数字（音视频信令为数字 1）。
    final id = '${json['businessID'] ?? ''}';
    switch (id) {
      case RichMediaMessage.id:
        return RichMediaMessage.fromJson(json);
      case LargeFileMessage.id:
        return LargeFileMessage.fromJson(json);
      case TypingMessage.id:
        return TypingMessage.fromJson(json);
      case OrderMessage.id:
        return OrderMessage.fromJson(json);
      case EvaluationMessage.id:
        return EvaluationMessage.fromJson(json);
      case TextLinkMessage.id:
        return TextLinkMessage(text: _string(json['text']));
      case CallSignalingMessage.id:
        return const CallSignalingMessage();
      default:
        // 旧版「正在输入」没有 businessID，只有 userAction=14 / actionParam=EIMAMSG_InputStatus_*。
        if (json['userAction'] == 14 || _string(json['actionParam']).startsWith('EIMAMSG_InputStatus')) {
          return TypingMessage.fromJson(json);
        }
        return UnknownCustomMessage(businessId: id, compatibleText: compatibleText, raw: raw);
    }
  }
}

/// 图文 / 图文视频消息。v1 仅 `images`，v2 为统一的 `media` 数组（图片+视频混排）。
class RichMediaMessage extends CustomMessageProtocol {
  /// 创建消息。
  const RichMediaMessage({required this.version, required this.caption, required this.media, this.compatibleText = ''});

  /// 协议标识。
  static const String id = 'rich_media_message';

  /// 协议版本（1 / 2）。
  final int version;

  /// 文字说明。
  final String caption;

  /// 媒体列表（顺序即展示顺序）。
  final List<RichMediaItem> media;

  /// 旧版本客户端展示的兜底文案。
  final String compatibleText;

  /// 从 JSON 解析，兼容 v1 / v2。
  factory RichMediaMessage.fromJson(Map<Object?, Object?> json) {
    final version = _int(json['version']) ?? 1;
    final items = <RichMediaItem>[];
    final media = json['media'];
    final images = json['images'];
    if (version >= 2 && media is List) {
      for (final item in media.whereType<Map<Object?, Object?>>()) {
        items.add(RichMediaItem.fromJson(item));
      }
    } else if (images is List) {
      for (final item in images.whereType<Map<Object?, Object?>>()) {
        items.add(RichMediaItem.fromJson({...item, 'type': 'image'}));
      }
    }
    return RichMediaMessage(
      version: version,
      caption: _string(json['caption']),
      media: items,
      compatibleText: _string(json['compatibleText']),
    );
  }

  @override
  String get businessId => id;

  /// 是否包含视频。
  bool get hasVideo => media.any((item) => item.isVideo);

  /// 是否包含图片。
  bool get hasImage => media.any((item) => !item.isVideo);

  @override
  String get summary {
    final label = hasVideo ? (hasImage ? '[图文视频消息]' : '[视频消息]') : '[图文消息]';
    final text = caption.trim();
    return text.isEmpty ? label : '$label $text';
  }
}

/// 图文消息中的单个媒体项。
class RichMediaItem {
  /// 创建媒体项。
  const RichMediaItem({
    required this.isVideo,
    this.url = '',
    this.fileId = '',
    this.thumbnailUrl = '',
    this.width = 0,
    this.height = 0,
    this.duration = 0,
  });

  /// 是否视频。
  final bool isVideo;

  /// 直链地址（图片通常有；视频走 fileId 时为空）。
  final String url;

  /// 文件 ID。**优先于 url**：播放时需通过 `queryByFileId` 解析 CDN 地址。
  final String fileId;

  /// 视频缩略图地址。
  final String thumbnailUrl;

  /// 宽（像素）。
  final int width;

  /// 高（像素）。
  final int height;

  /// 视频时长（秒）。
  final int duration;

  /// 是否需要通过 fileId 解析地址。
  bool get needsResolve => fileId.isNotEmpty;

  /// 从 JSON 解析（宽松）。
  factory RichMediaItem.fromJson(Map<Object?, Object?> json) {
    return RichMediaItem(
      isVideo: _string(json['type']) == 'video',
      url: _string(json['url']),
      fileId: _string(json['fileId']),
      thumbnailUrl: _string(json['thumbnailUrl']),
      width: _int(json['width']) ?? 0,
      height: _int(json['height']) ?? 0,
      duration: _int(json['duration']) ?? 0,
    );
  }
}

/// 大文件消息（视频 / 文件走业务 COS 直传，小程序 v1.1 / App v1.0）。
class LargeFileMessage extends CustomMessageProtocol {
  /// 创建消息。
  const LargeFileMessage({
    required this.version,
    required this.fileName,
    required this.fileSize,
    required this.isVideo,
    this.fileId = '',
    this.url = '',
    this.thumbnailUrl = '',
    this.duration = 0,
    this.compatibleText = '',
  });

  /// 协议标识。
  static const String id = 'large_file_message';

  /// 协议版本字符串（"1.0" / "1.1"）。
  final String version;

  /// 文件名。
  final String fileName;

  /// 文件大小（字节）。
  final int fileSize;

  /// 是否视频（`messageKind`/`fileType` 为 video）。
  final bool isVideo;

  /// 文件 ID（优先使用）。
  final String fileId;

  /// 历史直链（旧消息兼容）。
  final String url;

  /// 视频缩略图。
  final String thumbnailUrl;

  /// 视频时长（秒）。
  final int duration;

  /// 旧版本客户端展示的兜底文案。
  final String compatibleText;

  /// 从 JSON 解析。
  factory LargeFileMessage.fromJson(Map<Object?, Object?> json) {
    final infoRaw = json['fileInfo'];
    final info = infoRaw is Map<Object?, Object?> ? infoRaw : const <Object?, Object?>{};
    final kind = _string(info['messageKind']).isNotEmpty ? _string(info['messageKind']) : _string(info['fileType']);
    return LargeFileMessage(
      version: _string(json['version']),
      fileName: _string(info['fileName']),
      fileSize: _int(info['fileSize']) ?? 0,
      isVideo: kind == 'video',
      fileId: _string(info['fileId']),
      url: _string(info['url']),
      thumbnailUrl: _string(info['thumbnailUrl']),
      duration: _int(info['duration']) ?? 0,
      compatibleText: _string(json['compatibleText']),
    );
  }

  @override
  String get businessId => id;

  @override
  String get summary => isVideo ? '[视频]' : (fileName.isEmpty ? '[文件]' : '[文件] $fileName');
}

/// 对方正在输入（信令消息，不展示）。
class TypingMessage extends CustomMessageProtocol {
  /// 创建消息。
  const TypingMessage({required this.isTyping});

  /// 协议标识。
  static const String id = 'user_typing_status';

  /// 是否正在输入（`typingStatus==1` 或 `actionParam` 以 `_Ing` 结尾）。
  final bool isTyping;

  /// 从 JSON 解析。
  factory TypingMessage.fromJson(Map<Object?, Object?> json) {
    final action = _string(json['actionParam']);
    final typing = _int(json['typingStatus']) == 1 || action.endsWith('_Ing');
    return TypingMessage(isTyping: typing);
  }

  @override
  String get businessId => id;

  @override
  bool get isSignaling => true;

  @override
  String get summary => '';
}

/// 订单消息（小程序发送）。
class OrderMessage extends CustomMessageProtocol {
  /// 创建消息。
  const OrderMessage({required this.title, this.imageUrl = '', this.link = '', this.price = '', this.description = ''});

  /// 协议标识。
  static const String id = 'order';

  /// 标题。
  final String title;

  /// 商品图。
  final String imageUrl;

  /// 跳转链接。
  final String link;

  /// 价格。
  final String price;

  /// 描述。
  final String description;

  /// 从 JSON 解析。
  factory OrderMessage.fromJson(Map<Object?, Object?> json) {
    return OrderMessage(
      title: _string(json['title']),
      imageUrl: _string(json['imageUrl']),
      link: _string(json['link']),
      price: _string(json['price']),
      description: _string(json['description']),
    );
  }

  @override
  String get businessId => id;

  @override
  String get summary => title.isEmpty ? '[订单]' : '[订单] $title';
}

/// 服务评价消息（小程序发送）。
class EvaluationMessage extends CustomMessageProtocol {
  /// 创建消息。
  const EvaluationMessage({required this.score, this.comment = ''});

  /// 协议标识。
  static const String id = 'evaluation';

  /// 评分（1-5）。
  final int score;

  /// 评价内容。
  final String comment;

  /// 从 JSON 解析。
  factory EvaluationMessage.fromJson(Map<Object?, Object?> json) {
    return EvaluationMessage(score: _int(json['score']) ?? 0, comment: _string(json['comment']));
  }

  @override
  String get businessId => id;

  @override
  String get summary => comment.isEmpty ? '[服务评价] $score 分' : '[服务评价] $score 分：$comment';
}

/// 带链接的文本（小程序发送）。
class TextLinkMessage extends CustomMessageProtocol {
  /// 创建消息。
  const TextLinkMessage({required this.text});

  /// 协议标识。
  static const String id = 'text_link';

  /// 文本内容（可能包含 URL）。
  final String text;

  @override
  String get businessId => id;

  @override
  String get summary => text;
}

/// 建群提示（`data == 'group_create'`，文案在 `extension`）。
class GroupCreateMessage extends CustomMessageProtocol {
  /// 创建消息。
  const GroupCreateMessage({this.text = ''});

  /// `data` 字段的纯字符串标识。
  static const String marker = 'group_create';

  /// 提示文案。
  final String text;

  @override
  String get businessId => marker;

  @override
  String get summary => text.isEmpty ? '[群聊已创建]' : text;
}

/// 咨询消息（`data == 'consultion'`，扩展内容在 `extension`，拼写沿用后端既有写法）。
class ConsultationMessage extends CustomMessageProtocol {
  /// 创建消息。
  const ConsultationMessage({this.text = ''});

  /// `data` 字段的纯字符串标识（后端既有拼写）。
  static const String marker = 'consultion';

  /// 提示文案。
  final String text;

  @override
  String get businessId => marker;

  @override
  String get summary => text.isEmpty ? '[咨询]' : '[咨询] $text';
}

/// 音视频通话信令（`businessID == 1`）。PC 一期不支持通话，只展示固定文案。
class CallSignalingMessage extends CustomMessageProtocol {
  /// 创建消息。
  const CallSignalingMessage();

  /// 协议标识（数字 1 的字符串形式）。
  static const String id = '1';

  @override
  String get businessId => id;

  @override
  String get summary => '[音视频通话]';
}

/// 无法识别的自定义消息：优先展示发送方提供的 `compatibleText`。
class UnknownCustomMessage extends CustomMessageProtocol {
  /// 创建消息。
  const UnknownCustomMessage({this.businessId = '', this.compatibleText = '', this.raw = ''});

  @override
  final String businessId;

  /// 发送方提供的兜底文案。
  final String compatibleText;

  /// 原始数据（仅用于排查，**不要写入日志**）。
  final String raw;

  @override
  String get summary => compatibleText.isEmpty ? '[暂不支持的消息，请在手机端查看]' : compatibleText;
}

String _string(Object? value) => value == null ? '' : '$value';

int? _int(Object? value) => value is num ? value.toInt() : int.tryParse('${value ?? ''}');

String _extensionText(String? extension) {
  final raw = extension?.trim() ?? '';
  if (raw.isEmpty) return '';
  // 小程序的 extension 可能是 JSON（含 text/title 字段），也可能直接是文案。
  try {
    final json = jsonDecode(raw);
    if (json is Map) {
      for (final key in const ['text', 'title', 'content', 'message']) {
        final value = _string(json[key]);
        if (value.isNotEmpty) return value;
      }
      return '';
    }
  } on FormatException {
    // 不是 JSON，按纯文本处理。
  }
  return raw;
}
