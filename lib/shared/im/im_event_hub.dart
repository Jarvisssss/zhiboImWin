import 'dart:async';

import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

import '../utils/app_logger.dart';

/// IM 全局事件中心：新消息与未读总数。
///
/// UIKit 内部也会注册自己的监听器，SDK 支持多个监听器并存，因此这里的监听只用于「应用层」需求：
/// 系统通知、托盘/Dock 角标、AI 辅助回答触发。
class ImEventHub {
  /// 创建事件中心。
  ImEventHub();

  final AppLogger _log = AppLogger('ImEventHub');
  final StreamController<V2TimMessage> _newMessages = StreamController<V2TimMessage>.broadcast();
  final StreamController<int> _totalUnread = StreamController<int>.broadcast();

  V2TimAdvancedMsgListener? _msgListener;
  V2TimConversationListener? _conversationListener;
  int _lastUnread = 0;

  /// 收到的新消息（包含自己在其他端发送的同步消息，调用方需自行判断 `isSelf`）。
  Stream<V2TimMessage> get newMessages => _newMessages.stream;

  /// 未读消息总数变化。
  Stream<int> get totalUnread => _totalUnread.stream;

  /// 最近一次已知的未读总数。
  int get lastUnread => _lastUnread;

  /// 注册 SDK 监听（IM 登录成功后调用，可重复调用）。
  Future<void> attach() async {
    await detach();
    final manager = TencentImSDKPlugin.v2TIMManager;

    final messageListener = V2TimAdvancedMsgListener(
      onRecvNewMessage: (message) {
        if (!_newMessages.isClosed) _newMessages.add(message);
      },
    );
    final conversationListener = V2TimConversationListener(
      onTotalUnreadMessageCountChanged: _emitUnread,
    );
    _msgListener = messageListener;
    _conversationListener = conversationListener;
    await manager.getMessageManager().addAdvancedMsgListener(listener: messageListener);
    await manager.getConversationManager().addConversationListener(listener: conversationListener);
    await refreshTotalUnread();
  }

  /// 主动拉取一次未读总数。
  Future<int> refreshTotalUnread() async {
    final result = await TencentImSDKPlugin.v2TIMManager.getConversationManager().getTotalUnreadMessageCount();
    if (result.code == 0 && result.data != null) {
      _emitUnread(result.data!);
    } else {
      _log.warn('获取未读总数失败 code=${result.code}');
    }
    return _lastUnread;
  }

  /// 取消 SDK 监听（退出登录时调用）。
  Future<void> detach() async {
    final manager = TencentImSDKPlugin.v2TIMManager;
    final messageListener = _msgListener;
    final conversationListener = _conversationListener;
    _msgListener = null;
    _conversationListener = null;
    if (messageListener != null) {
      await manager.getMessageManager().removeAdvancedMsgListener(listener: messageListener);
    }
    if (conversationListener != null) {
      await manager.getConversationManager().removeConversationListener(listener: conversationListener);
    }
    _emitUnread(0);
  }

  /// 释放流。
  Future<void> dispose() async {
    await detach();
    await _newMessages.close();
    await _totalUnread.close();
  }

  void _emitUnread(int count) {
    if (count == _lastUnread) return;
    _lastUnread = count;
    if (!_totalUnread.isClosed) _totalUnread.add(count);
  }
}
