import 'package:flutter/material.dart';
import 'dart:io';
import '../services/nongsaro_api_service.dart';
import 'plant_detail_screen.dart';
import 'package:firebase_database/firebase_database.dart';

class PlantStatusScreen extends StatelessWidget {
  final Map<String, dynamic> plant;
  final Map<String, dynamic>? sensorData;

  const PlantStatusScreen({
    Key? key,
    required this.plant,
    this.sensorData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(plant['name']),
          bottom: TabBar(
            tabs: [
              Tab(text: '실시간 데이터'),
              Tab(text: '식물 정보'),
            ],
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
          ),
        ),
        body: TabBarView(
          children: [
            _buildRealTimeDataTab(context),
            _buildPlantInfoTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeDataTab(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseDatabase.instance.ref().child('JSON/ESP32SENSOR').onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        Map<String, dynamic> currentSensorData = {};
        
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          currentSensorData = Map<String, dynamic>.from(
              snapshot.data!.snapshot.value as Map);
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 식물 이미지
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(plant['imagePath']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(height: 20),
              
              // 식물 이름
              Text(
                plant['name'],
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),

              // 센서 데이터 카드들
              _buildSensorCard(
                Icons.thermostat,
                '온도',
                '${currentSensorData['온도'] ?? '20'}°C',
                Colors.orange,
              ),
              SizedBox(height: 12),
              _buildSensorCard(
                Icons.opacity,
                '습도',
                '${currentSensorData['습도'] ?? '40'}%',
                Colors.blue,
              ),
              SizedBox(height: 12),
              _buildSensorCard(
                Icons.wb_sunny,
                '조도',
                '${currentSensorData['조도'] ?? '500'}lx',
                Colors.yellow,
              ),
              SizedBox(height: 20),

              // 식물 건강 상태 섹션
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '식물 건강 상태',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildHealthRow(
                        Icons.favorite,
                        '건강 상태',
                        '건강함',
                        Colors.green,
                      ),
                      _buildHealthRow(
                        Icons.water_drop,
                        '토양 수분 정도',
                        '적정 수준',
                        Colors.blue,
                      ),
                      _buildHealthRow(
                        Icons.calendar_today,
                        '다음 물 주기',
                        '2주 후',
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlantInfoTab(BuildContext context) {
    // 식물 상세 정보 탭 구현
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '식물 관리 정보',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          _buildInfoCard(
            '물 주기',
            '2주에 한 번',
            Icons.water_drop,
            Colors.blue,
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            '빛 요구량',
            '적정 수준',
            Icons.wb_sunny,
            Colors.orange,
          ),
          SizedBox(height: 12),
          _buildInfoCard(
            '온도 관리',
            '20-25°C',
            Icons.thermostat,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(IconData icon, String label, String value, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHealthRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 