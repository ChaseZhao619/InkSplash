# InkSplash UI Feature Backend Requirements

This document defines the backend APIs required by the current InkSplash mobile UI. The Flutter app keeps using the existing `baseUrl` and Bearer session model. These endpoints should be implemented in `https://github.com/ChaseZhao619/ePaperService`.

## Auth: Apple and Google

Both social login endpoints must return the same response shape as `POST /api/auth/login`.

```http
POST /api/auth/oauth/apple
Content-Type: application/json
```

Request:

```json
{
  "identity_token": "APPLE_ID_TOKEN",
  "authorization_code": "APPLE_AUTHORIZATION_CODE",
  "email": "optional@example.com",
  "full_name": "Optional Name"
}
```

```http
POST /api/auth/oauth/google
Content-Type: application/json
```

Request:

```json
{
  "identity_token": "GOOGLE_ID_TOKEN",
  "authorization_code": "OPTIONAL_SERVER_AUTH_CODE",
  "email": "user@example.com",
  "display_name": "Optional Name"
}
```

Server behavior:

- Verify the provider token server-side.
- Create the user if this is the first sign-in.
- Link provider identity to the existing user when email matches a verified account.
- Return `{ "access_token": "...", "token_type": "bearer", "user": { ... } }`.

Client/platform configuration still required:

- Apple Developer account must enable Sign in with Apple for bundle id `com.inksplash.app`.
- iOS uses `ios/Runner/Runner.entitlements` with `com.apple.developer.applesignin`.
- Google Sign-In must provide Android OAuth client configuration for package `com.inksplash.app` and the app signing SHA fingerprints.
- Google Sign-In must provide iOS OAuth client configuration for bundle id `com.inksplash.app`; add the reversed client id URL scheme to `ios/Runner/Info.plist` when the real client id is available.
- The Google server client id used by the backend must match the provider configuration that validates `identity_token` / `authorization_code`.

## Albums and Photos

```http
GET /api/me/albums
POST /api/me/albums
GET /api/me/albums/{album_id}
PATCH /api/me/albums/{album_id}
DELETE /api/me/albums/{album_id}
POST /api/me/albums/{album_id}/photos/{photo_id}
DELETE /api/me/albums/{album_id}/photos/{photo_id}
GET /api/me/photos
GET /api/me/photos/{photo_id}
PATCH /api/me/photos/{photo_id}
```

Album object:

```json
{
  "album_id": "alb_123",
  "title": "Family",
  "subtitle": "Shared memories",
  "cover_url": "/api/images/img_1/preview",
  "photo_count": 24,
  "tags": ["family"],
  "shared": true,
  "created_at": "2026-06-01T10:00:00Z",
  "updated_at": "2026-06-01T10:00:00Z"
}
```

Photo object:

```json
{
  "photo_id": "pho_123",
  "image_id": "img_123",
  "title": "Mountain",
  "preview_url": "/api/images/img_123/preview",
  "data_url": "/api/images/img_123/data",
  "album_ids": ["alb_123"],
  "favorite": false,
  "tags": ["travel"],
  "assigned_device_id": "esp32_001",
  "assigned_at": "2026-06-01T10:00:00Z",
  "width": 480,
  "height": 800,
  "created_at": "2026-06-01T10:00:00Z"
}
```

List responses should use `{ "albums": [...] }` and `{ "photos": [...] }`; the app also accepts `{ "items": [...] }`.

## Timeline

```http
GET /api/me/timeline?range=all&album_id=alb_123&device_id=esp32_001
```

Event object:

```json
{
  "event_id": "evt_123",
  "type": "photo_uploaded",
  "title": "Photo uploaded",
  "subtitle": "Sent to Living Room",
  "photo_id": "pho_123",
  "album_id": "alb_123",
  "device_id": "esp32_001",
  "preview_url": "/api/images/img_123/preview",
  "created_at": "2026-06-01T10:00:00Z"
}
```

Supported `type` values should include `photo_uploaded`, `photo_assigned`, `device_displayed`, `device_status`, `group_invite`, `member_joined`, and `album_updated`.

## Notifications and Settings

```http
GET /api/me/notifications
PATCH /api/me/notifications/{notification_id}/read
GET /api/me/notification-settings
PATCH /api/me/notification-settings
GET /api/me/storage
GET /api/me/profile
PATCH /api/me/profile
GET /api/me/preferences
PATCH /api/me/preferences
```

Notification settings and preferences can use a flexible JSON object. The Flutter app currently reads these keys when present:

```json
{
  "device_alerts": true,
  "sharing_alerts": true,
  "upload_alerts": true,
  "profile_visibility": "family",
  "analytics_enabled": false
}
```

Storage response:

```json
{
  "used_bytes": 2469606195,
  "quota_bytes": 10737418240,
  "photo_count": 320,
  "album_count": 12,
  "device_count": 3,
  "cleanup_suggestion": "Remove old previews to save space."
}
```

## Virtual Test Device

The app exposes a testing tool for creating a cloud-backed virtual e-ink frame. This is used to validate upload, assign, timeline, status, and album flows without a physical ESP32 device.

```http
POST /api/me/devices/virtual
Authorization: Bearer <token>
Content-Type: application/json
```

Request:

```json
{
  "nickname": "Test Frame",
  "profile": "six_color_eink"
}
```

Response:

```json
{
  "device_id": "virtual_abc123",
  "nickname": "Test Frame",
  "role": "owner",
  "share_source": "owner",
  "current_image_id": null,
  "current_version": 0,
  "last_status": "virtual",
  "created_at": "2026-06-01T10:00:00Z",
  "updated_at": "2026-06-01T10:00:00Z"
}
```

Requirements:

- Requires an authenticated user; server may require verified email if that is the production write policy.
- Returned JSON must be compatible with `AppDevice`.
- The virtual device should appear in `GET /api/me/devices`.
- `POST /api/me/devices/{device_id}/assign` should work for virtual devices.
- Assignment should increment `current_version`, update `current_image_id`, and create timeline/status events so the app can test the full UX.
- Virtual devices must be clearly identified by `device_id` prefix or a backend-only type flag; they must never be used by real ESP32 polling tokens.
