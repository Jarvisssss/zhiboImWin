import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_config.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

import '../utils/app_logger.dart';
import 'im_gateway.dart';

/// 基于腾讯云 IM Flutter SDK + UIKit 分支的网关实现（macOS / Windows 均走同一套代码，原生库由 SDK 插件提供）。
///
/// 说明：`TIMUIKitCore.init` 内部会调用 `initSDK`，因此这里**不再**单独调用 `initSDK`
///（App 端的 `ChatService` 重复调用了两次，PC 端去掉冗余调用）。
class TimImGateway implements ImGateway {
  /// 创建网关。
  ///
  /// [theme] 为 UIKit 主题（品牌色等）；[onNotice] 接收 UIKit 抛出的提示文案（如磁盘空间不足、视频异常）。
  TimImGateway({this.theme, this.onNotice});

  /// UIKit 主题。
  final TUITheme? theme;

  /// UIKit 的 INFO 级提示，交给 UI 层以 SnackBar 等方式展示。
  final void Function(String message)? onNotice;

  final AppLogger _log = AppLogger('TimImGateway');

  CoreServicesImpl get _core => TIMUIKitCore.getInstance();

  @override
  Future<bool> init({required int sdkAppId, required ImGatewayListener listener}) async {
    final ok = await _core.init(
      sdkAppID: sdkAppId,
      loglevel: kReleaseMode ? LogLevelEnum.V2TIM_LOG_WARN : LogLevelEnum.V2TIM_LOG_INFO,
      listener: V2TimSDKListener(
        onConnecting: listener.onConnecting,
        onConnectSuccess: listener.onConnectSuccess,
        onConnectFailed: listener.onConnectFailed,
        onKickedOffline: listener.onKickedOffline,
        onUserSigExpired: listener.onUserSigExpired,
      ),
      onTUIKitCallbackListener: _onUiKitCallback,
      // 桌面端固定走宽屏布局，不依赖窗口宽度推断。
      platform: DeviceType.Desktop,
      config: const TIMUIKitConfig(
        defaultAvatarBorderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    );
    final theme = this.theme;
    if (theme != null) _core.setTheme(theme: theme);
    return ok == true;
  }

  @override
  Future<void> unInit() async {
    await TencentImSDKPlugin.v2TIMManager.unInitSDK();
  }

  @override
  Future<ImCallResult> login({required String userId, required String userSig}) async {
    final result = await _core.login(userID: userId, userSig: userSig);
    return ImCallResult(result.code, result.desc);
  }

  @override
  Future<ImCallResult> logout() async {
    final result = await _core.logout();
    return ImCallResult(result.code, result.desc);
  }

  void _onUiKitCallback(TIMCallback callback) {
    switch (callback.type) {
      case TIMCallbackType.INFO:
        final text = callback.infoRecommendText;
        if (text != null && text.isNotEmpty) onNotice?.call(text);
      case TIMCallbackType.API_ERROR:
        _log.warn('UIKit API 错误 code=${callback.errorCode}');
      case TIMCallbackType.FLUTTER_ERROR:
        _log.warn('UIKit Flutter 错误', callback.catchError);
      case null:
        break;
    }
  }
}
