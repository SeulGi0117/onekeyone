import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PlantIdentificationService {
  final String apiKey = dotenv.env['PLANT_ID_API_KEY'] ?? '';
  final String apiUrl = 'https://plant.id/api/v3/identification';

  Future<Map<String, dynamic>> identifyPlant(String imagePath) async {
    try {
      if (apiKey.isEmpty) {
        throw Exception('Plant.id API 키가 설정되지 않았습니다.');
      }

      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      var headers = {
        'Api-Key': apiKey,
        'Content-Type': 'application/json'
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: json.encode({
          "images": [base64Image],
          "similar_images": true,
          "classification_level": "species",
          "health": "all"
        }),
      );

      print('Plant.id API 응답 상태 코드: ${response.statusCode}');
      print('Plant.id API 응답 본문: ${response.body}');

      if (response.statusCode == 429) {
        throw Exception('API 호출 한도가 초과되었습니다. 나중에 다시 시도해주세요.');
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('식물 인식 서버 오류 (상태 코드: ${response.statusCode})');
      }

      final result = json.decode(response.body);
      
      if (result == null || !result.containsKey('result')) {
        throw Exception('API 응답 형식이 올바르지 않습니다.');
      }

      final suggestions = result['result']['classification']['suggestions'];
      if (suggestions == null || suggestions.isEmpty) {
        throw Exception('식물을 인식할 수 없습니다. 다른 사진을 시도해보세요.');
      }

      // 응답 구조를 농사로 API와 유사하게 변환
      return {
        'result': {
          'classification': {
            'suggestions': suggestions.map((suggestion) => {
              'name': suggestion['name'] ?? '',
              'probability': suggestion['probability'] ?? 0.0,
              'plantInfo': {
                'koreanName': suggestion['name'] ?? '',
                'scientificName': suggestion['name'] ?? '',
                'englishName': suggestion['name'] ?? '',
                'familyName': suggestion['family']?['name'] ?? '',
                'origin': '',
                'growthHeight': '',
                'growthWidth': '',
                'leafInfo': '',
                'flowerInfo': '',
                'managementLevel': '',
                'lightDemand': '',
                'temperature': {
                  'growth': '',
                  'winter': '',
                },
                'humidity': '',
                'waterCycle': {
                  'spring': '',
                  'summer': '',
                  'autumn': '',
                  'winter': '',
                },
                'specialManagement': '',
                'toxicity': '',
              },
            }).toList(),
          }
        }
      };
    } catch (e) {
      print('식물 인식 중 오류 발생: $e');
      rethrow;
    }
  }
}
