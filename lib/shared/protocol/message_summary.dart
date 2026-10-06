import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';

import 'custom_message.dart';

/// 将 [V2TimMessage] 转为会话预览、系统通知与 AI 上下文用的单行摘要。
///
/// 与小程序 / App 展示语义对齐：自定义消息走 [CustomMessageProtocol.parse]，
/// 信令类消息（如正在输入）返回空串。
abstract final class MessageSummary {
  /// 解析消息摘要；无法识别时返回兜底文案。
  static String of(V2TimMessage? message) {
    if (message == null) return '';
    switch (message.elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return _trim(message.textElem?.text);
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return '[图片]';
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return '[语音]';
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return '[视频]';
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        final name = _trim(message.fileElem?.fileName);
        return name.isEmpty ? '[文件]' : '[文件] $name';
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        return '[位置]';
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return '[表情]';
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        return '[聊天记录]';
      case MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS:
        return '[群提示]';
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return _customSummary(message);
      default:
        return '[消息]';
    }
  }

  static String _customSummary(V2TimMessage message) {
    final custom = message.customElem;
    final protocol = CustomMessageProtocol.parse(custom?.data, extension: custom?.extension);
    if (protocol.isSignaling) return '';
    final summary = protocol.summary.trim();
    if (summary.isNotEmpty) return summary;
    if (protocol is UnknownCustomMessage) {
      final fallback = protocol.compatibleText.trim();
      if (fallback.isNotEmpty) return fallback;
    }
    return '[自定义消息]';
  }

  static String _trim(String? value) => (value ?? '').replaceAll('\n', ' ').trim();
}
