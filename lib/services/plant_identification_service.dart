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

      var request = http.Request('POST', Uri.parse(apiUrl));

      request.body = json.encode({
        "images": ["data:image/jpeg;base64,$base64Image"],
        "similar_images": true,
        "classification_level": "species"
      });

      request.headers.addAll(headers);

      var streamedResponse = await request.send();
      var responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        return json.decode(responseBody);
      } else {
        throw Exception('Plant.id API 오류: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      print('식물 인식 중 오류 발생: $e');
      throw Exception('식물 인식 실패: $e');
    }
  }
}
