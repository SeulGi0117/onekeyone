import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/database_service.dart';
import 'dart:convert';

class PlantListScreen extends StatelessWidget {
  final DatabaseService _databaseService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('내 식물 목록'),
      ),
      body: StreamBuilder(
        stream: _databaseService.getPlantData(),
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류가 발생했습니다'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(child: Text('등록된 식물이 없습니다'));
          }

          Map<dynamic, dynamic> plants = 
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          return ListView.builder(
            itemCount: plants.length,
            itemBuilder: (context, index) {
              String key = plants.keys.elementAt(index);
              Map<dynamic, dynamic> plant = plants[key];
              
              return FutureBuilder<String>(
                future: _getKoreanStatus(plant['status']),
                builder: (context, statusSnapshot) {
                  String status = statusSnapshot.data ?? '상태 정보 없음';
                  
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: plant['imageBase64'] != null 
                          ? Image.memory(
                              base64Decode(plant['imageBase64']),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                          : Icon(Icons.local_florist),
                      title: Text(plant['nickname'] ?? plant['name'] ?? '이름 없음'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('상태: $status'),
                          if (plant['temperature'] != null)
                            Text('온도: ${plant['temperature']}°C'),
                          if (plant['humidity'] != null)
                            Text('습도: ${plant['humidity']}%'),
                          if (plant['light'] != null)
                            Text('조도: ${plant['light']} lux'),
                          if (plant['soilMoisture'] != null)
                            Text('토양습도: ${plant['soilMoisture']}%'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _databaseService.deletePlant(key),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 새 식물 추가 화면으로 이동
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Future<String> _getKoreanStatus(String? status) async {
    if (status == null) return '상태 정보 없음';
    
    // 건강한 상태 처리
    if (status == 'healthy' || status == 'plant___healthy') {
      return '건강함';
    }

    try {
      // Firebase에서 질병 정보 가져오기
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('plant_diseases')
          .child(status.replaceAll(' ', '_'))
          .get();

      if (snapshot.exists) {
        final diseaseData = Map<String, dynamic>.from(snapshot.value as Map);
        return diseaseData['한국어_병명'] ?? status;
      }

      // 첫 번째 시도 실패 시 끝에 _를 추가하여 재시도
      final retrySnapshot = await FirebaseDatabase.instance
          .ref()
          .child('plant_diseases')
          .child('${status.replaceAll(' ', '_')}_')
          .get();

      if (retrySnapshot.exists) {
        final diseaseData = Map<String, dynamic>.from(retrySnapshot.value as Map);
        return diseaseData['한국어_병명'] ?? status;
      }

      return status;
    } catch (e) {
      print('상태 변환 오류: $e');
      return status;
    }
  }
} 