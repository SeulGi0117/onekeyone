import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/plant_identification_service.dart';
import '../screens/plant_detail_screen.dart';

class PlantIdentificationScreen extends StatefulWidget {
  @override
  _PlantIdentificationScreenState createState() =>
      _PlantIdentificationScreenState();
}

class _PlantIdentificationScreenState extends State<PlantIdentificationScreen> {
  final ImagePicker _picker = ImagePicker();

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

  @override
  Widget build(BuildContext context) {
    if (selectedImagePath != null && !isAnalyzing) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('식물 분석'),
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
                  'AI가 당신이 촬영한 사진을 기반으로\n식물을 분석해봤어요!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(selectedImagePath!),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(height: 16),
                if (analysisResults != null && analysisResults!.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            analysisResults![0]['name'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '유사도: ${(analysisResults![0]['probability'] * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  child: Text('식물 정보 보기'),
                                  onPressed: () {
                                    // 식물 정보 보기 로직
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
                                    // 식물 등록 로직
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
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
