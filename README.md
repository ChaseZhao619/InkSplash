# InkSplash

Flutter iOS/Android app for the ePaper service.

## V1 Scope

- Email/password cloud account.
- ESP32-C3 BLE provisioning with ESP-IDF Wi-Fi provisioning protocol.
- QR payload binding: `device_id + claim_code + pop`.
- User-owned device list.
- Image upload, preview decode, and assign-to-device flow.

The app expects the service API described in the implementation plan:

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/me`
- `POST /api/me/devices/claim`
- `GET /api/me/devices`
- `GET /api/me/devices/{device_id}`
- `DELETE /api/me/devices/{device_id}`
- `POST /api/me/devices/{device_id}/assign`
- `POST /api/images` with Bearer token support

The existing ESP32 endpoints remain unchanged:

- `GET /api/devices/{device_id}/current`
- `GET /api/images/{image_id}/data`
- `POST /api/devices/{device_id}/status`

## QR Payload

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

## Native Provisioning Bridge

Flutter calls `com.inksplash.app/provisioning` through a method channel.

Android uses:

```text
com.github.espressif:esp-idf-provisioning-android:lib-2.4.4
```

iOS uses:

```text
pod 'ESPProvision'
```

Run iOS pods after dependency changes:

```bash
cd ios
pod install
```

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

Run on a real phone for BLE provisioning:

```bash
flutter run
```
