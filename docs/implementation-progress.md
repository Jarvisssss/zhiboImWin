# 猩子Talk PC · 实施进度（相对原方案）

> 原方案正文不在本仓库修改；本文仅记录 **zhiboImWin 工程** 的实际进度，便于与另一窗口的方案文档对照。

## 阶段概览

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| 0 | 工程搭建、依赖、可编译入口 | **进行中**（入口/登录/桌面壳已齐，待本机 `pub get` + `analyze` 验证） |
| 1 | 登录联调（兜底链路 + PC 接口切换） | 未开始 |
| 2 | IM 三端互通、自定义消息、文件 COS | 部分（协议解析与 LargeFile 配置已写，待联调） |
| 3 | 桌面能力（窗口/托盘/通知/角标） | 未开始（仅 `window_manager` 最小初始化） |
| 4 | AI 班主任回复助手（扣子 SSE） | **部分**（`CozeTokenManager` / `CozeSSEClient` / `CozeApiService` 已平移，待 UI 面板联调） |
| 5 | 打包（MSIX/安装包）、版本检查 | 未开始 |

## 已完成

- [x] `docs/backend-requirements.md`（需转后端确认）
- [x] FVM Flutter 3.35.0 工程（Windows + macOS）
- [x] 配置 / 网络 / 双登录链路 / `AuthCubit`
- [x] IM 网关、续期与被踢、`ImEventHub`
- [x] `custom_message.dart` 三端协议解析
- [x] `message_summary.dart`（会话预览 / 通知 / AI 上下文摘要）
- [x] 应用入口：`bootstrap` → `ZhiboTalkApp` → 登录 / 桌面壳
- [x] Windows VM：x64 Dart/Flutter 以适配 IM 原生库（见 `.local-logs/`）
- [x] 远程仓库：`https://github.com/Jarvisssss/zhiboImWin.git`（`main` 已推送初始骨架）
- [x] Coze 客户端：`lib/shared/services/coze/*`（Token + SSE + 取消对话 API）

## 与原方案差异（已采纳）

- **70014**：SDKAppID 与签发不一致，**不**走 userSig 自动续期（见 `im_error_codes.dart`）。
- **IM 控制台**：须「三平台登录」，否则 PC 与 App 互踢（见 `backend-requirements.md` B4）。

## 当前卡点

- 本机 / VM `pub get` 可能较慢（国内镜像）；未跑通 `flutter analyze` / `flutter run` 前视为「未编译验证」。
- 正式登录依赖构建期注入 `ZB_IM_TOKEN_KEY`（`config/env.example.json` → 本地 `config/env.local.json`，勿入库）。

## 下一步建议

1. 在 macOS 或 Windows VM 执行：`fvm flutter pub get` → `fvm flutter analyze` → `fvm flutter run -d windows/macos`。
2. 用 `ZB_AUTH_MODE=app` + 有效 `ZB_IM_TOKEN_KEY` 走兜底链路联调。
3. 后端 B1 就绪后切 `ZB_AUTH_MODE=pc`。
4. 按阶段 3–5 补托盘、通知、AI 面板与打包。
