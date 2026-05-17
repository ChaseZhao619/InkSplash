# InkSplash 服务端最新生产需求

请在服务端实现 InkSplash App 所需的账号、设备绑定、设备共享、图片下发和 ESP32 轮询接口。本文档只描述当前最新需求。

## 1. 核心原则

- App 支持 BLE 和 SoftAP 两种 ESP-IDF Wi-Fi Provisioning 配网方式。
- 配网只负责让 ESP32 连上 Wi-Fi。
- 设备绑定由 App 扫描二维码后调用云端完成。
- App 不保存、不计算 HMAC 密钥。
- 一个设备只能有一个 owner。
- owner 可以通过家庭组或好友组把设备共享给其他账号共同管理。
- ESP32 通过云端轮询获取图片，不要求 App 和 ESP32 保持长连接。

## 2. 服务端配置

新增环境变量：

```text
DEVICE_CLAIM_HMAC_SECRET=mqIJyxzd2cD3fMrZGBoSewYgX4LOTF7Q
```

该密钥只允许存在于服务端、固件或生产工具中，不得返回给 App，不得写入 App。

设备绑定码计算规则：

```text
claim_code = hex(first_16_bytes(HMAC_SHA256(DEVICE_CLAIM_HMAC_SECRET, device_id)))
```

说明：

- HMAC 输入固定使用 `device_id`。
- 不使用二维码里的 `name` 作为 HMAC 输入。
- 输出为 32 个小写十六进制字符。
- 不再依赖每台设备预存 `claim_code_hash`。

## 3. 账号接口

保留邮箱密码账号体系：

```http
POST /api/auth/register
POST /api/auth/login
GET /api/me
POST /api/auth/verify-email/request
POST /api/auth/verify-email/confirm
POST /api/auth/password-reset/request
POST /api/auth/password-reset/confirm
```

要求：

- 注册和登录返回 Bearer token。
- `GET /api/me` 返回当前用户信息，包括 `email_verified`。
- 邮箱验证码、密码重置验证码使用 6 位数字或大写字母。
- 验证码只存 hash，设置过期时间和最大尝试次数。
- 用户写操作可以要求邮箱已验证，至少包括设备绑定、图片上传、图片下发和共享邀请。

## 4. 设备数据模型

设备表至少包含：

```text
device_id TEXT PRIMARY KEY
device_token TEXT NOT NULL
owner_user_id TEXT
current_image_id TEXT
current_version INTEGER NOT NULL DEFAULT 0
nickname TEXT
claimed_at TEXT
last_seen_at TEXT
last_status TEXT
last_error TEXT
battery_mv INTEGER
rssi INTEGER
created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
updated_at TEXT
```

说明：

- `device_id` 必须和二维码、固件一致。
- `device_token` 用于 ESP32 访问 `/current` 和 `/status`，不要放进二维码。
- `owner_user_id` 为空表示未绑定。
- 不需要保存 `claim_code_hash`；如果旧表已有该字段，可以保留但新逻辑不依赖它。

## 5. 二维码格式

App 支持纯 JSON，也支持 `data={...}` 外层格式。

BLE 示例：

```json
{
  "ver": "v1",
  "name": "PROV_C36AD8",
  "transport": "ble",
  "security": 1,
  "pop": "abcd1234",
  "device_id": "esp32_001",
  "claim_code": "f095c9b448d55c929615763b09f54fef"
}
```

SoftAP 示例：

```json
{
  "ver": "v1",
  "name": "PROV_C36AD8",
  "transport": "softap",
  "security": 1,
  "pop": "abcd1234",
  "device_id": "esp32_001",
  "claim_code": "f095c9b448d55c929615763b09f54fef"
}
```

字段要求：

- `ver` 固定为 `v1`。
- `transport` 只允许 `ble` 或 `softap`。
- `security` 当前支持 `0` 或 `1`，推荐 `1`。
- `name` 是 BLE 广播名或 SoftAP SSID。
- `pop` 是 ESP-IDF provisioning 的 Proof of Possession。
- `device_id` 是云端设备 ID。
- `claim_code` 是按第 2 节规则计算出的 32 位 hex 字符串。

## 6. 设备绑定接口

App 配网成功后调用：

```http
POST /api/me/devices/claim
Authorization: Bearer <token>
Content-Type: application/json
```

请求：

```json
{
  "device_id": "esp32_001",
  "claim_code": "f095c9b448d55c929615763b09f54fef",
  "nickname": "客厅墨水屏"
}
```

服务端校验：

- 用户必须登录。
- 如启用邮箱验证策略，用户必须已验证邮箱。
- `device_id` 必须存在。
- 设备 `owner_user_id` 必须为空。
- 服务端用 `DEVICE_CLAIM_HMAC_SECRET` 和 `device_id` 计算期望 claim_code。
- 请求中的 `claim_code` 必须和期望值完全一致。

成功行为：

- 设置 `devices.owner_user_id = current_user_id`。
- 设置 `devices.claimed_at`。
- 可写入或更新 `devices.nickname`。
- 写入 `device_members(device_id, user_id, role='owner')`。
- 返回绑定后的设备对象。

失败行为：

- 设备不存在：返回 404。
- claim_code 不匹配：返回 401 或 403，错误信息明确为 `invalid claim code`。
- 设备已绑定：返回 409，错误信息明确为 `device already claimed`。

## 7. 用户设备接口

```http
GET /api/me/devices
GET /api/me/devices/{device_id}
PATCH /api/me/devices/{device_id}
DELETE /api/me/devices/{device_id}
```

要求：

- `GET /api/me/devices` 返回用户拥有的设备、被单设备邀请共享的设备、家庭组/好友组共享的设备。
- 返回设备时包含当前用户对设备的角色，例如 `owner`、`admin`、`viewer`。
- 可包含 `share_source`：`owner`、`device_invite`、`group`。
- `owner/admin` 可以修改 nickname。
- `owner` 删除设备绑定时必须让设备回到可重新绑定状态：清空 `devices.owner_user_id`、`devices.claimed_at`、`devices.nickname`，删除该设备所有 `device_members`、未使用的设备邀请、`group_device_shares` 关系；不要删除设备本身、`device_token`、轮询状态和历史状态。
- `owner` 解绑完成后，同一个二维码里的 `device_id + claim_code` 应该可以被任意已验证账号重新绑定；如果仍返回 `device already claimed`，说明解绑逻辑不完整。
- `admin/viewer` 删除时只退出共享，不解绑设备。

## 8. 家庭组 / 好友组

账号组用于跨账号共享设备控制权。

建议数据表：

```text
account_groups(group_id, name, kind, owner_user_id, created_at)
account_group_members(group_id, user_id, role, created_at)
account_group_invites(invite_id, group_id, email, role, code_hash, expires_at, accepted_at, created_by_user_id, created_at)
group_device_shares(group_id, device_id, role, created_by_user_id, created_at)
```

`kind` 只允许：

```text
family
friends
```

组成员角色：

```text
owner
admin
member
```

设备共享角色：

```text
admin
viewer
```

接口：

```http
GET /api/me/groups
POST /api/me/groups
PATCH /api/me/groups/{group_id}
DELETE /api/me/groups/{group_id}
GET /api/me/groups/{group_id}/members
POST /api/me/groups/{group_id}/invites
POST /api/me/group-invites/accept
GET /api/me/groups/{group_id}/devices
POST /api/me/groups/{group_id}/devices
DELETE /api/me/groups/{group_id}/devices/{device_id}
```

权限：

- 创建组要求用户登录，建议要求邮箱已验证。
- 组 owner/admin 可以邀请成员。
- 设备 owner 可以把设备共享到组。
- 设备 owner 始终保留最高权限。
- 组共享不转移设备所有权。
- 组 admin 可以控制被共享设备。
- viewer 只能查看设备状态，不能下发图片。

## 9. 图片上传与下发

App 端接口：

```http
POST /api/images
POST /api/me/devices/{device_id}/assign
```

要求：

- 上传图片要求 Bearer token。
- 下发图片要求用户对设备有 `owner` 或 `admin` 权限。
- `assign` 成功后递增设备 `current_version`。
- 更新设备 `current_image_id`。

## 10. ESP32 轮询接口

保持兼容：

```http
GET /api/devices/{device_id}/current
POST /api/devices/{device_id}/status
GET /api/images/{image_id}/data
```

`GET /api/devices/{device_id}/current`：

- 使用 `X-Device-Token` 校验设备身份。
- 返回当前图片 manifest。
- 如果没有图片，返回 `has_image=false`。

`POST /api/devices/{device_id}/status`：

- 使用 `X-Device-Token` 校验设备身份。
- 记录 `last_seen_at`、`last_status`、`last_error`、`battery_mv`、`rssi`。

`GET /api/images/{image_id}/data`：

- 继续兼容 ESP32 下载。
- 推荐后续增加设备 token 或签名 URL 校验。

## 11. 测试要求

必须覆盖：

- HMAC claim_code 计算正确。
- claim_code 错误时拒绝绑定。
- 已绑定设备不能被第二个用户重复绑定。
- BLE 二维码绑定成功。
- SoftAP 二维码绑定成功。
- `data={...}` 二维码格式可用。
- owner 可以共享设备到家庭组/好友组。
- 组 admin 可以控制设备。
- viewer 不能下发图片。
- ESP32 current/status/data 接口保持兼容。
