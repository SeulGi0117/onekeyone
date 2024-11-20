import 'package:flutter/material.dart';
import 'dart:io';
import '../services/nongsaro_api_service.dart';
import 'plant_detail_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';

class PlantStatusScreen extends StatefulWidget {
  final Map<String, dynamic> plant;
  final Map<String, dynamic>? sensorData;

  const PlantStatusScreen({
    Key? key,
    required this.plant,
    this.sensorData,
  }) : super(key: key);

  @override
  _PlantStatusScreenState createState() => _PlantStatusScreenState();
}

class _PlantStatusScreenState extends State<PlantStatusScreen> with SingleTickerProviderStateMixin {
  late final Stream<DatabaseEvent> _sensorStream;
  late final TabController _tabController;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sensorStream = FirebaseDatabase.instance
        .ref()
        .child('JSON/ESP32SENSOR')
        .onValue;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.plant['name']),
          bottom: TabBar(
            controller: _tabController,
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
          controller: _tabController,
          children: [
            _buildRealTimeDataTab(context),
            _buildPlantInfoTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeDataTab(BuildContext context) {
    if (_isDisposed) return Container();
    
    return StreamBuilder<DatabaseEvent>(
      key: ValueKey('realtime_data_stream'),
      stream: _sensorStream,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (_isDisposed) return Container();

        Map<String, dynamic> currentSensorData = {};
        
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          currentSensorData = Map<String, dynamic>.from(
              snapshot.data!.snapshot.value as Map);
        }

        // 센서값 파싱 함수
        String parseValue(String? value, String unit) {
          if (value == null) return '측정중...';
          // % 또는 lux 등의 단위를 제거하고 숫자만 추출
          String numericValue = value.replaceAll(RegExp(r'[^0-9.]'), '');
          return '$numericValue$unit';
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
                    File(widget.plant['imagePath']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(height: 20),
              
              // 식물 이름
              Text(
                widget.plant['name'],
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),

              // 센서 데이터 카드들
              _buildSensorCard(
                Icons.thermostat,
                '현재 온도',
                snapshot.hasData ? parseValue(currentSensorData['온도']?.toString(), '°C') : '측정중...',
                Colors.orange,
              ),
              SizedBox(height: 12),
              _buildSensorCard(
                Icons.opacity,
                '현재 습도',
                snapshot.hasData ? parseValue(currentSensorData['습도']?.toString(), '%') : '측정중...',
                Colors.blue,
              ),
              SizedBox(height: 12),
              _buildSensorCard(
                Icons.wb_sunny,
                '현재 조도',
                snapshot.hasData ? parseValue(currentSensorData['조도']?.toString(), ' lux') : '측정중...',
                Colors.yellow,
              ),
              SizedBox(height: 12),
              _buildSensorCard(
                Icons.water_drop,
                '현재 토양습도',
                snapshot.hasData ? parseValue(currentSensorData['토양습도']?.toString(), '%') : '측정중...',
                Colors.brown,
              ),
              SizedBox(height: 12),
              _buildCameraCard(),
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
    final NongsaroApiService _apiService = NongsaroApiService();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _apiService.getPlantDetails(
        widget.plant['name'],
        scientificName: widget.plant['scientificName'],
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('식물 정보를 불러오는데 실패했습니다.'));
        }

        final plantDetails = snapshot.data;
        if (plantDetails == null) {
          return Center(child: Text('식물 정보를 찾을 수 없습니다.'));
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '기본 정보',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              _buildInfoSection('식물명', [
                _buildInfoRow('한글명', plantDetails['koreanName'] ?? '-'),
                _buildInfoRow('영문명', plantDetails['englishName'] ?? '-'),
                _buildInfoRow('학명', plantDetails['scientificName'] ?? '-'),
                _buildInfoRow('과명', plantDetails['familyName'] ?? '-'),
              ]),
              
              _buildInfoSection('생육 정보', [
                _buildInfoRow('성장 높이', plantDetails['growthHeight'] ?? '-'),
                _buildInfoRow('성장 넓이', plantDetails['growthWidth'] ?? '-'),
                _buildInfoRow('생육 온도', plantDetails['temperature']?['growth'] ?? '-'),
                _buildInfoRow('겨울 최저온도', plantDetails['temperature']?['winter'] ?? '-'),
              ]),
              
              _buildInfoSection('관리 방법', [
                _buildInfoRow('관리 난이도', plantDetails['managementLevel'] ?? '-'),
                _buildInfoRow('물주기(봄)', plantDetails['waterCycle']?['spring'] ?? '-'),
                _buildInfoRow('물주기(여름)', plantDetails['waterCycle']?['summer'] ?? '-'),
                _buildInfoRow('물주기(가을)', plantDetails['waterCycle']?['autumn'] ?? '-'),
                _buildInfoRow('물주기(겨울)', plantDetails['waterCycle']?['winter'] ?? '-'),
                _buildInfoRow('빛 요구도', plantDetails['lightDemand'] ?? '-'),
                _buildInfoRow('습도', plantDetails['humidity'] ?? '-'),
              ]),

              if (plantDetails['specialManagement']?.isNotEmpty ?? false)
                _buildInfoSection('특별 관리', [
                  Text(plantDetails['specialManagement']),
                ]),

              if (plantDetails['toxicity']?.isNotEmpty ?? false)
                _buildInfoSection('독성 정보', [
                  Text(plantDetails['toxicity']),
                ]),
            ],
          ),
        );
      },
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

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        SizedBox(height: 8),
        ...children,
        SizedBox(height: 24),
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
            width: 120,
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
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 실시간 카메라 이미지를 보여주는 다이얼로그
  void _showCameraImageDialog(BuildContext context, String base64Image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text('실시간 식물 사진'),
                leading: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Image.memory(
                  base64Decode(base64Image.split(',').last),
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // _buildRealTimeDataTab 메서드 내부의 센서 카드 다음에 추가
  Widget _buildCameraCard() {
    if (_isDisposed) return Container();

    return StreamBuilder<DatabaseEvent>(
      key: ValueKey('camera_stream'),
      stream: FirebaseDatabase.instance.ref().child('JSON/ESP32CAM').onValue,
      builder: (context, snapshot) {
        if (_isDisposed) return Container();

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return Card(
            child: ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.grey),
              title: Text('실시간 식물 사진 보기'),
              subtitle: Text('카메라 연결 대기중...'),
            ),
          );
        }

        final imageData = snapshot.data!.snapshot.value.toString();

        return Card(
          child: ListTile(
            leading: Icon(Icons.camera_alt, color: Colors.green),
            title: Text('실시간 식물 사진 보기'),
            subtitle: Text('최근 업데이트: ${DateTime.now().toString().substring(11, 16)}'),
            onTap: () {
              if (imageData.startsWith('data:image')) {
                _showCameraImageDialog(context, imageData);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('유효하지 않은 이미지 데이터입니다.')),
                );
              }
            },
          ),
        );
      },
    );
  }
} 