import 'package:flutter/material.dart';
import 'plant_identification_screen.dart';
import 'plant_detail_screen.dart';
import 'plant_diagnosis_screen.dart';
import 'dart:io';
import '../models/plant.dart';
import '../services/nongsaro_api_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NongsaroApiService _apiService = NongsaroApiService();
  int _selectedIndex = 0;
  String? plantImageUrl;
  final List<Plant> plants = [
    Plant(
      name: '치자나무',
      imagePath: 'assets/images/default_plant.jpg',
      temperature: '16-20',
      humidity: '40-70',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPlantImage();
  }

  Future<void> _loadPlantImage() async {
    final details = await _apiService.getPlantDetails('치자');
    if (details != null && details['images'].isNotEmpty) {
      setState(() {
        plantImageUrl = details['images'][0];
      });
    }
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      // 진단 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PlantDiagnosisScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: plants.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlantDetailScreen(
                        plantName: '치자나무',
                        scientificName: 'Gardenia jasminoides',
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
                      child: plantImageUrl != null
                          ? Image.network(
                              plantImageUrl!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              'assets/images/default_plant.jpg',
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                    ),
                    title: Text('치자나무'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('생육 적온: ${plants[index].temperature}°C'),
                        Text('습도: ${plants[index].humidity}%'),
                        Text('광요구도: 중간 광도(800-1,500 Lux)'),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
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
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlantIdentificationScreen(),
                ),
              );

              if (result != null) {
                setState(() {
                  plants.add(Plant(
                    name: result['name'],
                    imagePath: result['imagePath'],
                    temperature: '20-25',
                    humidity: '60-70',
                  ));
                });
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('내 식물'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: _buildMainContent(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '내 식물',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '진단하기',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        onTap: _onItemTapped,
      ),
    );
  }
}
