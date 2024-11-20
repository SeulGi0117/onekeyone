import 'package:flutter/material.dart';
import 'quest_screen.dart';

class PlantGameScreen extends StatelessWidget {
  final String plantName;
  final int coins;

  const PlantGameScreen({
    Key? key,
    required this.plantName,
    required this.coins,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plantName),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(Icons.monetization_on),
                SizedBox(width: 4),
                Text('$coins'),
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
          _buildInfoItem('건강상태', '양호'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
