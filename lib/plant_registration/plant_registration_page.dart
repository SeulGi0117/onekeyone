import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/plant_identification_service.dart';
import '../widgets/plant_identification_loading_screen.dart';
import 'plant_identification_result_page.dart';

class PlantRegistrationPage extends StatefulWidget {
  @override
  _PlantRegistrationPageState createState() => _PlantRegistrationPageState();
}

class _PlantRegistrationPageState extends State<PlantRegistrationPage> {
  final ImagePicker _picker = ImagePicker();
  final PlantIdentificationService _plantService = PlantIdentificationService();

  Future<void> _processImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return PlantIdentificationLoadingScreen(imagePath: image.path);
        },
      );

      try {
        final plantInfo = await _plantService.identifyPlant(image.path);
        Navigator.of(context).pop(); // 로딩 화면 닫기

        // 결과 페이지로 이동
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PlantIdentificationResultPage(
              imagePath: image.path,
              plantResults: List<Map<String, dynamic>>.from(plantInfo['suggestions']),
            ),
          ),
        );
      } catch (e) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('식물 식별 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plant care'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '카메라로 식물을 촬영하거나, 갤러리에서 식물의 사진을 선택하여\n당신의 반려식물을 등록하세요!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _processImage(ImageSource.camera),
              icon: Icon(Icons.camera_alt),
              label: Text('식물 사진 촬영하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _processImage(ImageSource.gallery),
              icon: Icon(Icons.photo_library),
              label: Text('갤러리에서 사진 선택하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
