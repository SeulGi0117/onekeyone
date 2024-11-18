import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';

class PlantDiagnosisScreen extends StatefulWidget {
  @override
  _PlantDiagnosisScreenState createState() => _PlantDiagnosisScreenState();
}

class _PlantDiagnosisScreenState extends State<PlantDiagnosisScreen> {
  final ImagePicker _picker = ImagePicker();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  String? selectedImagePath;

  Future<void> _clearPreviousDiagnosis() async {
    try {
      // leaf_disease 경로의 모든 데이터를 가져옴
      DataSnapshot snapshot = await _database.child('leaf_disease').get();
      
      // 데이터가 있으면 삭제
      if (snapshot.exists) {
        await _database.child('leaf_disease').remove();
      }
    } catch (e) {
      print('기존 진단 데이터 삭제 오류: $e');
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          selectedImagePath = photo.path;
        });

        // 기존 진단 데이터 삭제
        await _clearPreviousDiagnosis();

        // Firebase에 저장할 데이터 준비
        Map<String, dynamic> diagnosisData = {
          'imagePath': photo.path,
          'timestamp': DateTime.now().toIso8601String(),
          'status': 'pending',
        };

        // 새로운 데이터 저장 (경로 수정)
        await _database.child('leaf_disease').push().set(diagnosisData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('식물 잎 사진이 업로드되었습니다')),
        );

        // TODO: 여기에 식물 건강 진단 API 연동
      }
    } catch (e) {
      print('카메라 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 촬영 중 오류가 발생했습니다.')),
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