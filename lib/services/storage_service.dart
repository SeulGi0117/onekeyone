import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  Future<String> convertImageToBase64(String localPath) async {
    try {
      print('Converting image from path: $localPath');

      final File file = File(localPath);
      if (!await file.exists()) {
        throw Exception('File does not exist at path: $localPath');
      }

      // 이미지 압축
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) throw Exception('Failed to decode image');

      // 이미지 크기 조정 (최대 width 800px)
      int targetWidth = 800;
      int targetHeight = (800 * image.height / image.width).round();

      final resized = img.copyResize(image,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.linear);

      // JPEG 품질 85%로 압축
      final compressedBytes = img.encodeJpg(resized, quality: 85);

      // Base64로 인코딩
      final base64String = base64Encode(compressedBytes);

      print('Image converted to base64 successfully');
      return base64String;
    } catch (e, stackTrace) {
      print('이미지 변환 오류: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
