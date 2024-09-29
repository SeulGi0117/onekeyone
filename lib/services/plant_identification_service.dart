import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PlantIdentificationService {
  final String apiKey = 'A5sz7vlrfVMKSPAvy1mooIpj4A4RZ4XoL77jQyfzVOAsdvqrIi';
  final String apiUrl = 'https://api.plant.id/v2/identify';

  Future<Map<String, dynamic>> identifyPlant(String imagePath) async {
    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
    request.headers.addAll({
      'Content-Type': 'multipart/form-data',
      'Api-Key': apiKey,
    });

    request.files.add(await http.MultipartFile.fromPath('images', imagePath));
    request.fields['organs'] = 'leaf';
    request.fields['include'] = 'common_names,taxonomy,description';

    var response = await request.send();
    if (response.statusCode == 200) {
      var responseBody = await response.stream.bytesToString();
      var decodedResponse = json.decode(responseBody);
      return {
        'suggestions': decodedResponse['suggestions'].map((suggestion) => {
          'plant_name': suggestion['plant_name'],
          'probability': suggestion['probability'],
          'images': suggestion['similar_images'],
          'taxonomy': suggestion['plant_details']['taxonomy'],
          'description': suggestion['plant_details']['wiki_description']?['value'],
        }).toList(),
      };
    } else {
      throw Exception('Failed to identify plant');
    }
  }
}