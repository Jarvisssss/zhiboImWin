# zhibo_im_win

猩子Talk **PC 客户端**（Windows / macOS）：与微信小程序 `zhiboIm`、Flutter App `study_app` 共用腾讯云 IM，并接入扣子 SSE 辅助班主任回复。

## 技术栈

- Flutter **3.35.0**（FVM，见 `.fvmrc`）
- `tencent_cloud_chat_sdk: 8.8.7357`
- `tencent_cloud_chat_uikit`：git submodule `third_party/chat-uikit-flutter`（[xchat-uikit-flutter](https://github.com/Jarvisssss/xchat-uikit-flutter)）；PC 独有业务逻辑在本仓库 `lib/`
- 桌面：`window_manager`、`tray_manager`（后续阶段启用）

## 本地开发

1. 安装 FVM 并 `fvm use 3.35.0`（或直接使用 `~/fvm/versions/3.35.0/bin/flutter`）。
2. 初始化 submodule（首次克隆或更新 UIKit 后执行）：

```bash
git submodule update --init --recursive
```

3. 复制 `config/env.example.json` 为 `config/env.local.json`（默认与猩子Talk 小程序一致：`ZB_AUTH_MODE=pc`、`ZB_AUTH_HEADER=accessToken`，**无需** `ZB_IM_TOKEN_KEY`；**勿提交**）。
4. 依赖：

```bash
fvm flutter pub get
```

5. 运行（需有效联调账号与密钥）：

```bash
fvm flutter run -d macos \
  --dart-define-from-file=config/env.local.json
```

或：

```bash
./scripts/macos/run_debug.sh
```

**Android Studio（macOS 主开发）**

1. 用 Android Studio 打开本仓库根目录（不是 `macos/` 子目录）。
2. **Settings → Languages & Frameworks → Flutter**：Flutter SDK 指向 FVM `3.35.0`（如 `~/fvm/versions/3.35.0`）。
3. 确认已存在 `config/env.local.json`（从 `config/env.example.json` 复制）。
4. 顶部设备选择 **macOS (desktop)**，Run/Debug `lib/main.dart`。
5. 若使用 VS Code 系配置，可选用 `.vscode/launch.json` 里的 **zhibo_im_win (macOS Debug)**。
6. 首次或升级 Xcode 后若 CocoaPods 报 `MACOSX_DEPLOYMENT_TARGET`，在本机执行：

```bash
cd macos && pod install && cd ..
```

（工程已统一最低 **macOS 12.0**。）

7. 控制台关注联调日志（不含 userSig）：
   - `[PcLoginAuthRepository]` PC 登录成功 → `imUserId` / `sdkAppId`
   - `[ImSessionManager]` IM 已连接 或 `IM 登录失败 code=…`
   - `[TimImGateway]` UIKit API 错误（含 70107 说明）

### Windows 11（Parallels）— 方式 B

在 VM 本地盘 `C:\dev\zhiboImWin` 构建（勿在 `\\Mac\Home\...` 共享路径下 build）。VM 名以 `prlctl list -a` 为准，一般为 `Windows 11`。

**Mac：同步 + Release 构建**

```bash
prlctl list -a
prlctl resume "Windows 11"   # 仅 paused 时需要

prlctl exec "Windows 11" --current-user powershell -NoProfile -ExecutionPolicy Bypass \
  -File '\\Mac\Home\WebstormProjects\zhiboImWin\scripts\windows\sync_and_build.ps1'
```

**VM：运行 Release**

```powershell
C:\dev\zhiboImWin\build\windows\x64\runner\Release\zhibo_im_win.exe
```

**VM：`pub get` 写 `.flutter-plugins-dependencies` 失败时**

```powershell
Stop-Process -Name zhibo_im_win,dart -Force -ErrorAction SilentlyContinue
Remove-Item C:\dev\zhiboImWin\.flutter-plugins-dependencies,C:\dev\zhiboImWin\.flutter-plugins -Force -ErrorAction SilentlyContinue
# 再在 Mac 重跑 sync_and_build.ps1
```

Mac 改代码后需重跑 `sync_and_build.ps1` 再测 exe。

### Windows 调试（登录接口 / 控制台日志）

Release exe 无完整 HTTP 正文；用 Debug `flutter run`，日志在 PowerShell 窗口（`MainApi` / `AuthCubit`）。完整 JSON 用 Fiddler/Charles 抓 `api-dev.zhibojiaoyu.cn`（dev 环境）。

**VM：Debug 运行**（Mac 改 `windows/CMakeLists.txt` 或 C++ 相关后，先在 Mac 重跑 `sync_and_build.ps1`）

推荐用脚本（会清理过期的 `build\windows` CMake 缓存，并在失败时打印 `cl` 错误）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\zhiboImWin\scripts\windows\run_debug.ps1
```

若仍报 `Build process failed` 且约几十秒就结束，多半是 **未同步最新 `windows/CMakeLists.txt`** 或 **旧 CMake 缓存仍含 `/utf-8`**，手动清一次再跑：

```powershell
Remove-Item -Recurse -Force C:\dev\zhiboImWin\build\windows -ErrorAction SilentlyContinue
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\zhiboImWin\scripts\windows\run_debug.ps1
```

热重载：`r` / `R` / `q`。未同步到 `C:\dev` 时先在 Mac 重跑脚本。

**Mac：对照调试**

```bash
fvm flutter run -d macos --dart-define-from-file=config/env.local.json
```

## 文档

- 后端对齐清单：`docs/backend-requirements.md`
- 实施进度：`docs/implementation-progress.md`

## 仓库

https://github.com/Jarvisssss/zhiboImWin.git
