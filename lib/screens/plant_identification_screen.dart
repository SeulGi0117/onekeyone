import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/plant_identification_service.dart';
import '../screens/plant_detail_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import '../services/database_service.dart';
import '../services/nongsaro_api_service.dart';

class PlantIdentificationScreen extends StatefulWidget {
  @override
  _PlantIdentificationScreenState createState() =>
      _PlantIdentificationScreenState();
}

class _PlantIdentificationScreenState extends State<PlantIdentificationScreen> {
  final ImagePicker _picker = ImagePicker();
  final DatabaseService _databaseService = DatabaseService();
  final NongsaroApiService _apiService = NongsaroApiService();

  String? selectedImagePath;

  bool isAnalyzing = false;

  List<Map<String, dynamic>>? analysisResults;

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(source: source);

      if (photo != null) {
        setState(() {
          selectedImagePath = photo.path;

          isAnalyzing = true;
        });

        // AI 분석 중 팝업 표시

        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              child: Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.file(
                      File(photo.path),
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'AI가 식물을 분석 중이에요!',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
            );
          },
        );

        final plantService = PlantIdentificationService();

        final result = await plantService.identifyPlant(photo.path);

        // 분석 완료 후 팝업 닫기

        if (!mounted) return;

        Navigator.of(context).pop();

        if (result['result'] != null &&
            result['result']['classification'] != null &&
            result['result']['classification']['suggestions'] != null) {
          setState(() {
            analysisResults = List<Map<String, dynamic>>.from(
              result['result']['classification']['suggestions'].map((suggestion) => {
                'name': suggestion['name'] ?? '',
                'probability': suggestion['probability'] ?? 0.0,
                'plantInfo': suggestion['plantInfo'] ?? {},
              }),
            );
            isAnalyzing = false;
          });

          // 농사로 API에서 추가 정보 가져오기
          if (analysisResults != null && analysisResults!.isNotEmpty) {
            try {
              final plantInfo = await _apiService.getPlantDetails(
                analysisResults![0]['name'],
                scientificName: analysisResults![0]['name'],
              );
              
              if (plantInfo != null) {
                setState(() {
                  analysisResults![0]['plantInfo'] = plantInfo;
                });
              }
            } catch (e) {
              print('농사로 API 정보 조회 실패: $e');
            }
          }
        }
      }
    } catch (e) {
      print('에러 발생: $e');

      if (!mounted) return;
      Navigator.of(context).pop(); // 에러 발생 시 팝업 닫기

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().contains('Exception:') 
              ? e.toString().replaceAll('Exception: ', '') 
              : '식물 인식 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<Map<String, String?>> getWikipediaInfo(String plantName) async {
    try {
      // 영문 위키피디아 API 호출
      final enResponse = await http.get(
        Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$plantName'),
      );
      
      // 한국어 위키피디아 API 호출
      final krResponse = await http.get(
        Uri.parse('https://ko.wikipedia.org/api/rest_v1/page/summary/$plantName'),
      );
      
      Map<String, String?> result = {
        'image': null,
        'koreanName': null,
      };
      
      if (enResponse.statusCode == 200) {
        final enData = json.decode(enResponse.body);
        result['image'] = enData['thumbnail']?['source'];
      }
      
      if (krResponse.statusCode == 200) {
        final krData = json.decode(krResponse.body);
        result['koreanName'] = krData['title'];
      }
      
      return result;
    } catch (e) {
      print('Wikipedia API 에러: $e');
      return {'image': null, 'koreanName': null};
    }
  }
 
  Future<void> _registerPlant(Map<String, dynamic> plantData) async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // 식물 정보를 Firebase에 저장
      await _databaseService.addPlant({
        'name': plantData['name'],
        'scientificName': plantData['name'], // Plant.id는 학명을 반환합니다
        'imagePath': plantData['imagePath'],
        'probability': plantData['probability'],
        'registeredAt': DateTime.now().toIso8601String(),
        'lastWatered': DateTime.now().toIso8601String(),
        'wateringInterval': 7, // 기본값으로 7일 설정
        'status': 'healthy',
      });

      if (!mounted) return;
      
      // 로딩 다이얼로그 닫기
      Navigator.pop(context);
      
      // 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('식물이 성공적으로 등록되었습니다!')),
      );

      // 홈 화면으로 이동
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      // 로딩 다이얼로그 닫기
      Navigator.pop(context);
      
      print('식물 등록 오류: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('식물 등록 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPlantInfo(BuildContext context, Map<String, dynamic> result) async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Plant.id가 예측한 식물 이름으로 농사로 API에서 정보 가져오기
      final plantInfo = await _apiService.getPlantDetails(
        result['name'],
        scientificName: result['name'], // Plant.id는 학명을 반환
      );

      // 로딩 다이얼로그 닫기
      if (!mounted) return;
      Navigator.pop(context);

      if (plantInfo != null) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              child: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppBar(
                        title: Text('식물 정보'),
                        leading: IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      if (plantInfo['images'] != null && 
                          (plantInfo['images'] as List).isNotEmpty)
                        Container(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: (plantInfo['images'] as List).length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    plantInfo['images'][index],
                                    width: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI 분석 결과',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('예측 정확도: ${(result['probability'] * 100).toStringAsFixed(1)}%'),
                            SizedBox(height: 16),
                            _buildInfoSection('기본 정보', [
                              _buildInfoRow('한글명', plantInfo['koreanName'] ?? '-'),
                              _buildInfoRow('영문명', plantInfo['englishName'] ?? '-'),
                              _buildInfoRow('학명', plantInfo['scientificName'] ?? '-'),
                              _buildInfoRow('과명', plantInfo['familyName'] ?? '-'),
                              _buildInfoRow('원산지', plantInfo['origin'] ?? '-'),
                            ]),
                            _buildInfoSection('생육 정보', [
                              _buildInfoRow('성장 높이', plantInfo['growthHeight'] ?? '-'),
                              _buildInfoRow('성장 너비', plantInfo['growthWidth'] ?? '-'),
                              _buildInfoRow('잎 특성', plantInfo['leafInfo'] ?? '-'),
                              _buildInfoRow('꽃 특성', plantInfo['flowerInfo'] ?? '-'),
                            ]),
                            _buildInfoSection('관리 방법', [
                              _buildInfoRow('관리 난이도', plantInfo['managementLevel'] ?? '-'),
                              _buildInfoRow('빛 요구도', plantInfo['lightDemand'] ?? '-'),
                              _buildInfoRow('생육 온도', plantInfo['temperature']['growth'] ?? '-'),
                              _buildInfoRow('겨울 최저온도', plantInfo['temperature']['winter'] ?? '-'),
                              _buildInfoRow('습도', plantInfo['humidity'] ?? '-'),
                            ]),
                            _buildInfoSection('물 주기', [
                              _buildInfoRow('봄', plantInfo['waterCycle']['spring'] ?? '-'),
                              _buildInfoRow('여름', plantInfo['waterCycle']['summer'] ?? '-'),
                              _buildInfoRow('가을', plantInfo['waterCycle']['autumn'] ?? '-'),
                              _buildInfoRow('겨울', plantInfo['waterCycle']['winter'] ?? '-'),
                            ]),
                            if (plantInfo['specialManagement']?.isNotEmpty ?? false)
                              _buildInfoSection('특별 관리', [
                                Text(plantInfo['specialManagement']),
                              ]),
                            if (plantInfo['toxicity']?.isNotEmpty ?? false)
                              _buildInfoSection('독성 정보', [
                                Text(plantInfo['toxicity']),
                              ]),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: Text(
                                  '이 식물로 등록하기',
                                  style: TextStyle(color: Colors.white),
                                ),
                                onPressed: () {
                                  Navigator.pop(context); // 다이얼로그 닫기
                                  _registerPlant({
                                    'name': result['name'],
                                    'imagePath': selectedImagePath,
                                    'probability': result['probability'].toString(),
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('식물 정보를 찾을 수 없습니다')),
        );
      }
    } catch (e) {
      print('식물 정보 로딩 오류: $e');
      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('식물 정보를 불러오는 중 오류가 발생했습니다')),
      );
    }
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        SizedBox(height: 8),
        ...children,
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResult() {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI 식물 분석'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(selectedImagePath!),
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            if (analysisResults != null)
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: analysisResults!.length,
                itemBuilder: (context, index) {
                  final result = analysisResults![index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ExpansionTile(
                      leading: FutureBuilder<Map<String, String?>>(
                        future: getWikipediaInfo(result['name']),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!['image'] != null) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                snapshot.data!['image']!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            );
                          }
                          return Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[300],
                            child: Icon(Icons.image_not_supported),
                          );
                        },
                      ),
                      title: Text(
                        result['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      subtitle: Text(
                        '유사도: ${(result['probability'] * 100).toStringAsFixed(1)}%',
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  child: Text('식물 정보 보기'),
                                  onPressed: () => _showPlantInfo(context, result),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: Text(
                                    '이 식물로 등록하기',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  onPressed: () {
                                    _registerPlant({
                                      'name': result['name'],
                                      'imagePath': selectedImagePath,
                                      'probability': result['probability'].toString(),
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (selectedImagePath != null && !isAnalyzing) {
      return _buildAnalysisResult();
    }

    // 초기 화면

    return Scaffold(
      appBar: AppBar(
        title: Text('Plant care'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '카메라로 식물을 촬영하거나, 갤러리에서 식물의 사진을 선택하여\n당신의 반려식물을 등록하세요!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onPressed: () => _getImage(ImageSource.camera),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '식물 사진 촬영하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onPressed: () => _getImage(ImageSource.gallery),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '갤러리에서 사진 선택하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
