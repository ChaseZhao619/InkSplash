# InkSplash 正式私发版完善计划

## 目标

目标按“企业/私发 + TestFlight iOS + Android APK”完善，不优先公开上架 App Store / Google Play。

第一阶段重点：

- 配网绑定流程更稳定、更清楚。
- 图片上传、预览、下发流程更直观。
- 账号具备邮箱验证和找回密码能力。
- 支持家庭共享设备。
- 服务端传输、图片访问和设备权限达到可私发使用的安全水平。

当前服务端已经具备账号、设备绑定、Bearer 上传、设备下发和 ESP32 轮询协议。后续不要重做旧协议，而是在现有接口上补生产化能力。

## App 端改动

- 重构信息架构：从当前 4 个 Tab 原型页改成正式流程：登录/注册、设备首页、添加设备向导、设备详情、图片上传/预览/下发、家庭成员管理、设置页。
- 增加本地会话持久化：使用安全存储保存 `access_token`、用户信息、base URL；启动时自动恢复登录并调用 `/api/me` 校验 token。
- 配网流程做成分步向导：扫码、权限检查、BLE 搜索、连接、Wi-Fi 扫描、输入密码、配网结果、云端绑定。每一步显示明确状态、失败原因和重试按钮。
- 上传体验升级：图片选择后先进入预览、方向、适配方式、抖动设置页，用户确认后再上传。上传成功后自动 assign，并显示目标设备、版本号、预览图、下发状态。
- 设备详情页展示：在线状态、最后上报时间、电量、RSSI、当前版本、当前图片、最近状态事件；支持刷新、重命名、解绑、邀请家庭成员。
- 家庭共享 UI：设备 owner 可邀请成员；成员可查看设备，并按角色决定是否能上传/下发。V1 角色固定为 `owner`、`admin`、`viewer`。
- 视觉和发布品质：统一中文文案、品牌色、空状态、错误提示、加载状态、App 图标、启动页。
- 配置收敛：移除用户可见的调试型 Server URL 输入，改到设置页隐藏配置。
- 发布工程：Android 使用正式签名 keystore；iOS 配置 TestFlight bundle、版本号、权限说明；默认服务地址切到 HTTPS 域名，移除 Android cleartext 和 iOS HTTP 例外。

## 服务端改动

- 配置域名和 HTTPS：nginx 接入证书，服务地址从 `http://47.113.120.232` 切到 `https://<your-domain>`；App、固件和二维码后续都使用 HTTPS base URL。
- 邮箱验证与找回密码，SMTP 配置化：
  - 新增 `email_verification_tokens`、`password_reset_tokens` 表，token 只存 hash，设置过期时间和使用时间。
  - `POST /api/auth/register` 注册后发送验证邮件，返回 session，但 `user.email_verified=false`。
  - 新增 `POST /api/auth/verify-email/request`、`POST /api/auth/verify-email/confirm`。
  - 新增 `POST /api/auth/password-reset/request`、`POST /api/auth/password-reset/confirm`。
  - 新增环境变量：`SMTP_HOST`、`SMTP_PORT`、`SMTP_USERNAME`、`SMTP_PASSWORD`、`SMTP_FROM`、`PUBLIC_APP_URL`。
- 会话与账号安全：
  - `users` 表新增 `email_verified_at`、`updated_at`。
  - Bearer token 继续兼容当前 HMAC 格式。
  - 上传、claim、assign 等用户写操作要求邮箱已验证；登录和查看 `/api/me` 不强制。
- 家庭共享数据模型：
  - 保留 `devices.owner_user_id` 兼容当前逻辑。
  - 新增 `device_members`：`device_id`、`user_id`、`role`、`created_at`，唯一索引 `(device_id,user_id)`。
  - claim 成功时同时写入 owner 的 `device_members(role='owner')`。
  - 新增 `device_invites`：`invite_id`、`device_id`、`role`、`email`、`token_hash`、`expires_at`、`accepted_at`。
- 家庭共享接口：
  - `GET /api/me/devices` 返回用户拥有或被共享的设备，并包含 `role`。
  - `GET /api/me/devices/{device_id}` 校验 membership，不再只校验 owner。
  - `POST /api/me/devices/{device_id}/invites` owner/admin 创建邀请。
  - `POST /api/me/device-invites/accept` 登录用户接受邀请。
  - `GET /api/me/devices/{device_id}/members` 查看成员列表。
  - `DELETE /api/me/devices/{device_id}/members/{user_id}` owner 移除成员。
  - `PATCH /api/me/devices/{device_id}` 修改 nickname。
- 权限规则：
  - `owner`：解绑、邀请、移除成员、上传并下发。
  - `admin`：上传并下发、查看状态。
  - `viewer`：只查看设备和状态，不能 assign。
  - `DELETE /api/me/devices/{device_id}` owner 调用时解绑设备并清空成员；非 owner 不允许解绑设备，只能退出共享。
- 图片安全：
  - 当前 `GET /api/images/{image_id}`、`/preview`、`/data` 知道 `image_id` 即可访问，正式版需要补授权。
  - App 访问图片 metadata/preview 需要 Bearer token，校验图片 owner 或设备 membership。
  - ESP32 下载 `/api/images/{image_id}/data` 继续兼容，但推荐改为 manifest 返回短期签名下载 URL，或要求 `X-Device-Token` + 当前 device/image 匹配。
- 状态历史：
  - 保留 ESP32 `POST /api/devices/{device_id}/status`。
  - 新增 `GET /api/me/devices/{device_id}/status-events?limit=50`，App 设备详情显示最近状态。
- 运维和部署：
  - 增加数据库备份脚本，备份 SQLite 和 `/var/lib/epaper-service/images`。
  - 增加结构化日志，记录 auth、claim、assign、status 的关键事件，但不记录密码、device token、claim code。
  - 增加 `/health` 深度检查：数据库可写、图片目录可写、版本号。

## 新增或调整的 API

### 用户

`GET /api/me` response 增加：

```json
{
  "email_verified": true,
  "email_verified_at": "2026-05-14T00:00:00Z"
}
```

`POST /api/auth/verify-email/request`

- Header：`Authorization: Bearer <token>`
- Response：`{"status":"ok"}`

`POST /api/auth/verify-email/confirm`

- Body：`{"token": "TOKEN"}`
- Response：`User`

`POST /api/auth/password-reset/request`

- Body：`{"email": "user@example.com"}`
- Response：永远返回 `{"status":"ok"}`，避免枚举邮箱。

`POST /api/auth/password-reset/confirm`

- Body：`{"token": "TOKEN", "new_password": "new-password"}`
- Response：`{"status":"ok"}`

### 设备

`PATCH /api/me/devices/{device_id}`

- Body：`{"nickname": "Desk display"}`
- Response：`AppDevice`

`GET /api/me/devices/{device_id}/status-events?limit=50`

- Response：`{"events":[StatusEvent]}`

### 家庭共享

`POST /api/me/devices/{device_id}/invites`

- Body：`{"email": "member@example.com", "role": "admin"}`
- Response：`DeviceInvite`

`POST /api/me/device-invites/accept`

- Body：`{"token": "TOKEN"}`
- Response：`AppDevice`

`GET /api/me/devices/{device_id}/members`

- Response：`{"members":[DeviceMember]}`

`DELETE /api/me/devices/{device_id}/members/{user_id}`

- Response：`{"status":"ok"}`

## 测试计划

- App 真机测试 iOS TestFlight 和 Android APK，覆盖扫码、BLE 权限拒绝、BLE 找不到设备、Wi-Fi 密码错误、配网成功、claim 成功、上传成功、assign 后版本递增。
- App 测试登录持久化、token 过期、邮箱未验证时阻止上传/绑定、无设备空状态、viewer 不能下发。
- Server 测试注册、邮箱验证、重复验证、密码找回 token 过期、claim code 错误/重复、家庭邀请接受/过期/重复。
- Server 测试 owner/admin/viewer 权限矩阵，确保用户不能查看或下发非成员设备，不能访问无权限图片预览。
- Firmware compatibility：旧 ESP32 `current/status/data` 协议保持可用；如启用签名下载 URL，先保留旧 `/data` 兼容路径用于灰度。
- Release：Android release APK 使用正式签名；iOS 走 TestFlight；每次发布记录版本、commit、APK SHA-256、已知限制。

## 默认假设

- 发布目标是企业/私发，不优先处理 App Store / Google Play 公开上架材料。
- iOS 分发使用 TestFlight，Android 分发使用 GitHub Release APK。
- 后端会绑定正式域名并启用 HTTPS；App 默认只连接 HTTPS 服务。
- 邮件使用 SMTP 环境变量配置，具体 SMTP 服务商可后续替换，不影响 API 设计。
- 家庭共享 V1 使用固定角色 `owner/admin/viewer`，不做更细粒度权限配置。
