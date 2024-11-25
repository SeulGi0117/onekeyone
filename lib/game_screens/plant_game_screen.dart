import 'package:flutter/material.dart';
import 'quest_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/plant_health_model.dart';

class PlantGameScreen extends StatefulWidget {
  final String plantName;
  final int coins;
  final String plantId;

  const PlantGameScreen({
    Key? key,
    required this.plantName,
    required this.coins,
    required this.plantId,
  }) : super(key: key);

  @override
  State<PlantGameScreen> createState() => _PlantGameScreenState();
}

class _PlantGameScreenState extends State<PlantGameScreen> {
  PlantHealthStatus? healthStatus;
  late DatabaseReference _healthRef;

  @override
  void initState() {
    super.initState();
    _healthRef = FirebaseDatabase.instance
        .ref()
        .child('plants/${widget.plantId}/health_status');
    _setupHealthListener();
  }

  void _setupHealthListener() {
    _healthRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          healthStatus = PlantHealthStatus.fromMap(
            Map<String, dynamic>.from(event.snapshot.value as Map),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plantName),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(Icons.monetization_on),
                SizedBox(width: 4),
                Text('${widget.coins}'),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Text('여기에 식물 이미지와 게임 요소를 추가하세요'),
            ),
          ),
          _buildEnvironmentInfo(),
          _buildBottomTabs(context),
        ],
      ),
    );
  }

  Widget _buildEnvironmentInfo() {
    return Container(
      padding: EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem('온도', '22°C'),
          _buildInfoItem('습도', '45%'),
          _buildInfoItem('조도', '300 lux'),
          _buildInfoItem(
            '건강상태',
            healthStatus?.status ?? '분석중...',
            textColor: _getHealthStatusColor(healthStatus?.status),
          ),
        ],
      ),
    );
  }

  Color _getHealthStatusColor(String? status) {
    if (status == null) return Colors.grey;
    if (status.toLowerCase() == 'healthy') return Colors.green;
    return Colors.red;
  }

  Widget _buildInfoItem(String label, String value, {Color? textColor}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomTabs(BuildContext context) {
    return Container(
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTab(Icons.list_alt, '퀘스트', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => QuestScreen()),
            );
          }),
          _buildTab(Icons.person, '캐릭터', () {}),
        ],
      ),
    );
  }

  Widget _buildTab(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
