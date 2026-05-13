# ESP32-C3 配网与 InkSplash App 对接说明

本文档给负责 ESP32 固件的同事使用，目标是让 ESP32-C3 设备可以通过 InkSplash App 完成 BLE 配网、云端绑定、图片拉取和状态上报。

## 目标流程

1. ESP32 进入 BLE 配网模式。
2. App 扫描设备二维码，拿到 BLE 名称、PoP、`device_id` 和 `claim_code`。
3. App 通过 ESP-IDF Wi-Fi Provisioning BLE 协议给 ESP32 下发 Wi-Fi SSID 和密码。
4. ESP32 连接 Wi-Fi。
5. App 用二维码里的 `device_id + claim_code` 调用云端接口，把设备绑定到当前用户账号。
6. 用户在 App 上传图片并下发到设备。
7. ESP32 主动轮询云端 manifest，发现版本变化后下载图片数据并刷新电子纸。
8. ESP32 上报显示状态。

## 固件必须预置的数据

每台设备需要有独立的：

- `device_id`
- `device_token`
- `claim_code`
- `pop`
- 云端 base URL，默认：

```text
http://47.113.120.232
```

字段说明：

- `device_id`：设备唯一编号，用于云端接口路径。
- `device_token`：ESP32 请求云端 current/status 接口时使用，只能存在固件里，不要放进二维码。
- `claim_code`：App 绑定设备到账号时使用的一次性绑定码，可以放进二维码。
- `pop`：ESP-IDF Security 1 的 Proof of Possession，用于 BLE 配网安全握手，可以放进二维码。

## 二维码内容

设备外壳、包装、屏幕或串口日志中需要提供二维码。App 当前要求二维码内容是 JSON 字符串：

```json
{
  "ver": "v1",
  "name": "PROV_123456",
  "transport": "ble",
  "security": 1,
  "pop": "abcd1234",
  "device_id": "device001",
  "claim_code": "one-time-claim-code"
}
```

字段要求：

- `ver` 固定为 `v1`
- `transport` 固定为 `ble`
- `security` 固定为 `1`
- `name` 必须等于或能唯一匹配 BLE 广播名
- `pop` 必须和固件中 Wi-Fi Provisioning 使用的 PoP 一致
- `device_id` 必须和云端设备记录一致
- `claim_code` 必须和云端创建设备时生成或写入的绑定码一致

建议：

- BLE name 使用 `PROV_` 前缀，例如 `PROV_123456`
- `123456` 可以取 MAC 后 3 字节或设备序列号后缀
- `claim_code` 不要等于 `device_token`
- `claim_code` 被 App 成功绑定后会失效，需要管理员重新生成才能再次绑定

## ESP-IDF 配网要求

请使用 ESP-IDF Wi-Fi Provisioning：

- 芯片：ESP32-C3
- Transport：BLE
- Security：Security 1
- PoP：启用，并和二维码 `pop` 一致
- BLE scheme：`wifi_prov_scheme_ble`
- BLE service name：二维码中的 `name`

参考文档：

```text
https://docs.espressif.com/projects/esp-idf/zh_CN/v5.5-rc1/esp32c3/api-reference/provisioning/wifi_provisioning.html
```

固件端典型配置点：

```c
wifi_prov_mgr_config_t config = {
    .scheme = wifi_prov_scheme_ble,
    .scheme_event_handler = WIFI_PROV_SCHEME_BLE_EVENT_HANDLER_FREE_BTDM
};
```

Security 1：

```c
wifi_prov_security_t security = WIFI_PROV_SECURITY_1;
const char *pop = "abcd1234";
```

BLE service name：

```c
const char *service_name = "PROV_123456";
```

配网启动时需要确保：

- BLE 广播名和二维码 `name` 一致
- PoP 和二维码 `pop` 一致
- 支持 App 发起 Wi-Fi scan
- 支持 App 下发 SSID/password
- 配网成功后保存 Wi-Fi 凭据
- 后续重启可以自动连接 Wi-Fi

## 何时进入配网模式

建议逻辑：

1. 首次开机未保存 Wi-Fi 时，自动进入配网模式。
2. 长按按键 5 秒，清除 Wi-Fi 并重新进入配网模式。
3. 配网超时后可以低功耗等待或重启再次进入配网。

建议串口日志输出：

```text
device_id=device001
ble_name=PROV_123456
provisioning=started
```

不要在正式日志中输出 `device_token`。

## 云端设备创建要求

在 App 绑定前，云端必须已经存在设备记录。管理员需要调用：

```http
POST /api/devices/{device_id}
X-Admin-Token: <admin-token>
Content-Type: application/json
```

请求示例：

```json
{
  "token": "DEVICE_TOKEN_IN_FIRMWARE",
  "claim_code": "one-time-claim-code"
}
```

返回示例：

```json
{
  "device_id": "device001",
  "token": "DEVICE_TOKEN_IN_FIRMWARE",
  "claim_code": "one-time-claim-code"
}
```

要求：

- 云端 `device_id` 必须和固件、二维码一致
- 云端 `token` 必须和固件里的 `device_token` 一致
- 云端 `claim_code` 必须和二维码一致

## ESP32 云端轮询协议

ESP32 配网并联网后，不需要被 App 直接连接。设备通过 HTTP 主动请求云端。

### 1. 获取当前图片 manifest

```http
GET /api/devices/{device_id}/current
X-Device-Token: DEVICE_TOKEN
```

示例：

```http
GET http://47.113.120.232/api/devices/device001/current
X-Device-Token: DEVICE_TOKEN
```

无图片时返回：

```json
{
  "device_id": "device001",
  "version": 0,
  "has_image": false
}
```

有图片时返回：

```json
{
  "device_id": "device001",
  "version": 1,
  "has_image": true,
  "image_id": "IMAGE_ID",
  "width": 800,
  "height": 480,
  "format": "epd4bit-indexed-v1",
  "palette": [[0,0,0],[255,255,255],[255,255,0],[255,0,0],[0,0,255],[0,255,0]],
  "sha256": "SHA256",
  "download_url": "/api/images/IMAGE_ID/data"
}
```

固件要求：

- 保存本地已显示的 `version`
- 如果云端 `version` 不变，不下载图片
- 如果 `has_image=false`，进入休眠或等待
- 如果 `version` 变化，下载 `download_url`

### 2. 下载图片数据

如果 `download_url` 是相对路径，需要拼接 base URL：

```text
http://47.113.120.232/api/images/IMAGE_ID/data
```

请求：

```http
GET /api/images/{image_id}/data
```

当前该接口不需要 `X-Device-Token`，但固件可以继续只按 manifest 中的 `download_url` 下载。

下载后必须校验：

- 文件大小：`width * height / 2`
- SHA-256：等于 manifest 中的 `sha256`

对于当前屏幕尺寸：

```text
800 * 480 / 2 = 192000 bytes
480 * 800 / 2 = 192000 bytes
```

### 3. 上报状态

显示完成或失败后，ESP32 上报：

```http
POST /api/devices/{device_id}/status
X-Device-Token: DEVICE_TOKEN
Content-Type: application/json
```

成功显示：

```json
{
  "version": 1,
  "status": "displayed"
}
```

图片未变化：

```json
{
  "version": 1,
  "status": "unchanged"
}
```

显示失败：

```json
{
  "version": 1,
  "status": "error",
  "error": "sha256 mismatch"
}
```

建议附带电池和信号：

```json
{
  "version": 1,
  "status": "displayed",
  "battery_mv": 3800,
  "rssi": -62
}
```

## 图片数据格式

格式名称：

```text
epd4bit-indexed-v1
```

每个字节存两个像素：

```text
高 4 bit：第一个像素
低 4 bit：第二个像素
```

C 解码示例：

```c
uint8_t first = (byte >> 4) & 0x0F;
uint8_t second = byte & 0x0F;
```

调色板索引：

```text
0 black  RGB(0, 0, 0)
1 white  RGB(255, 255, 255)
2 yellow RGB(255, 255, 0)
3 red    RGB(255, 0, 0)
4 blue   RGB(0, 0, 255)
5 green  RGB(0, 255, 0)
```

固件需要把 palette index 转换成电子纸屏幕驱动需要的颜色编码。

## 推荐设备主循环

```text
1. 启动或 deep sleep 唤醒
2. 连接 Wi-Fi
3. GET /api/devices/{device_id}/current
4. 如果 has_image=false，上报 idle，进入休眠
5. 如果 version 和本地一致，上报 unchanged，进入休眠
6. 如果 version 变化，下载 download_url
7. 校验文件大小
8. 校验 sha256
9. 解码 epd4bit-indexed-v1
10. 刷新电子纸
11. 保存当前 version
12. 上报 displayed
13. 进入 deep sleep
```

## 错误处理要求

建议固件至少处理：

- Wi-Fi 连接失败
- HTTP 请求超时
- HTTP 401：device token 不匹配
- HTTP 404：device_id 不存在
- manifest JSON 解析失败
- 图片下载失败
- 图片大小不匹配
- SHA-256 不匹配
- 电子纸刷新失败

遇到失败时：

- 如果能联网，调用 status 接口上报 `error`
- `error` 字段写简短原因，例如 `wifi failed`、`http 401`、`sha256 mismatch`
- 不要保存新 version
- 下次唤醒继续重试

## 联调验收清单

### 配网验收

- App 能扫描二维码
- App 能搜索到 BLE 设备
- App 能连接 BLE 设备
- App 能扫描到 Wi-Fi 列表
- App 能下发 Wi-Fi 密码
- ESP32 能连接 Wi-Fi
- App 能用 `device_id + claim_code` 成功绑定设备

### 云端协议验收

- ESP32 带 `X-Device-Token` 请求 current 成功
- 没有图片时返回 `has_image=false`
- App 上传并下发图片后，current 返回 `has_image=true`
- version 每次下发后递增
- ESP32 能下载 `download_url`
- 下载文件大小为 `192000 bytes`
- SHA-256 校验通过
- ESP32 显示完成后上报 `displayed`
- App 的 Devices 页面能看到最新状态、电量、RSSI

## 调试建议

串口日志建议输出：

```text
boot reason
device_id
ble provisioning start/stop
wifi connected/disconnected
current manifest http code
remote version
local version
download size
sha256 result
display result
status report result
```

不要输出：

- `device_token`
- Wi-Fi 密码
- 用户账号 token

## 当前限制

- 首版只支持 BLE 配网，不支持 SoftAP 配网。
- 首版只支持 Security 1，不支持 Security 0 或 Security 2。
- `claim_code` 是一次性的，绑定成功后不能再次使用。
- App 不直接把图片推送给 ESP32，ESP32 必须主动轮询云端。
- 当前服务器使用 HTTP，token 会明文传输；长期正式使用前建议切换 HTTPS。
