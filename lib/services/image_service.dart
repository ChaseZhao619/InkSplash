import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models.dart';
import 'api_client.dart';

class ImageService {
  const ImageService(this._api);

  final EpaperApiClient _api;

  Future<ImageInfo> uploadImage({
    required String bearerToken,
    required String filePath,
    required String fileName,
    required UploadOptions options,
  }) async {
    final json = await _api.multipartJson(
      '/api/images',
      bearerToken: bearerToken,
      filePath: filePath,
      fileName: fileName,
      fields: {
        'direction': options.direction,
        'mode': options.mode,
        'dither': options.dither ? 'true' : 'false',
      },
    );
    return ImageInfo.fromJson(json);
  }

  Future<Uint8List> getPreviewPng(
    ImageInfo image, {
    String? bearerToken,
  }) async {
    final bytes = await _api.getBytes(
      image.previewUrl,
      bearerToken: bearerToken,
    );
    final decoded = img.decodeBmp(Uint8List.fromList(bytes));
    if (decoded == null) {
      return Uint8List.fromList(bytes);
    }
    return Uint8List.fromList(img.encodePng(decoded));
  }
}
