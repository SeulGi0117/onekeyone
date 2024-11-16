import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // 데이터 읽기
  Stream<DatabaseEvent> getPlantData() {
    return _database.child('plants').onValue;
  }

  // 데이터 쓰기
  Future<void> addPlant(Map<String, dynamic> plantData) async {
    await _database.child('plants').push().set(plantData);
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