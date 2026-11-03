# 猩子Talk PC · 实施进度（相对原方案）

> 原方案正文不在本仓库修改；本文仅记录 **zhiboImWin 工程** 的实际进度，便于与另一窗口的方案文档对照。

## 阶段概览

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| 0 | 工程搭建、依赖、可编译入口 | **基本完成**（macOS / Windows VM Release 已可构建运行；登录全流程待联调） |
| 1 | 登录联调（兜底链路 + PC 接口切换） | 进行中 |
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
- [x] Windows VM：x64 Dart/Flutter（见 `scripts/windows/`）
- [x] Coze 客户端：`lib/shared/services/coze/*`
- [x] 桌面壳：`ConvType` 导入与 UIKit 废弃 API 清理；`fvm flutter analyze` 0 issues
- [x] macOS App Sandbox 出站网络：`com.apple.security.network.client`
- [x] `dio` 5.11+：`DioExceptionType.transformTimeout` 映射
- [x] Parallels Windows 构建脚本：`scripts/windows/sync_and_build.ps1`（操作见 `README.md`）

## 与原方案差异（已采纳）

- **70014**：SDKAppID 与签发不一致，**不**走 userSig 自动续期（见 `im_error_codes.dart`）。
- **IM 控制台**：须「三平台登录」，否则 PC 与 App 互踢（见 `backend-requirements.md` B4）。

## 当前卡点

- 登录与自定义消息渲染需本机短信验证码联调（`config/env.local.json` 本地注入，勿入库）。
- Windows 在 VM 本地盘 `C:\dev\zhiboImWin` 构建，改代码后需重跑 `sync_and_build.ps1`。

## 下一步建议

1. macOS / Windows 走通兜底登录（`ZB_AUTH_MODE=app`），验证自定义消息渲染。
2. 联调 Coze SSE + AI 面板 UI。
3. 后端 B1 就绪后切 `ZB_AUTH_MODE=pc`。
4. 阶段 3–5：托盘、通知、MSIX 打包。
