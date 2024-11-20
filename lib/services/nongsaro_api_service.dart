import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NongsaroApiService {
  final String apiKey = dotenv.env['NONGSARO_API_KEY'] ?? '';
  final String baseUrl = 'http://api.nongsaro.go.kr/service/garden';

  Future<Map<String, dynamic>?> getPlantDetails(String plantName, {String? scientificName, String? englishName}) async {
    try {
      // 1. 학명으로 검색 (sType을 'sPlntzrNm'으로 설정)
      final searchParams = {
        'apiKey': apiKey,
        'sType': 'sPlntzrNm',  // 학명으로 검색
        'sText': scientificName ?? plantName,  // 학명이 있으면 학명으로, 없으면 일반 이름으로 검색
        'pageNo': '1',
        'numOfRows': '10',
      };

      print('검색 파라미터: $searchParams'); // 디버깅용

      final searchResponse = await http.get(
        Uri.parse('$baseUrl/gardenList?${_buildQueryString(searchParams)}')
      );

      print('검색 응답 상태 코드: ${searchResponse.statusCode}'); // 디버깅용
      print('검색 응답 내용: ${searchResponse.body}'); // 디버깅용

      if (searchResponse.statusCode != 200) {
        throw Exception('식물 검색 실패 (상태 코드: ${searchResponse.statusCode})');
      }

      final searchDocument = XmlDocument.parse(searchResponse.body);
      
      // 응답 코드 확인
      final resultCode = searchDocument.findAllElements('resultCode').first.text;
      if (resultCode != '00') {
        final resultMsg = searchDocument.findAllElements('resultMsg').first.text;
        throw Exception('API 오류: $resultMsg (코드: $resultCode)');
      }

      final items = searchDocument.findAllElements('item');
      
      String? cntntsNo;
      for (var item in items) {
        final itemScientificName = _getElementText(item, 'plntzrNm');
        
        // 학명이 정확히 일치하는 항목 찾기
        if (itemScientificName.toLowerCase() == (scientificName ?? plantName).toLowerCase()) {
          cntntsNo = _getElementText(item, 'cntntsNo');
          break;
        }
      }

      if (cntntsNo == null) {
        print('식물을 찾을 수 없음: ${scientificName ?? plantName}'); // 디버깅용
        return null;
      }

      // 2. 상세 정보 조회
      final detailParams = {
        'apiKey': apiKey,
        'cntntsNo': cntntsNo,
      };

      final detailResponse = await http.get(
        Uri.parse('$baseUrl/gardenDtl?${_buildQueryString(detailParams)}')
      );

      print('상세 정보 응답 상태 코드: ${detailResponse.statusCode}'); // 디버깅용
      print('상세 정보 응답 내용: ${detailResponse.body}'); // 디버깅용

      if (detailResponse.statusCode != 200) {
        throw Exception('상세 정보 조회 실패');
      }

      final detailDocument = XmlDocument.parse(detailResponse.body);
      final detailItems = detailDocument.findAllElements('item');
      
      if (detailItems.isEmpty) {
        print('상세 정보 없음'); // 디버깅용
        return null;
      }

      final detailItem = detailItems.first;

      return {
        'koreanName': _getElementText(detailItem, 'cntntsSj'),
        'scientificName': _getElementText(detailItem, 'plntzrNm'),
        'englishName': _getElementText(detailItem, 'plntbneNm'),
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
      };
    } catch (e) {
      print('식물 검색 오류: $e'); // 디버깅용
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
