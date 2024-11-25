import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/plant_health_model.dart';

class AIMonitoringService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<PlantHealthStatus> analyzePlantHealth(String plantId, String imageUrl) async {
    try {
      // Cloud Function 호출
      final result = await _functions
          .httpsCallable('analyzePlantHealth')
          .call({
        'plantId': plantId,
        'imageUrl': imageUrl,
      });

      return PlantHealthStatus.fromMap(result.data);
    } catch (e) {
      print('Plant health analysis failed: $e');
      return PlantHealthStatus(
        status: 'Unknown',
        timestamp: DateTime.now().toString(),
      );
    }
  }

  Future<void> saveAnalysisResult(String plantId, PlantHealthStatus status) async {
    // Firebase에 분석 결과 저장
    try {
      await _functions
          .httpsCallable('saveHealthAnalysis')
          .call({
        'plantId': plantId,
        'status': status.toMap(),
      });
    } catch (e) {
      print('Failed to save analysis result: $e');
    }
  }
} 