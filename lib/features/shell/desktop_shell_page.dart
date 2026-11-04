import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_chat_controller.dart';

import '../../app/dependency_container.dart';
import '../../features/auth/cubit/auth_cubit.dart';
import '../../shared/chat/desktop_custom_message_builder.dart';

/// 桌面主界面：左侧会话列表 + 右侧聊天区。
class DesktopShellPage extends StatefulWidget {
  /// 创建主界面。
  const DesktopShellPage({required this.container, super.key});

  /// 依赖容器。
  final DependencyContainer container;

  @override
  State<DesktopShellPage> createState() => _DesktopShellPageState();
}

class _DesktopShellPageState extends State<DesktopShellPage> {
  V2TimConversation? _selected;
  final TIMUIKitChatController _chatController = TIMUIKitChatController();

  Future<void> _logout() async {
    await context.read<AuthCubit>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthCubit>().state.session;
    final nick = session?.nick.isNotEmpty == true ? session!.nick : (session?.imUserId ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('猩子Talk'),
        actions: [
          if (nick.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: Text(nick, style: const TextStyle(fontSize: 14))),
            ),
          IconButton(tooltip: '退出登录', onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 320,
            child: ColoredBox(
              color: Colors.white,
              child: TIMUIKitConversation(
                onTapItem: (conv) => setState(() => _selected = conv),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _buildChatPane()),
        ],
      ),
    );
  }

  Widget _buildChatPane() {
    final conv = _selected;
    if (conv == null) {
      return const Center(child: Text('选择左侧会话开始聊天'));
    }

    final convType = conv.type == 1 ? ConvType.c2c : ConvType.group;
    // 勿传 conv.conversationID（形如 c2c_xxx）：拉历史需 userID/groupID。
    // ValueKey：桌面分栏复用同一 TIMUIKitChat 时，UIKit 仅监听 conversationID 变化才会重置模型；用 Key 强制按会话重建（等同 App 每次 push ChatPage）。
    return TIMUIKitChat(
      key: ValueKey(conv.conversationID),
      controller: _chatController,
      conversation: conv,
      conversationType: convType,
      conversationShowName: conv.showName,
      config: const TIMUIKitChatConfig(isShowReadingStatus: true),
      messageItemBuilder: MessageItemBuilder(
        customMessageItemBuilder: (message, isShowJump, clearJump) {
          return DesktopCustomMessageBuilder.build(message, isFromSelf: message.isSelf ?? false);
        },
      ),
    );
  }
}
