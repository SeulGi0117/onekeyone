import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_database/firebase_database.dart';

class NongsaroApiService {
  final String apiKey = dotenv.env['NONGSARO_API_KEY'] ?? '';
  final String baseUrl = 'http://api.nongsaro.go.kr/service/garden';

  // 1단계: 식물 목록 가져와서 DB에 저장
  Future<void> fetchAndSavePlantList() async {
    try {
      print('1단계: 식물 목록 가져오기 시작...');
      
      final listParams = {
        'apiKey': apiKey,
        'pageNo': '1',
        'numOfRows': '217',
      };

      final listResponse = await http.get(
        Uri.parse('$baseUrl/gardenList?${_buildQueryString(listParams)}')
      );

      if (listResponse.statusCode == 200) {
        final listDocument = XmlDocument.parse(listResponse.body);
        final items = listDocument.findAllElements('item');

        final databaseRef = FirebaseDatabase.instance.ref();
        final plantsListRef = databaseRef.child('nongsaroPlantsList');

        for (var item in items) {
          final contentNo = _getElementText(item, 'cntntsNo');
          final plantName = _getElementText(item, 'cntntsSj');

          await plantsListRef.child(contentNo).set({
            'contentNo': contentNo,
            'plantName': plantName,
          });
        }
        print('1단계 완료: 식물 목록 저장 성공');
      }
    } catch (e) {
      print('1단계 오류: $e');
      rethrow;
    }
  }

  // 2단계: 각 식물의 학명 가져와서 DB에 추가
  Future<void> fetchAndSaveScientificNames() async {
    try {
      print('2단계: 학명 정보 가져오기 시작...');
      
      final databaseRef = FirebaseDatabase.instance.ref();
      final plantsListRef = databaseRef.child('nongsaroPlantsList');
      final snapshot = await plantsListRef.get();

      if (!snapshot.exists) throw Exception('식물 목록이 없습니다');

      Map<dynamic, dynamic> plants = snapshot.value as Map<dynamic, dynamic>;

      for (var contentNo in plants.keys) {
        final detailParams = {
          'apiKey': apiKey,
          'cntntsNo': contentNo.toString(),
        };

        final detailResponse = await http.get(
          Uri.parse('$baseUrl/gardenDtl?${_buildQueryString(detailParams)}')
        );

        if (detailResponse.statusCode == 200) {
          final detailDocument = XmlDocument.parse(detailResponse.body);
          final detailItems = detailDocument.findAllElements('item');

          if (detailItems.isNotEmpty) {
            final detailItem = detailItems.first;
            final scientificName = _getElementText(detailItem, 'plntbneNm');

            await plantsListRef.child(contentNo.toString()).update({
              'plntbneNm': scientificName,
            });
          }
        }
        await Future.delayed(Duration(milliseconds: 100));
      }
      print('2단계 완료: 학명 정보 저장 성공');
    } catch (e) {
      print('2단계 오류: $e');
      rethrow;
    }
  }

  // 3단계: 폴더 이름을 학명으로 변경
  Future<void> renameFoldersToScientificNames() async {
    try {
      print('3단계: 폴더 이름 변경 시작...');
      
      final databaseRef = FirebaseDatabase.instance.ref();
      final plantsListRef = databaseRef.child('nongsaroPlantsList');
      final snapshot = await plantsListRef.get();

      if (!snapshot.exists) throw Exception('식물 목록이 없습니다');

      Map<dynamic, dynamic> plants = snapshot.value as Map<dynamic, dynamic>;

      for (var contentNo in plants.keys) {
        final plantData = plants[contentNo];
        final scientificName = plantData['plntbneNm'];
        
        if (scientificName != null && scientificName.isNotEmpty) {
          // 새 경로에 데이터 저장
          await plantsListRef.child(scientificName).set(plantData);
          // 기존 데이터 삭제
          await plantsListRef.child(contentNo.toString()).remove();
        }
      }
      print('3단계 완료: 폴더 이름 변경 성공');
    } catch (e) {
      print('3단계 오류: $e');
      rethrow;
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

  // getPlantDetails 메서드 추가
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

      // 입력받은 식물 이름과 일치하는 데이터 찾기
      for (var scientificNameKey in plants.keys) {
        final plantData = plants[scientificNameKey];
        if (plantData['plantName'] == plantName) {
          return {
            'koreanName': plantData['plantName'],
            'scientificName': plantData['plntbneNm'],
            'contentNo': plantData['contentNo'],
          };
        }
      }

      return null;
    } catch (e) {
      print('식물 정보 조회 오류: $e');
      return null;
    }
  }
}
