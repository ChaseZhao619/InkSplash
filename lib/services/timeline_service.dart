import '../models.dart';
import 'api_client.dart';

class TimelineService {
  const TimelineService(this._api);

  final EpaperApiClient _api;

  Future<List<InkTimelineEvent>> listTimeline({
    required String bearerToken,
    String range = 'all',
    String? albumId,
    String? deviceId,
  }) async {
    final query = <String, String>{
      'range': range,
      if (albumId != null && albumId.isNotEmpty) 'album_id': albumId,
      if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
    };
    final path = Uri(
      path: '/api/me/timeline',
      queryParameters: query,
    ).toString();
    final json = await _api.getJson(path, bearerToken: bearerToken);
    final raw = json['events'] ?? json['items'] ?? [];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => InkTimelineEvent.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }
}
