# 猩子Talk PC 客户端 · 后端 / 运维对齐清单

> 适用读者：后端、运维（腾讯云 IM 控制台管理员）、产品。
> 配套文档：[架构说明](../README.md)、[三端互通测试矩阵](./interop-test-matrix.md)。
> 状态说明：本文列出 PC 客户端上线前**必须由后端 / 运维确认或提供**的事项。每一项都标注了「PC 端当前兜底方案」，
> 因此后端接口未就绪时 PC 开发与联调不会被阻塞，但**兜底方案不得带入正式发布**。

## 0. 事项总览

| 编号 | 事项 | 级别 | 负责方 | PC 端当前兜底 |
| --- | --- | --- | --- | --- |
| B1 | PC 专用手机验证码登录接口 | P0（上线阻塞） | 后端 | 复用 App 主 API「验证码登录」+ `getUserSig`（注意副作用，见 1.3） |
| B2 | `/im/app/login/*` 鉴权路径（`userToken` 还是 `X-Access-Token`） | P0 | 后端 | 方案 A：客户端用构建期注入的密钥生成 AES `userToken` |
| B3 | `userSig` 签发有效期与续期接口 | P0 | 后端 | 复用 `GET /im/app/login/getUserSig` |
| B4 | IM 控制台多端登录策略改为「三平台登录」 | P0 | 运维 | 无（不改则 PC 登录会把手机 App 踢下线） |
| B5 | 扣子「班主任回复助手」Bot、下发方式与配额 | P1 | 后端 / AI | 复用 `lstAiTch` 返回的学科助教 Bot + 客户端内置提示词 |
| B6 | 两个 `queryByFileId` 文件库是否一致 | P1 | 后端 | PC 只用 App 协议接口 `/im/app/login/queryByFileId` |
| B7 | PC 版本检查 / 更新接口 | P2 | 后端 | 客户端读取本地配置，不做强制更新 |
| B8 | 二期：AI 建议统一后端接口（SSE） | P2 | 后端 / AI | 一期直连扣子 |
| B9 | 密钥安全：小程序客户端硬编码的 IM `SECRETKEY` 应轮换 | P1 | 后端 / 运维 | PC 严禁内置任何签发密钥 |

## 1. B1 · PC 手机验证码登录接口

### 1.1 为什么需要

小程序登录接口 `POST /im/login/phoneAuditLogin` 依赖 `wx.login()` 得到的微信 `code`，桌面端拿不到该参数；
App 的账号体系（主 API `/account/auth/*`）与小程序不是同一套登录态。PC 端面向班主任 / 管理人员，需要一个**不依赖微信、带角色校验**的登录入口。

### 1.2 建议契约（新增，或改造 `phoneAuditLogin` 使 `code` 在 `clientType=pc` 时可省略）

发送验证码（沿用现有接口，无需改动）：

```http
POST {eipHost}/im/login/getCaptchaLogin
Content-Type: application/json;charset=UTF-8

{ "cel": "13800000000" }
```

登录：

```http
POST {eipHost}/im/login/phoneAuditLogin
Content-Type: application/json;charset=UTF-8

{
  "username": "13800000000",
  "captcha": "123456",
  "clientType": "pc",
  "deviceId": "e0a9c0f6-0d54-4b4c-9d2f-6f1b0b6a9a11",
  "deviceName": "Windows 11 / DESKTOP-ABC"
}
```

成功响应（统一信封，PC 端按 `result` 解包；字段名与小程序保持一致，**新增字段已标注**）：

```json
{
  "code": 0,
  "success": true,
  "message": "",
  "result": {
    "token": "业务 X-Access-Token",
    "userInfo": {
      "id": "10778378",
      "imUserId": "IM 账号 ID",
      "imUserSig": "后端签发的 userSig",
      "sdkAppId": 1400327457,
      "userRole": 1,
      "nick": "张老师",
      "avatar": "https://..."
    }
  }
}
```

- **新增字段**：`userInfo.id`（主业务用户 ID，方案 A 生成 `userToken` 必需）、`userInfo.sdkAppId`（避免客户端硬编码）。
- **失败**沿用 `result.failCode`：`0` 登录失败 / `1` 用户不存在或验证码错误 / `2` 微信 ID 获取失败（PC 不会出现）。
  新增 `3`：**该角色不允许在 PC 端登录**（学员）。
- **角色白名单**：仅允许非学员角色登录 PC。`userRole` 取值沿用 App `UserRole`：
  `1` 班主任、`2` 学员、`3–7` 各科助教、`10` 招生班主任、`20` 群管理员、`30/40/50/60` AI 助教。
  PC 允许 `1、3–7、10、20`；拒绝 `2` 与 AI 助教（`30–60`）与未知角色。客户端也做同样的二次校验，但**以服务端为准**。
- **验证码防刷**：同手机号 60 秒 1 次、每日上限、图形验证 / 风控（桌面端无法使用微信的订阅消息前置校验）。
- **token 有效期**：建议 ≥ 7 天，服务端过期统一返回 `status=500 且 message 含 TOKEN`（与小程序约定一致），
  PC 端据此回到登录页。
- **设备记录**：服务端记录 `deviceId / deviceName`，便于审计「谁在哪台电脑登录」。

### 1.3 PC 端当前兜底链路（仅限内部联调）

```text
POST {apiHost}/account/auth/sendCode          { phone }
POST {apiHost}/account/auth/verifyCodeLogin   { phone, verifyCode }   →  UserEntity { id, token, ... }
GET  {eipHost}/im/app/login/getUserSig        header: userToken = AES-GCM(UserEntity.id)
                                              →  { userSig, sdkAppId, imUserId, userRole }
```

> ⚠️ `verifyCodeLogin` 是 **「登录 / 注册统一接口」**：未注册的手机号会被自动创建为普通账号。
> 因此该链路**仅用于内部联调**，上线前必须切换到 1.2 的 PC 专用接口。
> PC 客户端对该链路做了保护：`getUserSig` 无结果（账号未分配班级）或 `userRole` 为学员时一律拒绝进入主界面，
> 但账号被自动创建这一副作用无法在客户端消除。

## 2. B2 · `/im/app/login/*` 鉴权路径

PC 需要调用的业务接口（均为现有 App 协议接口）：

| 用途 | 方法 | 路径 |
| --- | --- | --- |
| 获取 / 续期 userSig | GET | `/im/app/login/getUserSig` |
| 联系人（含角色名） | GET | `/im/app/login/lstUserFriends?aiTchFlag=1` |
| AI 助教 Bot 列表 | GET | `/im/app/login/lstAiTch` |
| 扣子访问令牌 | GET | `/im/app/login/getCozeAcessToken` |
| COS 预签名上传 | GET | `/im/app/login/generatePresignedUrl?fileName=` |
| fileId 解析播放地址 | GET | `/im/app/login/queryByFileId?fileId=` |
| 语音识别 STS（二期） | GET | `/im/app/login/getAsrStsToken` |

这些接口当前要求请求头 `userToken = Base64(IV ‖ AES-GCM-256(userId, imTokenKey))` 且 `X-Access-Token: 0`。

| | 方案 A（PC 默认） | 方案 B（推荐中期） |
| --- | --- | --- |
| 做法 | 客户端用构建期注入的 `imTokenKey` 生成 `userToken` | 服务端让这些接口同时接受 PC 登录得到的 `X-Access-Token` |
| 后端改动 | 无（仅需登录响应带主业务 `userId`） | 需要 |
| 安全性 | 密钥随安装包分发，可被逆向提取；只能依赖「密钥可轮换 + 服务端校验 userId 与登录态一致」 | 密钥不出服务端 |
| 说明 | `imTokenKey` **不进入代码仓库**，通过 `--dart-define-from-file` 注入（见 README） | 上线后 PC 端把 `AuthHeaderStrategy` 切换为 token 模式即可，业务代码不变 |

请后端确认：**方案 A 是否允许 PC 使用**；若不允许，请优先排期方案 B。

## 3. B3 · userSig 签发与续期

- 官方说明：`UserSig` 默认有效期 180 天，最长 10 年，**官方建议设置为两个月**。
- 客户端登录失败且错误码为 `6206`（`ERR_USER_SIG_EXPIRED`）、`70001`（`ERR_SVR_ACCOUNT_USERSIG_EXPIRED`）、
  `70052`（`ERR_SVR_ACCOUNT_INVALID_USERSIG`）时，PC 会**只重试一次**：重新调用 `getUserSig` 获取新签名后再登录。
  官方明确提示「其他错误码不要在登录回调里再次调用 login，避免 SDK 登录进入死循环」，所以 PC 不会对其它错误码重试。
- 与方案文档的差异：原方案列了 `70014`，核对官方错误码后确认它是「SDKAppID 与签发 userSig 时不一致」的配置错误，
  续期无法解决，已从自动续期集合中移除，改为提示「应用配置错误，请联系管理员」。
- 请后端确认 `getUserSig` 的有效期，以及 userSig 是否由后端签发（**不要**让客户端持有签发密钥）。

## 4. B4 · IM 控制台多端登录策略（运维）

路径：**腾讯云 IM 控制台 → 目标应用 → 消息服务 Chat → 功能配置 → 登录与消息 → 登录设置 → 编辑**。

| 策略 | 含义 | 是否满足 PC 上线 |
| --- | --- | --- |
| 单平台登录 | Android / iPhone / iPad / Windows / Mac / Web 仅 1 种平台在线 | 否 |
| 双平台登录（默认） | Android / iPhone / iPad / Windows / Mac **共 1 端**在线；Web 可同时在线 | **否**：PC 登录会把手机 App 踢下线 |
| **三平台登录（推荐）** | Android / iPhone / iPad 1 种平台在线；Windows / Mac 1 种平台在线；Web 可同时在线 | **是** |
| 多平台登录 | 所有平台可同时在线 | 是 |

要点：

1. 必须改为「三平台登录」或「多平台登录」，否则班主任在电脑登录会踢掉手机 App（反之亦然）。
2. 同一账号在**两台 Windows 电脑**同时登录，默认会互踢；「同平台多设备在线」属于**旗舰版 / 企业版**功能
   （每平台最多 3 个实例），如业务有需要请评估套餐。
3. 可选开启「接收被踢离线状态」：开启后，账号离线期间被踢、再次上线时 Native SDK 会收到错误码 `6208`；
   PC 端已对 `6208` 与 `onKickedOffline` 做统一处理（提示并回到登录页）。
4. 小程序使用 Web SDK，属于「Web」平台，在三平台 / 多平台策略下可与 PC、App 同时在线（请在联调时实测确认）。

验证步骤：同一账号依次登录小程序 → App → PC，三端均保持在线，且互发消息可收到。

## 5. B5 · 扣子「班主任回复助手」Bot

### 5.1 需要新增的 Bot

在扣子控制台新建 Bot「班主任回复助手」，用途是**给班主任 / 管理人员生成可直接发送的回复草稿**（不直接面向学员）。
建议系统提示词：

```text
你是智博教育「班主任回复助手」，帮助班主任针对学员消息起草回复。
要求：
1. 以班主任口吻、面向学员，语气亲切、专业、简洁，一般不超过 150 字；
2. 只输出可直接发送给学员的回复正文，不要出现「作为 AI」「以下是建议」等说明，不要使用 Markdown 标题；
3. 学员问题涉及学习方法、课程安排、考试时间、报名缴费等你不确定的事实时，不要编造，
   改为给出稳妥的回复并提示「班主任需核实」，用【待核实：…】标注在末尾；
4. 学员情绪低落或表达焦虑时，先共情再给建议；
5. 涉及退费、投诉、法律与隐私信息时，只给出安抚与转交流程的建议，并标注【需人工处理】。
```

### 5.2 下发方式（建议）

`GET /im/app/login/lstAiTch` 目前返回 `[{ avatarUrl, botId, name }]`。建议扩展两个可选字段（旧客户端忽略即可）：

```json
{ "avatarUrl": "", "botId": "7431...", "name": "班主任回复助手", "scene": "reply_assistant", "sort": 0 }
```

`scene`：`tutor`（学科助教，默认）/ `reply_assistant`（班主任回复助手）。PC 优先选择 `scene=reply_assistant`，
其次名称含「回复助手」，最后读取构建期配置 `ZB_AI_REPLY_BOT_ID`，仍无则使用列表第一项。

### 5.3 配额

App 接口设计文档记录的扣子限额为 **QPS 2 / QPM 60 / QPD 3000**（请以扣子控制台实际套餐为准）。
全部班主任共用一个访问令牌时，**每日 3000 次是硬约束**：例如 30 位班主任、每人每天 100 次建议就会触顶。
请确认：(1) 套餐额度是否需要提升；(2) 是否按老师 / 班级维度拆分 Bot 或令牌；(3) 429 时的业务降级策略。
PC 端已内置：默认手动触发、同会话 2 秒内多条消息合并为一次请求、同一消息最多重新生成 3 次、429 指数退避（2s / 4s / 8s）。

## 6. B6 · 两个 `queryByFileId` 是否同源

| 端 | 上传 | 解析 |
| --- | --- | --- |
| 小程序 | `POST /sys/cos/upload`（fileId 模式，大视频 / 图文视频 / 大文件） | `GET /sys/cos/queryByFileId` |
| App | `GET /im/app/login/generatePresignedUrl` + 客户端 PUT 直传 | `GET /im/app/login/queryByFileId` |

小程序发出的消息里 `fileId` 由前者产生；PC / App 解析时走后者。请后端确认**二者共用同一文件库**。验证方法：

1. 用小程序发送一条大视频，取消息 `payload.fileInfo.fileId`；
2. 分别调用两个解析接口，应返回同一个播放地址（或同一文件的不同签名地址）。

若不同源，PC 与 App 将无法播放小程序发出的 fileId 消息，需要后端统一或提供转换接口。

## 7. B7 · PC 版本检查接口（建议）

```http
GET {eipHost}/im/app/login/pcVersion?platform=windows&current=1.0.0%2B1
```

```json
{
  "result": {
    "latestVersion": "1.1.0+3",
    "minSupportedVersion": "1.0.0+1",
    "downloadUrl": "https://static.zhibojiaoyu.cn/zbtalk/ZhiboTalk-Setup-1.1.0.exe",
    "sha256": "<安装包 SHA-256>",
    "releaseNotes": "1. 新增 AI 辅助回答…",
    "forceUpdate": false
  }
}
```

`platform` 取 `windows` / `macos`。当前版本低于 `minSupportedVersion` 时客户端提示强制更新。

## 8. B8 · 二期：AI 建议统一后端接口（SSE）

目标：由后端统一拼装提示词（可带入学员班级 / 课程 / 老师风格）、限流、审计与模型切换；PC 仅负责展示。
事件名与扣子保持一致，PC 端只需替换数据层：

```http
POST {eipHost}/im/ai/suggest
Accept: text/event-stream
```

```json
{
  "peerImUserId": "学员 IM 账号",
  "conversationId": "可选，多轮上下文标识",
  "messages": [
    { "role": "student", "type": "text", "content": "老师，高数作业什么时候交？" },
    { "role": "teacher", "type": "text", "content": "周五晚上 8 点前。" }
  ],
  "botId": "可选"
}
```

返回 SSE：`conversation.chat.created` → `conversation.message.delta`（`content` 增量）→ `conversation.message.completed` →
`conversation.chat.completed` / `conversation.chat.failed` → `done`。

## 9. B9 · 安全事项

- 小程序 `app.js` 的 `globalData.config.SECRETKEY` 为 IM 应用密钥，**不应出现在客户端**，建议立即在控制台轮换，
  并让所有端统一通过后端获取 userSig。PC 端不包含任何签发密钥。
- 方案 A 中 `imTokenKey` 属于「可被提取的客户端密钥」，请服务端同时校验 `userToken` 解出的 userId 与 IP / 设备 / 登录态的一致性，
  并具备密钥轮换能力（PC 与 App 的密钥可分别注入、分别吊销）。

## 10. 验收清单

- [ ] B1：PC 登录接口联调通过，学员账号被拒绝，教师账号返回 `imUserSig`
- [ ] B2：确认方案 A 可用，或 B 的排期
- [ ] B3：`getUserSig` 有效期与续期行为确认
- [ ] B4：控制台改为三平台 / 多平台登录，三端同账号同时在线验证通过
- [ ] B5：Bot 创建、`lstAiTch` 下发 `scene`、配额确认
- [ ] B6：两个 `queryByFileId` 返回一致
- [ ] B7：版本接口上线（可晚于首版）
- [ ] B9：IM `SECRETKEY` 轮换
