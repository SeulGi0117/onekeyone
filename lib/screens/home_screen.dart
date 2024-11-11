import 'package:flutter/material.dart';
import 'plant_identification_screen.dart';
import 'plant_detail_screen.dart';
import 'dart:io';
import '../models/plant.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Plant> plants = [
    Plant(
      name: '테스트 식물',
      imagePath: 'assets/images/default_plant.jpg',
      temperature: '20-25',
      humidity: '60-70',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: plants.length, // plants는 등록된 식물 리스트
              itemBuilder: (context, index) {
                return InkWell(
                  // 터치 가능한 위젯으로 감싸기
                  onTap: () {
                    // 식물 상세 정보 화면으로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlantDetailScreen(
                          plantName: plants[index].name,
                          imagePath: plants[index].imagePath,
                          showRegisterButton: false,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(plants[index].imagePath),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(plants[index].name),
                      subtitle: Text(
                          '온도: ${plants[index].temperature}°C\n습도: ${plants[index].humidity}% 필요'),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              // icon 추가
              icon: Icon(Icons.add, color: Colors.white),
              label: Text(
                '식물 등록하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlantIdentificationScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
