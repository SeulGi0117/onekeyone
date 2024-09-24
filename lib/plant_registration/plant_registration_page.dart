import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // image_picker 패키지 추가

class PlantRegistrationPage extends StatelessWidget {
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      // 사진이 선택되었을 때의 처리
      print('Photo taken: ${photo.path}');
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
              'Register the photo of your plant!\nYou can take a picture with the camera or select from the gallery.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              '카메라로 식물을 촬영하거나, 갤러리에서 식물의 사진을 선택하여\n당신의 반려식물을 등록하세요!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _takePhoto, // 카메라로 사진 촬영 기능 추가
              icon: Icon(Icons.camera_alt),
              label: Text('Take a photo of your plant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // 'primary'를 'backgroundColor'로 변경
                foregroundColor: Colors.white, // 'onPrimary'를 'foregroundColor'로 변경
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // 갤러리에서 사진 선택 기능 추가
              },
              icon: Icon(Icons.photo_library),
              label: Text('Select photos from your phone'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // 'primary'를 'backgroundColor'로 변경
                foregroundColor: Colors.white, // 'onPrimary'를 'foregroundColor'로 변경
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
