import 'package:http/http.dart' as http;

import 'package:xml/xml.dart';

class NongsaroApiService {
  final String apiKey = '202410172YV65RKGC1W4ZMWO94TG';

  final String baseUrl = 'http://api.nongsaro.go.kr/service/garden';

  Future<Map<String, dynamic>?> getPlantDetails(String scientificName) async {
    try {
      // 1. 식물 검색 - 여러 검색 방법 시도
      String? cntntsNo;
      
      // 학명으로 검색
      cntntsNo = await _searchPlant(scientificName, 'plntzrNm');
      
      // 학명으로 검색 실패시 영문명으로 검색
      if (cntntsNo == null) {
        cntntsNo = await _searchPlant(scientificName, 'plntbneNm');
      }

      if (cntntsNo == null) return null;

      // 2. 상세 정보 조회
      final details = await _getPlantDetail(cntntsNo);
      if (details == null) return null;

      // 3. 이미지 URL 조회
      final images = await _getPlantImages(cntntsNo);

      // 4. 모든 정보 합치기
      return {
        ...details,
        'images': images,
      };
    } catch (e) {
      print('농사로 API 오류: $e');
      return null;
    }
  }

  Future<String?> _searchPlant(String searchText, String searchType) async {
    try {
      // 학명으로 검색
      final scientificParams = {
        'apiKey': apiKey,
        'sType': 'plntzrNm',     // 학명으로 검색
        'sText': searchText,
        'wordType': 'cntntsSj',
        'pageNo': '1',
        'numOfRows': '10',
      };

      var response = await http
          .get(Uri.parse('$baseUrl/gardenList?${_buildQueryString(scientificParams)}'));

      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');

        // 정확한 매칭 찾기
        for (var item in items) {
          final itemName = _getElementText(item, 'plntzrNm');
          if (itemName.toLowerCase() == searchText.toLowerCase()) {
            return _getElementText(item, 'cntntsNo');
          }
        }

        // 한글 이름으로 검색
        final koreanParams = {
          'apiKey': apiKey,
          'sType': 'sCntntsSj',
          'sText': searchText,
          'wordType': 'cntntsSj',
          'pageNo': '1',
          'numOfRows': '10',
        };

        response = await http
            .get(Uri.parse('$baseUrl/gardenList?${_buildQueryString(koreanParams)}'));

        if (response.statusCode == 200) {
          final document = XmlDocument.parse(response.body);
          final items = document.findAllElements('item');

          for (var item in items) {
            final itemName = _getElementText(item, 'cntntsSj');
            if (itemName.contains(searchText)) {
              return _getElementText(item, 'cntntsNo');
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('식물 검색 오류: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getPlantDetail(String cntntsNo) async {
    final params = {
      'apiKey': apiKey,
      'cntntsNo': cntntsNo,
    };

    final response = await http
        .get(Uri.parse('$baseUrl/gardenDtl?${_buildQueryString(params)}'));

    if (response.statusCode == 200) {
      final document = XmlDocument.parse(response.body);

      final item = document.findAllElements('item').first;

      return {
        'koreanName': _getElementText(item, 'cntntsSj'),
        'scientificName': _getElementText(item, 'plntzrNm'),
        'familyName': _getElementText(item, 'fmlCodeNm'),
        'englishName': _getElementText(item, 'plntbneNm'),
        'description': _getElementText(item, 'adviseInfo'),
        'origin': _getElementText(item, 'orgplceInfo'),
        'growthHeight': _getElementText(item, 'growthHgInfo'),
        'growthWidth': _getElementText(item, 'growthAraInfo'),
        'leafInfo': _getElementText(item, 'lefStleInfo'),
        'flowerInfo': _getElementText(item, 'flwrInfo'),
        'managementLevel': _getElementText(item, 'managelevelCodeNm'),
        'lightDemand': _getElementText(item, 'lighttdemanddoCodeNm'),
        'waterCycle': {
          'spring': _getElementText(item, 'watercycleSprngCodeNm'),
          'summer': _getElementText(item, 'watercycleSummerCodeNm'),
          'autumn': _getElementText(item, 'watercycleAutumnCodeNm'),
          'winter': _getElementText(item, 'watercycleWinterCodeNm'),
        },
        'temperature': {
          'growth': _getElementText(item, 'grwhTpCodeNm'),
          'winter': _getElementText(item, 'winterLwetTpCodeNm'),
        },
        'humidity': _getElementText(item, 'hdCodeNm'),
        'specialManagement': _getElementText(item, 'speclmanageInfo'),
        'toxicity': _getElementText(item, 'toxctyInfo'),
      };
    }

    return null;
  }

  Future<List<String>> _getPlantImages(String cntntsNo) async {
    final params = {
      'apiKey': apiKey,
      'cntntsNo': cntntsNo,
    };

    final response = await http
        .get(Uri.parse('$baseUrl/gardenFileList?${_buildQueryString(params)}'));

    if (response.statusCode == 200) {
      final document = XmlDocument.parse(response.body);

      final items = document.findAllElements('item');

      return items.map((item) => _getElementText(item, 'rtnFileUrl')).toList();
    }

    return [];
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
