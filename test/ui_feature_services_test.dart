import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ink_splash/models.dart';
import 'package:ink_splash/services/api_client.dart';
import 'package:ink_splash/services/auth_service.dart';

void main() {
  test(
    'parses album, photo, timeline, notification, storage, and preferences',
    () {
      final album = InkAlbum.fromJson({
        'album_id': 'alb_1',
        'title': 'Family',
        'cover_url': '/preview',
        'photo_count': 2,
        'tags': ['family'],
        'shared': true,
        'photos': [
          {
            'photo_id': 'pho_1',
            'image_id': 'img_1',
            'preview_url': '/api/images/img_1/preview',
            'favorite': true,
          },
        ],
      });

      expect(album.albumId, 'alb_1');
      expect(album.photos.single.favorite, isTrue);

      final event = InkTimelineEvent.fromJson({
        'event_id': 'evt_1',
        'type': 'photo_assigned',
        'title': 'Sent',
        'device_id': 'esp32_001',
      });
      expect(event.type, 'photo_assigned');
      expect(event.deviceId, 'esp32_001');

      final notification = InkNotification.fromJson({
        'notification_id': 'ntf_1',
        'title': 'Device updated',
        'read_at': '2026-06-01T10:00:00Z',
      });
      expect(notification.read, isTrue);

      final storage = StorageSummary.fromJson({
        'used_bytes': 512,
        'quota_bytes': 1024,
        'photo_count': 4,
      });
      expect(storage.usedRatio, 0.5);

      final prefs = UserPreferences.fromJson({
        'device_alerts': false,
        'profile_visibility': 'private',
      });
      expect(prefs.deviceAlerts, isFalse);
      expect(prefs.sharingAlerts, isTrue);
      expect(prefs.profileVisibility, 'private');
    },
  );

  test('oauth services parse AuthSession response', () async {
    final client = MockClient((request) async {
      expect(request.url.path, startsWith('/api/auth/oauth/'));
      return http.Response(
        jsonEncode({
          'access_token': 'token',
          'token_type': 'bearer',
          'user': {
            'user_id': 'usr_1',
            'email': 'me@example.com',
            'email_verified': true,
            'created_at': '2026-06-01T10:00:00Z',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = AuthService(
      EpaperApiClient(baseUrl: 'http://localhost', httpClient: client),
    );

    final apple = await service.loginWithApple(
      identityToken: 'apple-id-token',
      authorizationCode: 'apple-code',
    );
    final google = await service.loginWithGoogle(
      identityToken: 'google-id-token',
      authorizationCode: 'google-code',
    );

    expect(apple.accessToken, 'token');
    expect(google.user.emailVerified, isTrue);
  });
}
