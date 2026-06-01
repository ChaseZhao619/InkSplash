import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models.dart';

class EpaperApiClient {
  EpaperApiClient({required String baseUrl, http.Client? httpClient})
    : _baseUri = Uri.parse(_normalizeBaseUrl(baseUrl)),
      _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;

  Uri resolve(String pathOrUrl) {
    final uri = Uri.parse(pathOrUrl);
    if (uri.hasScheme) {
      return uri;
    }
    final path = pathOrUrl.startsWith('/') ? pathOrUrl.substring(1) : pathOrUrl;
    return _baseUri.resolve(path);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? bearerToken,
    Map<String, String>? headers,
  }) async {
    final response = await _networkRetry(
      () => _httpClient.get(
        resolve(path),
        headers: _headers(bearerToken: bearerToken, extra: headers),
      ),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    String? bearerToken,
    Map<String, String>? headers,
  }) async {
    final encodedBody = jsonEncode(body ?? const {});
    final response = await _networkRetry(
      () => _httpClient.post(
        resolve(path),
        headers: _headers(
          bearerToken: bearerToken,
          extra: {'Content-Type': 'application/json', ...?headers},
        ),
        body: encodedBody,
      ),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    String? bearerToken,
  }) async {
    final response = await _networkRetry(
      () => _httpClient.delete(
        resolve(path),
        headers: _headers(bearerToken: bearerToken),
      ),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Object? body,
    String? bearerToken,
    Map<String, String>? headers,
  }) async {
    final encodedBody = jsonEncode(body ?? const {});
    final response = await _networkRetry(
      () => _httpClient.patch(
        resolve(path),
        headers: _headers(
          bearerToken: bearerToken,
          extra: {'Content-Type': 'application/json', ...?headers},
        ),
        body: encodedBody,
      ),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> multipartJson(
    String path, {
    required String filePath,
    required String fileName,
    required Map<String, String> fields,
    String? bearerToken,
    Map<String, String>? headers,
  }) async {
    final response = await _networkRetry(() async {
      final request = http.MultipartRequest('POST', resolve(path))
        ..headers.addAll(_headers(bearerToken: bearerToken, extra: headers))
        ..fields.addAll(fields)
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            filePath,
            filename: fileName,
          ),
        );
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
    return _decodeObject(response);
  }

  Future<List<int>> getBytes(String pathOrUrl, {String? bearerToken}) async {
    final response = await _networkRetry(
      () => _httpClient.get(
        resolve(pathOrUrl),
        headers: _headers(bearerToken: bearerToken),
      ),
    );
    _ensureSuccess(response);
    return response.bodyBytes;
  }

  Map<String, String> _headers({
    String? bearerToken,
    Map<String, String>? extra,
  }) {
    return {
      if (bearerToken != null && bearerToken.isNotEmpty)
        'Authorization': 'Bearer $bearerToken',
      'Accept': 'application/json',
      'Connection': 'close',
      ...?extra,
    };
  }

  Future<T> _networkRetry<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 30));
    } on http.ClientException catch (error) {
      if (!_shouldRetryNetworkError(error.message)) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return request().timeout(const Duration(seconds: 30));
    } on SocketException {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return request().timeout(const Duration(seconds: 30));
    }
  }

  bool _shouldRetryNetworkError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('connection abort') ||
        normalized.contains('connection reset') ||
        normalized.contains('connection closed') ||
        normalized.contains('broken pipe');
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    _ensureSuccess(response);
    if (response.body.isEmpty) {
      return const {};
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
    throw const ApiError('Expected JSON object response');
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    var message = response.reasonPhrase ?? 'Request failed';
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['detail'] != null) {
        message = _formatDetail(decoded['detail']);
      }
    } catch (_) {
      if (response.body.isNotEmpty) {
        message = response.body;
      }
    }
    throw ApiError(message, statusCode: response.statusCode);
  }

  static String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      return 'http://47.113.120.232/';
    }
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  static String _formatDetail(Object? detail) {
    if (detail is String) {
      return detail;
    }
    if (detail is List) {
      final messages = detail
          .map(_formatValidationItem)
          .where((item) => item.isNotEmpty)
          .toList();
      if (messages.isNotEmpty) {
        return messages.join('; ');
      }
    }
    return '$detail';
  }

  static String _formatValidationItem(Object? item) {
    if (item is! Map) {
      return '$item';
    }
    final msg = item['msg']?.toString() ?? 'Invalid value';
    final loc = item['loc'];
    if (loc is List && loc.isNotEmpty) {
      final field = loc.where((part) => part != 'body').join('.');
      if (field.isNotEmpty) {
        return '$field: $msg';
      }
    }
    return msg;
  }
}
