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
            analysisResults = List<Map<String, dynamic>>.from(result['result']
                    ['classification']['suggestions']
                .map((suggestion) => {
                      'name': suggestion['name'],
                      'probability': suggestion['probability'],
                    }));

            isAnalyzing = false;
          });
        }
      }
    } catch (e) {
      print('에러 발생: $e');

      if (!mounted) return;

      Navigator.of(context).pop(); // 에러 발생 시 팝업 닫기

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('식물 인식 중 오류가 발생했습니다.')),
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

  Widget _buildAnalysisResult() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('AI 식물 분석'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI가 당신이 촬영한 사진을 기반으로 식물을 분석해봤어요!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(selectedImagePath!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(height: 16),
              if (analysisResults != null && analysisResults!.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: analysisResults!.length,
                  itemBuilder: (context, index) {
                    final result = analysisResults![index];
                    return FutureBuilder<Map<String, String?>>(
                      future: getWikipediaInfo(result['name'].toString().replaceAll(' ', '_')),
                      builder: (context, snapshot) {
                        return Card(
                          child: ExpansionTile(
                            leading: snapshot.hasData && snapshot.data!['image'] != null
                                ? SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        snapshot.data!['image']!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Icon(Icons.image_not_supported),
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                            title: FutureBuilder<Map<String, dynamic>?>(
                              future: _apiService.getPlantDetails(result['name']),
                              builder: (context, apiSnapshot) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      result['name'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    if (apiSnapshot.hasData && apiSnapshot.data?['koreanName'] != null)
                                      Text(
                                        apiSnapshot.data!['koreanName'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      )
                                    else if (snapshot.hasData && snapshot.data!['koreanName'] != null)
                                      Text(
                                        snapshot.data!['koreanName']!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    Text(
                                      '유사도: ${(result['probability'] * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                );
                              },
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        child: Text('식물 정보 보기'),
                                        onPressed: () async {
                                          final plantInfo = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PlantDetailScreen(
                                                plantName: result['name'],
                                                imagePath: selectedImagePath!,
                                                probability: result['probability'].toString(),
                                                scientificName: result['scientific_name'],
                                              ),
                                            ),
                                          );
                                          if (plantInfo != null) {
                                            Navigator.pop(context, plantInfo);
                                          }
                                        },
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
                    );
                  },
                ),
            ],
          ),
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
