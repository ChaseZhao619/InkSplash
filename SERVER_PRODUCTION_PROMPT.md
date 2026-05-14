# 给服务端 Codex 的修改 Prompt

请在 `ChaseZhao619/ePaperService` 服务端仓库中实现 InkSplash 私发正式版所需的后端改造。

## 背景

当前服务端是 FastAPI + SQLite + 本地文件存储，已有能力包括：

- 邮箱密码注册/登录。
- Bearer token。
- App 用户 claim 设备。
- 用户上传图片并 assign 到自己的设备。
- ESP32 旧协议：
  - `GET /api/devices/{device_id}/current`
  - `GET /api/images/{image_id}/data`
  - `POST /api/devices/{device_id}/status`
- 管理员创建设备：
  - `POST /api/devices/{device_id}`

请保持旧 ESP32 协议兼容，不要破坏固件轮询、下载和状态上报。

## 总目标

把服务端升级为可供 InkSplash iOS/Android 私发版本使用的生产化后端：

- HTTPS / 域名部署准备。
- 邮箱验证。
- 找回密码。
- 家庭共享设备。
- 设备成员权限。
- 图片访问授权。
- 设备状态历史接口。
- 运维备份和日志改善。

不要凭空删除现有接口。新增接口要有测试，旧测试必须继续通过。

## 具体要求

### 1. 用户邮箱验证

修改 `users` 表：

- 新增 `email_verified_at TEXT`
- 新增 `updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP`

新增 `email_verification_tokens` 表：

- `token_hash TEXT PRIMARY KEY`
- `user_id TEXT NOT NULL`
- `expires_at TEXT NOT NULL`
- `used_at TEXT`
- `created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP`

注册行为：

- `POST /api/auth/register` 注册成功后创建邮箱验证 token。
- 通过 SMTP 发送验证邮件。
- 返回原有 `AuthResponse`，但 `User` response 需要新增：
  - `email_verified: bool`
  - `email_verified_at: string|null`

新增接口：

```http
POST /api/auth/verify-email/request
Authorization: Bearer <token>
```

行为：

- 给当前登录用户重新发送验证邮件。
- 如果已经验证，也返回 `{"status":"ok"}`。

```http
POST /api/auth/verify-email/confirm
Content-Type: application/json
```

Body：

```json
{"token":"TOKEN"}
```

行为：

- 校验 token hash、未过期、未使用。
- 设置 `users.email_verified_at`。
- 设置 token `used_at`。
- 返回 `User`。

### 2. 找回密码

新增 `password_reset_tokens` 表：

- `token_hash TEXT PRIMARY KEY`
- `user_id TEXT NOT NULL`
- `expires_at TEXT NOT NULL`
- `used_at TEXT`
- `created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP`

新增接口：

```http
POST /api/auth/password-reset/request
Content-Type: application/json
```

Body：

```json
{"email":"user@example.com"}
```

行为：

- 无论邮箱是否存在，都返回 `{"status":"ok"}`，避免枚举邮箱。
- 如果用户存在，创建 reset token 并发送邮件。

```http
POST /api/auth/password-reset/confirm
Content-Type: application/json
```

Body：

```json
{"token":"TOKEN","new_password":"new-password"}
```

行为：

- 校验 token hash、未过期、未使用。
- 新密码沿用当前密码规则：至少 8 位。
- 更新 `users.password_hash`。
- 设置 token `used_at`。
- 返回 `{"status":"ok"}`。

### 3. SMTP 配置

通过环境变量配置邮件发送：

- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `SMTP_FROM`
- `SMTP_USE_TLS`
- `PUBLIC_APP_URL`

如果 SMTP 未配置：

- 本地开发不要崩溃。
- 将验证/重置链接记录到日志中，方便测试。
- 不要在 API response 中返回明文 token，除非测试环境显式启用，例如 `EPAPER_DEBUG_RETURN_EMAIL_TOKENS=1`。

邮件链接格式建议：

```text
{PUBLIC_APP_URL}/verify-email?token=...
{PUBLIC_APP_URL}/reset-password?token=...
```

### 4. 邮箱验证权限规则

以下用户写操作要求邮箱已验证：

- `POST /api/me/devices/claim`
- `POST /api/images` 使用 Bearer token 上传时
- `POST /api/me/devices/{device_id}/assign`
- 家庭共享邀请相关写操作

登录和 `GET /api/me` 不要求邮箱已验证。

未验证时返回 HTTP 403，detail 使用稳定文本，例如：

```text
email not verified
```

### 5. 家庭共享设备

保留 `devices.owner_user_id` 字段，兼容现有逻辑。

新增 `device_members` 表：

- `device_id TEXT NOT NULL`
- `user_id TEXT NOT NULL`
- `role TEXT NOT NULL`
- `created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP`
- 唯一索引：`(device_id, user_id)`

角色固定为：

- `owner`
- `admin`
- `viewer`

claim 成功时：

- 继续写入 `devices.owner_user_id`
- 同时写入 `device_members(role='owner')`

新增 `device_invites` 表：

- `invite_id TEXT PRIMARY KEY`
- `device_id TEXT NOT NULL`
- `email TEXT NOT NULL`
- `role TEXT NOT NULL`
- `token_hash TEXT NOT NULL`
- `expires_at TEXT NOT NULL`
- `accepted_at TEXT`
- `created_by_user_id TEXT NOT NULL`
- `created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP`

### 6. 家庭共享接口

修改：

```http
GET /api/me/devices
```

返回当前用户拥有或被共享的设备，`AppDevice` 增加：

```json
{"role":"owner"}
```

修改：

```http
GET /api/me/devices/{device_id}
```

校验用户是否在 `device_members` 中，不再只看 `owner_user_id`。

新增：

```http
PATCH /api/me/devices/{device_id}
Authorization: Bearer <token>
```

Body：

```json
{"nickname":"Desk display"}
```

权限：

- `owner` 或 `admin` 可以修改 nickname。

新增：

```http
POST /api/me/devices/{device_id}/invites
Authorization: Bearer <token>
```

Body：

```json
{"email":"member@example.com","role":"admin"}
```

权限：

- `owner` 或 `admin` 可以邀请。
- 可邀请角色只允许 `admin` 或 `viewer`，不能邀请 `owner`。

行为：

- 创建 invite token。
- 发送邀请邮件。
- 返回 `DeviceInvite`，不要返回明文 token，除非 debug 环境显式启用。

新增：

```http
POST /api/me/device-invites/accept
Authorization: Bearer <token>
```

Body：

```json
{"token":"TOKEN"}
```

行为：

- token 有效、未过期、未接受。
- 当前登录用户 email 必须等于 invite email。
- 写入 `device_members`。
- 设置 `accepted_at`。
- 返回 `AppDevice`。

新增：

```http
GET /api/me/devices/{device_id}/members
Authorization: Bearer <token>
```

权限：

- 任意成员可查看。

Response：

```json
{"members":[{"user_id":"...","email":"...","role":"owner","created_at":"..."}]}
```

新增：

```http
DELETE /api/me/devices/{device_id}/members/{user_id}
Authorization: Bearer <token>
```

权限：

- 只有 `owner` 可以移除成员。
- 不允许移除最后一个 owner。

修改：

```http
DELETE /api/me/devices/{device_id}
```

行为：

- 如果当前用户是 `owner`：解绑设备，清空 `owner_user_id`、`claimed_at`、`nickname`，删除所有 members。
- 如果当前用户是 `admin` 或 `viewer`：只退出共享，即删除自己的 `device_members` 记录，不解绑设备。

### 7. Assign 权限

修改：

```http
POST /api/me/devices/{device_id}/assign
```

权限：

- `owner` 和 `admin` 可以 assign。
- `viewer` 返回 403。

图片权限：

- Bearer 上传的图片仍归属于上传用户。
- 用户只能 assign 自己拥有的图片。

### 8. 图片访问授权

当前图片 metadata、preview、data 是公开的，正式版需要收紧。

要求：

- `GET /api/images/{image_id}`：Bearer token 访问，用户必须拥有该图片，或是某个使用该图片设备的 member。
- `GET /api/images/{image_id}/preview`：同上。
- `GET /api/images/{image_id}/data`：
  - 为兼容 ESP32，暂时保留旧行为或增加兼容分支。
  - 推荐支持 `X-Device-Token` + device/image 匹配校验，或由 manifest 返回短期签名 URL。

实现时必须保证当前 ESP32 `download_url` 下载不被直接破坏。可以先让 App 图片访问受 Bearer 保护，ESP32 data 下载保留兼容路径，并在代码中标注后续安全升级点。

### 9. 状态历史接口

保留现有 `status_events` 表。

新增：

```http
GET /api/me/devices/{device_id}/status-events?limit=50
Authorization: Bearer <token>
```

权限：

- 任意 device member 可查看。

Response：

```json
{
  "events": [
    {
      "id": 1,
      "device_id": "device001",
      "version": 1,
      "status": "displayed",
      "error": null,
      "battery_mv": 3800,
      "rssi": -62,
      "created_at": "..."
    }
  ]
}
```

### 10. HTTPS / 部署文档

更新 README / AGENTS：

- 说明生产环境必须使用域名和 HTTPS。
- App 默认 base URL 应改为 HTTPS 域名。
- nginx 增加 443 配置说明。
- 保留 80 到 443 redirect。
- 不要在文档中写真实 secret。

### 11. 备份和日志

新增备份脚本，例如：

```text
scripts/backup.sh
```

备份内容：

- SQLite 数据库
- images 目录

新增结构化日志：

- auth register/login/verify/reset
- device claim/assign/unbind
- invite create/accept
- device status

不要记录：

- 明文密码
- device token
- claim code
- 邮箱验证 token
- 密码重置 token

## 测试要求

请新增或更新 pytest 测试，覆盖：

- 注册后 `email_verified=false`。
- 验证邮箱成功、重复验证、过期 token。
- 未验证邮箱不能 claim/upload/assign。
- password reset request 不暴露邮箱是否存在。
- password reset confirm 成功、过期、重复使用失败。
- claim 后创建 owner membership。
- owner/admin/viewer 权限矩阵。
- viewer 不能 assign。
- admin 可以 assign。
- 非成员不能查看设备、成员、状态历史。
- invite 创建、接受、邮箱不匹配、过期、重复接受。
- 删除设备成员，不能删除最后一个 owner。
- owner 解绑设备后 members 清空。
- admin/viewer 调用 DELETE 只退出共享，不解绑设备。
- 图片 metadata/preview 授权。
- ESP32 旧协议 `current/status/data` 兼容。

运行：

```bash
pytest
python -m py_compile app/main.py app/db.py app/image_processing.py simulate_device.py
```

## 交付结果

完成后请输出：

- 修改了哪些文件。
- 新增了哪些 API。
- 是否保持旧 ESP32 协议兼容。
- 如何配置 SMTP。
- 如何配置 HTTPS 域名。
- 测试结果。
