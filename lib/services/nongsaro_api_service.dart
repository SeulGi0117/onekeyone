import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_database/firebase_database.dart';

class NongsaroApiService {
  final String apiKey = dotenv.env['NONGSARO_API_KEY'] ?? '';
  final String baseUrl = 'http://api.nongsaro.go.kr/service/garden';

  Future<Map<String, dynamic>?> getPlantDetails(String plantName, {String? scientificName}) async {
    try {
      // Firebase에서 nongsaroPlantsList 데이터 가져오기
      final databaseRef = FirebaseDatabase.instance.ref();
      final plantsListRef = databaseRef.child('nongsaroPlantsList');
      final snapshot = await plantsListRef.get();

      if (!snapshot.exists) {
        throw Exception('저장된 식물 목록이 없습니다');
      }

      Map<dynamic, dynamic> plants = snapshot.value as Map<dynamic, dynamic>;

      // 학명을 Firebase 경로에 맞게 변환
      String searchName = (scientificName ?? '')
          .replaceAll('.', '_')
          .replaceAll('[', '_')
          .replaceAll(']', '_')
          .replaceAll('#', '_')
          .replaceAll(' ', '_')
          .replaceAll('(', '_')
          .replaceAll(')', '_')
          .replaceAll('/', '_')
          .replaceAll('\\', '_')
          .replaceAll(',', '_')
          .replaceAll('\'', '_')
          .replaceAll('"', '_');

      // 첫 번째 시도: 변환된 학명으로 검색
      var plantData = plants[searchName];

      // 두 번째 시도: 학명 뒤에 '_' 추가해서 검색
      if (plantData == null) {
        plantData = plants[searchName + '_'];
      }

      if (plantData != null) {
        final contentNo = plantData['contentNo'];
        final nongsaroPlantName = plantData['plantName']; // nongsaroPlantsList에서 가져온 한글명

        // 1. 상세 정보 가져오기
        final detailParams = <String, String>{
          'apiKey': apiKey,
          'cntntsNo': contentNo.toString(),
        };

        // 2. 이미지 파일 정보 가져오기
        final fileParams = <String, String>{
          'apiKey': apiKey,
          'cntntsNo': contentNo.toString(),
        };

        final detailResponse = await http.get(
            Uri.parse('$baseUrl/gardenDtl?${_buildQueryString(detailParams)}'));
        
        final fileResponse = await http.get(
            Uri.parse('$baseUrl/gardenFileList?${_buildQueryString(fileParams)}'));

        if (detailResponse.statusCode == 200) {
          final detailDocument = XmlDocument.parse(detailResponse.body);
          final detailItems = detailDocument.findAllElements('item');

          List<String> imageUrls = [];
          if (fileResponse.statusCode == 200) {
            final fileDocument = XmlDocument.parse(fileResponse.body);
            final fileItems = fileDocument.findAllElements('item');
            
            for (var fileItem in fileItems) {
              final fileUrl = _getElementText(fileItem, 'rtnFileUrl');
              if (fileUrl.isNotEmpty) {
                imageUrls.add(fileUrl);
              }
            }
          }

          if (detailItems.isNotEmpty) {
            final detailItem = detailItems.first;

            return {
              'koreanName': nongsaroPlantName, // nongsaroPlantsList에서 가져온 한글명 사용
              'scientificName': _getElementText(detailItem, 'plntbneNm'),
              'englishName': _getElementText(detailItem, 'plntzrNm'),
              'familyName': _getElementText(detailItem, 'fmlNm'),
              'origin': _getElementText(detailItem, 'orgplceInfo'),
              'growthHeight': _getElementText(detailItem, 'growthHgInfo'),
              'growthWidth': _getElementText(detailItem, 'growthAraInfo'),
              'leafInfo': _getElementText(detailItem, 'lefStleInfo'),
              'flowerInfo': _getElementText(detailItem, 'flwrInfo'),
              'managementLevel': _getElementText(detailItem, 'managelevelCodeNm'),
              'lightDemand': _getElementText(detailItem, 'lighttdemanddoCodeNm'),
              'waterCycle': {
                'spring': _getElementText(detailItem, 'watercycleSprngCodeNm'),
                'summer': _getElementText(detailItem, 'watercycleSummerCodeNm'),
                'autumn': _getElementText(detailItem, 'watercycleAutumnCodeNm'),
                'winter': _getElementText(detailItem, 'watercycleWinterCodeNm'),
              },
              'temperature': {
                'growth': _getElementText(detailItem, 'grwhTpCodeNm'),
                'winter': _getElementText(detailItem, 'winterLwetTpCodeNm'),
              },
              'humidity': _getElementText(detailItem, 'hdCodeNm'),
              'specialManagement': _getElementText(detailItem, 'speclmanageInfo'),
              'toxicity': _getElementText(detailItem, 'toxctyInfo'),
              'images': imageUrls, // 농사로 이미지 URL 목록 추가
            };
          }
        }
      }

      return null;
    } catch (e) {
      print('식물 정보 조회 오류: $e');
      return null;
    }
  }

  String _buildQueryString(Map<String, String> params) {
    return params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  String _getElementText(XmlElement item, String elementName) {
    try {
      return item.findElements(elementName).first.text;
    } catch (e) {
      return '';
    }
  }
}
