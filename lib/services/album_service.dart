import '../models.dart';
import 'api_client.dart';

class AlbumService {
  const AlbumService(this._api);

  final EpaperApiClient _api;

  Future<List<InkAlbum>> listAlbums(String bearerToken) async {
    final json = await _api.getJson('/api/me/albums', bearerToken: bearerToken);
    return _albumsFromJson(json);
  }

  Future<InkAlbum> createAlbum({
    required String bearerToken,
    required String title,
    String? subtitle,
  }) async {
    final json = await _api.postJson(
      '/api/me/albums',
      bearerToken: bearerToken,
      body: {'title': title, 'subtitle': subtitle},
    );
    return InkAlbum.fromJson(_objectPayload(json, 'album'));
  }

  Future<InkAlbum> getAlbum({
    required String bearerToken,
    required String albumId,
  }) async {
    final json = await _api.getJson(
      '/api/me/albums/$albumId',
      bearerToken: bearerToken,
    );
    return InkAlbum.fromJson(_objectPayload(json, 'album'));
  }

  Future<InkAlbum> updateAlbum({
    required String bearerToken,
    required String albumId,
    required String title,
    String? subtitle,
  }) async {
    final json = await _api.patchJson(
      '/api/me/albums/$albumId',
      bearerToken: bearerToken,
      body: {'title': title, 'subtitle': subtitle},
    );
    return InkAlbum.fromJson(_objectPayload(json, 'album'));
  }

  Future<void> deleteAlbum({
    required String bearerToken,
    required String albumId,
  }) async {
    await _api.deleteJson('/api/me/albums/$albumId', bearerToken: bearerToken);
  }

  Future<void> addPhotoToAlbum({
    required String bearerToken,
    required String albumId,
    required String photoId,
  }) async {
    await _api.postJson(
      '/api/me/albums/$albumId/photos/$photoId',
      bearerToken: bearerToken,
    );
  }

  Future<void> removePhotoFromAlbum({
    required String bearerToken,
    required String albumId,
    required String photoId,
  }) async {
    await _api.deleteJson(
      '/api/me/albums/$albumId/photos/$photoId',
      bearerToken: bearerToken,
    );
  }

  Future<List<InkPhoto>> listPhotos(String bearerToken) async {
    final json = await _api.getJson('/api/me/photos', bearerToken: bearerToken);
    final raw = json['photos'] ?? json['items'] ?? [];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => InkPhoto.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }

  Future<InkPhoto> updatePhoto({
    required String bearerToken,
    required String photoId,
    bool? favorite,
    List<String>? tags,
  }) async {
    final body = <String, Object>{};
    if (favorite != null) {
      body['favorite'] = favorite;
    }
    if (tags != null) {
      body['tags'] = tags;
    }
    final json = await _api.patchJson(
      '/api/me/photos/$photoId',
      bearerToken: bearerToken,
      body: body,
    );
    return InkPhoto.fromJson(_objectPayload(json, 'photo'));
  }

  List<InkAlbum> _albumsFromJson(Map<String, dynamic> json) {
    final raw = json['albums'] ?? json['items'] ?? [];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => InkAlbum.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }
}

Map<String, dynamic> _objectPayload(Map<String, dynamic> json, String key) {
  final payload = json[key];
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  if (payload is Map) {
    return payload.map((key, value) => MapEntry('$key', value));
  }
  return json;
}
