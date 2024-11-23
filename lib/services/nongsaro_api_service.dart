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

            // 모든 정보를 가져오되, 빈 값은 제외
            Map<String, dynamic> details = {};

            // 기본 정보
            _addIfNotEmpty(details, 'koreanName', nongsaroPlantName);
            _addIfNotEmpty(details, 'scientificName', _getElementText(detailItem, 'plntbneNm'));
            _addIfNotEmpty(details, 'englishName', _getElementText(detailItem, 'plntzrNm'));
            _addIfNotEmpty(details, 'familyCode', _getElementText(detailItem, 'fmlCodeNm')); // 과명 코드
            _addIfNotEmpty(details, 'distributionName', _getElementText(detailItem, 'distbNm'));
            _addIfNotEmpty(details, 'origin', _getElementText(detailItem, 'orgplceInfo'));
            _addIfNotEmpty(details, 'classification', _getElementText(detailItem, 'clCodeNm')); // 분류
            _addIfNotEmpty(details, 'growthType', _getElementText(detailItem, 'grwhstleCodeNm')); // 생육형태
            _addIfNotEmpty(details, 'ecologyType', _getElementText(detailItem, 'eclgyCodeNm')); // 생태 정보
            _addIfNotEmpty(details, 'smell', _getElementText(detailItem, 'smellCodeNm')); // 냄새
            _addIfNotEmpty(details, 'leafPattern', _getElementText(detailItem, 'lefmrkCodeNm')); // 잎무늬

            // 생육 정보
            Map<String, dynamic> growthInfo = {};
            _addIfNotEmpty(growthInfo, 'height', _getElementText(detailItem, 'growthHgInfo'));
            _addIfNotEmpty(growthInfo, 'width', _getElementText(detailItem, 'growthAraInfo'));
            if (growthInfo.isNotEmpty) {
              details['growthInfo'] = growthInfo;
            }

            // 관리 정보
            Map<String, dynamic> managementInfo = {};
            _addIfNotEmpty(managementInfo, 'level', _getElementText(detailItem, 'managelevelCodeNm'));
            _addIfNotEmpty(managementInfo, 'demand', _getElementText(detailItem, 'managedemanddoCodeNm')); // 관리요구도
            _addIfNotEmpty(managementInfo, 'special', _getElementText(detailItem, 'speclmanageInfo'));
            if (managementInfo.isNotEmpty) {
              details['managementInfo'] = managementInfo;
            }

            // 환경 정보
            Map<String, dynamic> environmentInfo = {};
            _addIfNotEmpty(environmentInfo, 'light', _getElementText(detailItem, 'lighttdemanddoCodeNm'));
            _addIfNotEmpty(environmentInfo, 'humidity', _getElementText(detailItem, 'hdCodeNm'));
            _addIfNotEmpty(environmentInfo, 'growthTemperature', _getElementText(detailItem, 'grwhTpCodeNm'));
            _addIfNotEmpty(environmentInfo, 'winterTemperature', _getElementText(detailItem, 'winterLwetTpCodeNm'));
            if (environmentInfo.isNotEmpty) {
              details['environmentInfo'] = environmentInfo;
            }

            // 물 주기 정보
            Map<String, dynamic> waterCycle = {};
            _addIfNotEmpty(waterCycle, 'spring', _getElementText(detailItem, 'watercycleSprngCodeNm'));
            _addIfNotEmpty(waterCycle, 'summer', _getElementText(detailItem, 'watercycleSummerCodeNm'));
            _addIfNotEmpty(waterCycle, 'autumn', _getElementText(detailItem, 'watercycleAutumnCodeNm'));
            _addIfNotEmpty(waterCycle, 'winter', _getElementText(detailItem, 'watercycleWinterCodeNm'));
            if (waterCycle.isNotEmpty) {
              details['waterCycle'] = waterCycle;
            }

            // 기능성 정보
            _addIfNotEmpty(details, 'functionInfo', _getElementText(detailItem, 'fncltyInfo'));
            
            // 병충해 관리 정보
            _addIfNotEmpty(details, 'pestControlInfo', _getElementText(detailItem, 'dlthtsManageInfo'));

            // 독성 정보
            _addIfNotEmpty(details, 'toxicity', _getElementText(detailItem, 'toxctyInfo'));

            // 배치 장소 정보 추가
            _addIfNotEmpty(details, 'placementLocation', _getElementText(detailItem, 'postngplaceCodeNm')); // 배치장소

            // 병충해 정보 추가
            _addIfNotEmpty(details, 'pestInfo', _getElementText(detailItem, 'dlthtsCodeNm')); // 병충해 정보

            // 이미지 URL 추가
            if (imageUrls.isNotEmpty) {
              details['images'] = imageUrls;
            }

            return details;
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

  void _addIfNotEmpty(Map<String, dynamic> map, String key, String value) {
    if (value.isNotEmpty) {
      // 독성 정보 번역
      if (key == 'toxicity' && value == 'All parts of plant are poisonous if ingested') {
        map[key] = '식물의 모든 부분은 섭취하면 독성이 있습니다.';
      } else {
        map[key] = value;
      }
    }
  }
}
