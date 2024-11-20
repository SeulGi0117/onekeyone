import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'dart:convert';

class PlantDiagnosisScreen extends StatefulWidget {
  @override
  _PlantDiagnosisScreenState createState() => _PlantDiagnosisScreenState();
}

class _PlantDiagnosisScreenState extends State<PlantDiagnosisScreen> {
  final ImagePicker _picker = ImagePicker();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  String? selectedImagePath;

  // 이미지를 Base64로 인코딩하는 함수
  Future<String> encodeImageToBase64(String imagePath) async {
    final File imageFile = File(imagePath);
    final List<int> imageBytes = await imageFile.readAsBytes();
    final String base64Image = base64Encode(imageBytes);
    return base64Image;
  }

  // Firebase에 이미지 업로드하는 함수
  Future<void> uploadImageToFirebase(String encodedImage) async {
    try {
      await _database.child('leaf_disease').push().set({
        'disease_image': encodedImage,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Firebase 업로드 에러: $e');
      throw e;
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          selectedImagePath = photo.path;
        });

        // 로딩 표시
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        try {
          // 이미지를 Base64로 인코딩
          final String encodedImage = await encodeImageToBase64(photo.path);
          
          // Firebase에 업로드
          await uploadImageToFirebase(encodedImage);

          // 로딩 다이얼로그 닫기
          if (!mounted) return;
          Navigator.of(context).pop();

          // 성공 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('식물 잎 사진이 업로드되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          // 로딩 다이얼로그 닫기
          if (!mounted) return;
          Navigator.of(context).pop();

          // 에러 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('업로드 중 오류가 발생했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('카메라 에러: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('사진 촬영 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.local_hospital,
            size: 64,
            color: Colors.green,
          ),
          SizedBox(height: 24),
          Text(
            '식물 건강 진단',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'AI가 당신의 식물의 건강 상태를\n진단해줘요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 32),
          if (selectedImagePath != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(selectedImagePath!),
                  height: 200,
                  width: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: _takePicture,
            icon: Icon(Icons.camera_alt, color: Colors.white),
            label: Text(
              '식물 잎 사진 촬영하기',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
