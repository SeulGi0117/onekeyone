import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NongsaroApiService {
  final String apiKey = dotenv.env['NONGSARO_API_KEY'] ?? '';
  final String baseUrl = 'http://api.nongsaro.go.kr/service/garden';

  Future<Map<String, dynamic>?> getPlantDetails(String plantName, {String? scientificName}) async {
    try {
      // 1. 먼저 한글 이름으로 검색
      Map<String, dynamic>? result = await _searchPlant(plantName);
      
      // 2. 한글 이름으로 검색 실패시 학명으로 검색
      if (result == null && scientificName != null) {
        result = await _searchPlant(scientificName);
      }

      return result;
    } catch (e) {
      print('농사로 API 오류: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _searchPlant(String searchText) async {
    try {
      final searchParams = {
        'apiKey': apiKey,
        'sText': searchText,
        'pageNo': '1',
        'numOfRows': '10',
      };

      // 한글 이름과 학명 모두로 검색
      final searchResponse = await http.get(
        Uri.parse('$baseUrl/gardenList?${_buildQueryString(searchParams)}')
      );

      if (searchResponse.statusCode != 200) {
        throw Exception('식물 검색 실패');
      }

      final searchDocument = XmlDocument.parse(searchResponse.body);
      final items = searchDocument.findAllElements('item');
      
      String? cntntsNo;
      for (var item in items) {
        final itemName = _getElementText(item, 'cntntsSj');
        final itemScientificName = _getElementText(item, 'plntzrNm');
        
        // 한글 이름이나 학명이 일치하는 경우
        if (itemName.contains(searchText) || itemScientificName.contains(searchText)) {
          cntntsNo = _getElementText(item, 'cntntsNo');
          break;
        }
      }

      if (cntntsNo == null) return null;

      // 상세 정보 조회
      final detailParams = {
        'apiKey': apiKey,
        'cntntsNo': cntntsNo,
      };

      final detailResponse = await http.get(
        Uri.parse('$baseUrl/gardenDtl?${_buildQueryString(detailParams)}')
      );

      if (detailResponse.statusCode != 200) {
        throw Exception('상세 정보 조회 실패');
      }

      final detailDocument = XmlDocument.parse(detailResponse.body);
      final detailItem = detailDocument.findAllElements('item').first;

      return {
        'koreanName': _getElementText(detailItem, 'cntntsSj'),
        'scientificName': _getElementText(detailItem, 'plntzrNm'),
        'englishName': _getElementText(detailItem, 'plntbneNm'),
        'familyName': _getElementText(detailItem, 'fmlCodeNm'),
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
      };
    } catch (e) {
      print('식물 검색 오류: $e');
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
