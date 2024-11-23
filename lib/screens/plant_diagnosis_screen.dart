import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

class PlantDiagnosisScreen extends StatefulWidget {
  const PlantDiagnosisScreen({super.key});

  @override
  _PlantDiagnosisScreenState createState() => _PlantDiagnosisScreenState();
}

class _PlantDiagnosisScreenState extends State<PlantDiagnosisScreen> {
  final ImagePicker _picker = ImagePicker();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  String? selectedImagePath;

  // 이미지를 Base64로 인코딩하는 함수
  Future<String> encodeImageToBase64(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final List<int> imageBytes = await imageFile.readAsBytes();

      // List<int>를 Uint8List로 변환
      final Uint8List bytes = Uint8List.fromList(imageBytes);

      // 이미지 디코딩
      final img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) throw Exception('이미지 디코딩 실패');

      // 이미지 크기 조정 (최대 너비 1200px로 설정)
      int targetWidth = 1200;
      int targetHeight =
          (1200 * originalImage.height / originalImage.width).round();

      final img.Image resizedImage = img.copyResize(originalImage,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.linear);

      // JPEG 형식으로 압축 (품질: 95%)
      final List<int> compressedBytes =
          img.encodeJpg(resizedImage, quality: 90);

      // Base64로 인코딩
      final String base64Image = base64Encode(compressedBytes);

      print('이미지 처리 완료 - 크기: ${base64Image.length} bytes');
      return base64Image;
    } catch (e) {
      print('이미지 인코딩 오류: $e');
      rethrow;
    }
  }

  // Firebase에 이미지 업로드하는 함수
  Future<void> uploadImageToFirebase(String encodedImage) async {
    try {
      // 이미지 크기 확인
      final int imageSizeKB = encodedImage.length ~/ 1024;
      print('업로드 이미지 크기: ${imageSizeKB}KB');

      if (imageSizeKB > 10240) {
        // 10MB 제한
        throw Exception('이미지 크기가 너무 큽니다 (${imageSizeKB}KB)');
      }

      await _database.child('leaf_disease').push().set({
        'disease_image': encodedImage,
        'timestamp': DateTime.now().toIso8601String(),
        'image_size_kb': imageSizeKB,
      });
    } catch (e) {
      print('Firebase 업로드 에러: $e');
      rethrow;
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
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
            return const Center(
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
            const SnackBar(
              content: Text('식물 잎 사진이 업로드되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          print('이미지 처리 오류: $e');
          if (!mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미지 처리 중 오류가 발생했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('카메라 에러: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진 촬영 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.local_hospital,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          const Text(
            '식물 건강 진단',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'AI가 당신의 식물의 건강 상태를\n진단해줘요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
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
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            label: const Text(
              '식물 잎 사진 촬영하기',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
