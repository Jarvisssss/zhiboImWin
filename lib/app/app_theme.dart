import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

/// 智博品牌主色（与 App 聊天页一致）。
const Color kBrandPrimary = Color(0xFFCC00CC);

/// 应用 Material 主题。
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kBrandPrimary, brightness: Brightness.light);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF5F6F8),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Color(0xFFF8F9FB),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

/// UIKit IM 主题（宽屏布局背景与气泡色）。
TUITheme buildTuiTheme(ColorScheme scheme) {
  return TUITheme(
    primaryColor: kBrandPrimary,
    lightPrimaryColor: kBrandPrimary,
    wideBackgroundColor: const Color(0xFFF5F6F8),
    chatHeaderBgColor: const Color(0xFFF8F9FB),
    chatMessageItemFromSelfBgColor: kBrandPrimary.withValues(alpha: 0.12),
    chatMessageItemFromOthersBgColor: Colors.white,
  );
}
