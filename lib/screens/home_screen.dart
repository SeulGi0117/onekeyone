import 'package:flutter/material.dart';
import 'plant_identification_screen.dart';
import 'plant_detail_screen.dart';
import 'plant_diagnosis_screen.dart';
import 'dart:io';
import '../models/plant.dart';
import '../services/nongsaro_api_service.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/database_service.dart';
import 'plant_status_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}
 
class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final NongsaroApiService _apiService = NongsaroApiService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? '내 식물' : '식물 진단'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _selectedIndex == 0 ? _buildHomeScreen() : _buildDiagnosisScreen(),
          ),
          if (_selectedIndex == 0)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlantIdentificationScreen(),
                    ),
                  );
                },
                icon: Icon(Icons.add, color: Colors.white),
                label: Text(
                  '식물 등록하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '내 식물',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.healing),
            label: '진단하기',
          ),
        ],
        selectedItemColor: Colors.green,
      ),
    );
  }

  Widget _buildHomeScreen() {
    return StreamBuilder(
      stream: _databaseService.getPlantData(),
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('오류가 발생했습니다'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return Center(
            child: Text(
              '등록된 식물이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          );
        }

        Map<dynamic, dynamic> plants = 
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

        return ListView.builder(
          itemCount: plants.length,
          itemBuilder: (context, index) {
            String key = plants.keys.elementAt(index);
            Map<dynamic, dynamic> plant = plants[key];
            
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: () {
                  Map<String, dynamic> plantData = Map<String, dynamic>.from(plant);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlantStatusScreen(plant: plantData),
                    ),
                  );
                },
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(plant['imagePath']),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    plant['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.water_drop, size: 16, color: Colors.blue),
                            SizedBox(width: 4),
                            Text('마지막 물주기: ${_formatDate(plant['lastWatered'])}'),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.favorite, size: 16, color: Colors.green),
                            SizedBox(width: 4),
                            Text('상태: ${plant['status']}'),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.thermostat, size: 16, color: Colors.orange),
                            SizedBox(width: 4),
                            Text('온도: ${plant['temperature'] ?? '20-25'}°C'),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.opacity, size: 16, color: Colors.lightBlue),
                            SizedBox(width: 4),
                            Text('토양습도: ${plant['soilMoisture'] ?? '60-70'}%'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  trailing: PopupMenuButton(
                    icon: Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('식물 삭제하기', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text('식물 삭제'),
                              content: Text('정말로 등록된 ${plant['name']}을(를) 삭제하시겠습니까?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    '아니요',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    await _databaseService.deletePlant(key);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${plant['name']}이(가) 삭제되었습니다'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    '삭제합니다',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            );
                          },
                        );
                      }
                    },
                  ),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDiagnosisScreen() {
    return PlantDiagnosisScreen();
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null || dateString.toString().isEmpty) {
      return '정보 없음';
    }
    try {
      final date = DateTime.parse(dateString.toString());
      return '${date.year}-${date.month}-${date.day}';
    } catch (e) {
      return '정보 없음';
    }
  }
}
