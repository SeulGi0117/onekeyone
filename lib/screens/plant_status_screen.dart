import 'package:flutter/material.dart';
import 'dart:io';
import '../services/nongsaro_api_service.dart';
import 'plant_detail_screen.dart';

class PlantStatusScreen extends StatefulWidget {
  final Map<String, dynamic> plant;

  const PlantStatusScreen({Key? key, required this.plant}) : super(key: key);

  @override
  _PlantStatusScreenState createState() => _PlantStatusScreenState();
}

class _PlantStatusScreenState extends State<PlantStatusScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NongsaroApiService _apiService = NongsaroApiService();
  Map<String, dynamic>? plantDetails;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPlantDetails();
  }

  Future<void> _loadPlantDetails() async {
    final details = await _apiService.getPlantDetails(widget.plant['name']);
    setState(() {
      plantDetails = details;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plant['name']),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green,
          tabs: [
            Tab(text: '실시간 데이터'),
            Tab(text: '식물 정보'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRealTimeDataTab(),
          _buildPlantInfoTab(),
        ],
      ),
    );
  }

  Widget _buildRealTimeDataTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Image.file(
                    File(widget.plant['imagePath']),
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                  SizedBox(height: 16),
                  Text(
                    widget.plant['name'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            
            Text(
              '실시간 데이터',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            
            _buildStatusItem(
              icon: Icons.thermostat,
              title: '온도',
              value: '20°C',
            ),
            _buildStatusItem(
              icon: Icons.water_drop,
              title: '습도',
              value: '40%',
            ),
            _buildStatusItem(
              icon: Icons.wb_sunny,
              title: '조도',
              value: '500lx',
            ),
            
            Divider(height: 32),
            
            Text(
              '식물 건강 상태',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            
            _buildStatusItem(
              icon: Icons.favorite,
              title: '건강 상태',
              value: '건강함',
              valueColor: Colors.green,
            ),
            _buildStatusItem(
              icon: Icons.opacity,
              title: '토양 수분 정도',
              value: '적정 수준',
            ),
            _buildStatusItem(
              icon: Icons.calendar_today,
              title: '다음 물 주기',
              value: '2 주 후',
            ),
            
            SizedBox(height: 16),
            Text(
              '당신의 식물은 건강해요!',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantInfoTab() {
    if (plantDetails == null) {
      return Center(child: CircularProgressIndicator());
    }

    // 데이터가 비어있는 경우 기본 정보 표시
    final details = plantDetails ?? {};

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (details['images']?.isNotEmpty ?? false)
              Image.network(
                details['images'][0],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              )
            else
              Image.file(
                File(widget.plant['imagePath']),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            SizedBox(height: 16),
            Text(
              details['koreanName'] ?? widget.plant['name'],
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (details['scientificName'] != null) ...[
              SizedBox(height: 8),
              Text(
                details['scientificName'],
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
            Divider(height: 32),
            
            _buildInfoSection('기본 정보', [
              _buildInfoRow('영명', details['englishName'] ?? '정보 없음'),
              _buildInfoRow('과명', details['familyName'] ?? '정보 없음'),
              _buildInfoRow('원산지', details['origin'] ?? '정보 없음'),
              _buildInfoRow('개화 시기', details['floweringSeason'] ?? '정보 없음'),
              _buildInfoRow('꽃 색상', details['flowerColor'] ?? '정보 없음'),
            ]),
            
            _buildInfoSection('생육 정보', [
              _buildInfoRow('생육 온도', details['temperature']?['growth'] ?? '정보 없음'),
              _buildInfoRow('겨울 최저온도', details['temperature']?['winter'] ?? '정보 없음'),
              _buildInfoRow('생육 습도', details['humidity'] ?? '정보 없음'),
              _buildInfoRow('광요구도', details['lightDemand'] ?? '정보 없음'),
              _buildInfoRow('생장 높이', details['growthHeight'] ?? '정보 없음'),
              _buildInfoRow('생장 너비', details['growthWidth'] ?? '정보 없음'),
            ]),
            
            _buildInfoSection('관리 방법', [
              _buildInfoRow('관리 난이도', details['managementLevel'] ?? '정보 없음'),
              _buildInfoRow('물주기(봄)', details['waterCycle']?['spring'] ?? '정보 없음'),
              _buildInfoRow('물주기(여름)', details['waterCycle']?['summer'] ?? '정보 없음'),
              _buildInfoRow('물주기(가을)', details['waterCycle']?['autumn'] ?? '정보 없음'),
              _buildInfoRow('물주기(겨울)', details['waterCycle']?['winter'] ?? '정보 없음'),
              _buildInfoRow('배치 장소', details['placementLocation'] ?? '정보 없음'),
              _buildInfoRow('토양 정보', details['soil'] ?? '정보 없음'),
              _buildInfoRow('비료 정보', details['fertilizer'] ?? '정보 없음'),
            ]),
            
            if (details['specialManagement']?.isNotEmpty ?? false)
              _buildInfoSection('특별 관리', [
                Text(details['specialManagement']),
              ]),
              
            if (details['toxicity']?.isNotEmpty ?? false)
              _buildInfoSection('독성 정보', [
                Text(details['toxicity']),
              ]),
              
            if (details['description']?.isNotEmpty ?? false)
              _buildInfoSection('상세 설명', [
                Text(details['description']),
              ]),
          ],
        ),
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
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        ...children,
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey[600]),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 