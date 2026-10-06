# zhibo_im_win

猩子Talk **PC 客户端**（Windows / macOS）：与微信小程序 `zhiboIm`、Flutter App `study_app` 共用腾讯云 IM，并接入扣子 SSE 辅助班主任回复。

## 技术栈

- Flutter **3.35.0**（FVM，见 `.fvmrc`）
- `tencent_cloud_chat_sdk: 8.8.7357`
- `tencent_cloud_chat_uikit`：本地路径 `../study_app/chat-uikit-flutter`
- 桌面：`window_manager`、`tray_manager`（后续阶段启用）

## 本地开发

1. 安装 FVM 并 `fvm use 3.35.0`（或直接使用 `~/fvm/versions/3.35.0/bin/flutter`）。
2. 复制 `config/env.example.json` 为 `config/env.local.json`，填入 `ZB_IM_TOKEN_KEY` 等（**勿提交**）。
3. 依赖：

```bash
fvm flutter pub get
```

4. 运行（需有效联调账号与密钥）：

```bash
fvm flutter run -d macos \
  --dart-define-from-file=config/env.local.json
```

Windows 构建请在 **x64 Dart/Flutter** 环境下进行（Parallels ARM64 VM 见 `scripts/windows/`）。

## 文档

- 后端对齐清单：`docs/backend-requirements.md`
- 实施进度：`docs/implementation-progress.md`

## 仓库

https://github.com/Jarvisssss/zhiboImWin.git
