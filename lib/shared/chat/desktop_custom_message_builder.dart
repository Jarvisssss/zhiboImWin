import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';

import '../protocol/custom_message.dart';

/// 小程序独有自定义消息的桌面渲染；UIKit 已内置 `rich_media_message` / `large_file_message`。
class DesktopCustomMessageBuilder {
  /// 供 [MessageItemBuilder.customMessageItemBuilder] 使用；返回 `null` 时走 UIKit 默认气泡。
  static Widget? build(V2TimMessage message, {required bool isFromSelf}) {
    final custom = message.customElem;
    final protocol = CustomMessageProtocol.parse(custom?.data, extension: custom?.extension);

    if (protocol is RichMediaMessage || protocol is LargeFileMessage) {
      return null;
    }
    if (protocol.isSignaling) {
      return const SizedBox.shrink();
    }

    final text = _displayText(protocol);
    if (text.isEmpty) return null;

    final bg = isFromSelf ? const Color(0x1FCC00CC) : Colors.white;
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
          bottomLeft: Radius.circular(isFromSelf ? 10 : 2),
          bottomRight: Radius.circular(isFromSelf ? 2 : 10),
        ),
      ),
      child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
    );
  }

  static String _displayText(CustomMessageProtocol protocol) {
    return switch (protocol) {
      OrderMessage(:final title, :final price, :final description) =>
        [title, if (price.isNotEmpty) '￥$price', description].where((e) => e.isNotEmpty).join('\n'),
      EvaluationMessage(:final score, :final comment) => comment.isEmpty ? '服务评价 $score 分' : '服务评价 $score 分\n$comment',
      TextLinkMessage(:final text) => text,
      GroupCreateMessage(:final text) => text.isEmpty ? '群聊已创建' : text,
      ConsultationMessage(:final text) => text.isEmpty ? '咨询消息' : text,
      CallSignalingMessage() => '音视频通话（请在手机端接听）',
      UnknownCustomMessage(:final compatibleText) => compatibleText,
      _ => protocol.summary,
    };
  }
}
