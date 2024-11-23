import 'package:firebase_database/firebase_database.dart';
import './storage_service.dart';

class DatabaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final StorageService _storageService = StorageService();

  // 데이터 읽기
  Stream<DatabaseEvent> getPlantData() {
    return _database.child('plants').onValue;
  }

  // 데이터 쓰기
  Future<void> addPlant(Map<String, dynamic> plantData) async {
    try {
      print('Starting plant registration...');
      print('Original image path: ${plantData['imagePath']}');

      // 이미지를 Base64로 변환
      final String base64Image = await _storageService.convertImageToBase64(plantData['imagePath']);
      
      // 데이터베이스에 저장할 데이터 준비
      final Map<String, dynamic> dataToSave = {
        ...plantData,
        'imageBase64': base64Image, // Base64 이미지 데이터 저장
        'registeredAt': DateTime.now().toIso8601String(),
      };

      // Realtime Database에 저장
      await _database.child('plants').push().set(dataToSave);
      print('Plant data saved to database successfully');
    } catch (e, stackTrace) {
      print('식물 등록 오류: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // 데이터 업데이트
  Future<void> updatePlant(String key, Map<String, dynamic> plantData) async {
    await _database.child('plants').child(key).update(plantData);
  }

  // 데이터 삭제
  Future<void> deletePlant(String key) async {
    await _database.child('plants').child(key).remove();
  }
} 