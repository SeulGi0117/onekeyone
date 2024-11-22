import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NongsaroApiService {
  final String apiKey = dotenv.env['NONGSARO_API_KEY'] ?? '';
  final String baseUrl = 'http://api.nongsaro.go.kr/service/garden';

  Future<Map<String, dynamic>?> getPlantDetails(String plantName, {String? scientificName}) async {
    try {
      // 1단계: gardenList API로 학명 검색
      final listParams = {
        'apiKey': apiKey,
        // 'sType': 'plntzrNm',  // 학명으로 검색
        'sType': 'plntbneNm',  // 학명으로 검색
        'sText': scientificName ?? plantName,
        'pageNo': '1',
        'numOfRows': '10',
      };

      print('1단계 - gardenList 요청: ${_buildQueryString(listParams)}');
      
      final listResponse = await http.get(
        Uri.parse('$baseUrl/gardenList?${_buildQueryString(listParams)}')
      );

      print('1단계 - 응답 코드: ${listResponse.statusCode}');
      print('1단계 - 응답 내용: ${listResponse.body}');

      if (listResponse.statusCode != 200) {
        throw Exception('gardenList API 호출 실패');
      }

      final listDocument = XmlDocument.parse(listResponse.body);
      
      // 응답 결과 확인
      final resultCode = listDocument.findAllElements('resultCode').first.text;
      if (resultCode != '00') {
        final resultMsg = listDocument.findAllElements('resultMsg').first.text;
        throw Exception('API 오류: $resultMsg');
      }

      // item 태그 찾기
      final items = listDocument.findAllElements('item').toList();
      print('1단계 - 검색된 항목 수: ${items.length}');

      String? cntntsNo;
      String? plantKoreanName;

      // 검색된 모든 항목 출력
      for (var item in items) {
        final itemPlntzrNm = _getElementText(item, 'plntzrNm');
        final itemCntntsNo = _getElementText(item, 'cntntsNo');
        final itemCntntsSj = _getElementText(item, 'cntntsSj');
        final itemRtnFileSeCode = _getElementText(item, 'rtnFileSeCode');
        final itemRtnOrginlFileNm = _getElementText(item, 'rtnOrginlFileNm');
        final itemRtnStreFileNm = _getElementText(item, 'rtnStreFileNm');
        
        print('검색 결과 항목:');
        print('- 학명: $itemPlntzrNm');
        print('- 컨텐츠번호: $itemCntntsNo');
        print('- 식물명: $itemCntntsSj');
        print('- 파일구분코드: $itemRtnFileSeCode');
        print('- 원본파일명: $itemRtnOrginlFileNm');
        print('- 저장파일명: $itemRtnStreFileNm');
        print('----------------------------------------');
        
        // 학명이 일치하는 항목 찾기
        if (itemPlntzrNm.toLowerCase().trim() == (scientificName ?? plantName).toLowerCase().trim()) {
          cntntsNo = itemCntntsNo;
          plantKoreanName = itemCntntsSj;
          print('일치하는 항목 발견 - 컨텐츠번호: $cntntsNo, 식물명: $plantKoreanName');
          break;
        }
      }

      if (cntntsNo == null) {
        print('식물을 찾을 수 없음: ${scientificName ?? plantName}');
        return null;
      }

      // 2단계: gardenDtl API로 상세 정보 조회
      final detailParams = {
        'apiKey': apiKey,
        'cntntsNo': cntntsNo,
      };

      print('2단계 - gardenDtl 요청: ${_buildQueryString(detailParams)}');

      final detailResponse = await http.get(
        Uri.parse('$baseUrl/gardenDtl?${_buildQueryString(detailParams)}')
      );

      print('2단계 - 응답 코드: ${detailResponse.statusCode}');
      print('2단계 - 응답 내용: ${detailResponse.body}');

      if (detailResponse.statusCode != 200) {
        throw Exception('gardenDtl API 호출 실패');
      }

      final detailDocument = XmlDocument.parse(detailResponse.body);
      final detailItems = detailDocument.findAllElements('item');
      
      if (detailItems.isEmpty) {
        print('상세 정보 없음');
        return null;
      }

      final detailItem = detailItems.first;

      // 상세 정보 매핑
      return {
        'koreanName': _getElementText(detailItem, 'cntntsSj'),
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
        'imageUrl': _getElementText(detailItem, 'mainImgUrl'),
      };
    } catch (e) {
      print('API 호출 오류: $e');
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
