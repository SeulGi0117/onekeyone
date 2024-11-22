import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadStoreImage(String imageName, File imageFile) async {
    try {
      // store_images 폴더에 이미지 업로드
      final ref = _storage.ref().child('store_images/$imageName');
      await ref.putFile(imageFile);

      // 업로드된 이미지의 URL 반환
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('이미지 업로드 오류: $e');
      throw Exception('이미지 업로드에 실패했습니다');
    }
  }
}
