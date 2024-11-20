import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class PlantIdentificationService {
  final String apiKey = 'A5sz7vlrfVMKSPAvy1mooIpj4A4RZ4XoL77jQyfzVOAsdvqrIi';
  final String apiUrl = 'https://plant.id/api/v3/identification';

  Future<Map<String, dynamic>> identifyPlant(String imagePath) async {
    try {
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = json.decode(response.body);
        
        if (result['result']?.containsKey('classification')) {
          final suggestions = result['result']['classification']['suggestions'];
          return {
            'result': {
              'classification': {
                'suggestions': suggestions.map((suggestion) => {
                  'name': suggestion['name'],
                  'scientific_name': suggestion['name'],
                  'probability': suggestion['probability'],
                }).toList(),
              }
            }
          };
        }
      }
      
      print('Plant.id API 응답: ${response.body}');
      throw Exception('Plant.id API 응답 오류: ${response.statusCode}');
    } catch (e) {
      print('식물 인식 중 오류 발생: $e');
      rethrow;
    }
  }
}
