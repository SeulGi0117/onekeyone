import 'package:flutter/material.dart';
import 'plant_identification_screen.dart';
import 'plant_diagnosis_screen.dart';
import 'dart:io';
import '../services/nongsaro_api_service.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/database_service.dart';
import 'plant_status_screen.dart';
import 'quest_screen.dart';
import 'store_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final NongsaroApiService _apiService = NongsaroApiService();
  int _selectedIndex = 0;

  late final Stream<DatabaseEvent> _plantsStream;
  late final Stream<DatabaseEvent> _sensorStream;

  @override
  void initState() {
    super.initState();
    _plantsStream = _databaseService.getPlantData().asBroadcastStream();
    _sensorStream = FirebaseDatabase.instance
        .ref()
        .child('JSON/ESP32SENSOR')
        .onValue
        .asBroadcastStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.assignment),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuestScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '내 식물',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.healing),
            label: '진단하기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: '스토어',
          ),
        ],
        selectedItemColor: Colors.green,
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return '내 식물';
      case 1:
        return '식물 진단';
      case 2:
        return '스토어';
      default:
        return '내 식물';
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return Column(
          children: [
            Expanded(child: _buildHomeScreen()),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlantIdentificationScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  '식물 등록하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      case 1:
        return _buildDiagnosisScreen();
      case 2:
        return const StoreScreen();
      default:
        return _buildHomeScreen();
    }
  }

  Widget _buildHomeScreen() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref()
          .child('plants')
          .onValue
          .asBroadcastStream(),
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('오류가 발생했습니다'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final dynamic snapshotValue = snapshot.data?.snapshot.value;
        if (snapshotValue == null) {
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

        if (snapshotValue is! Map) {
          return const Center(child: Text('데이터 형식이 올바르지 않습니다'));
        }

        Map<dynamic, dynamic> plants =
            Map<dynamic, dynamic>.from(snapshotValue);

        return ListView.builder(
          itemCount: plants.length,
          itemBuilder: (context, index) {
            String key = plants.keys.elementAt(index);
            Map<dynamic, dynamic> plant =
                Map<dynamic, dynamic>.from(plants[key]);
            plant['id'] = key;

            String jsonNode = 'JSON';
            if (index == 1) jsonNode = 'JSON2';
            if (index == 2) jsonNode = 'JSON3';

            return StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref()
                  .child(jsonNode)
                  .child('ESP32SENSOR')
                  .onValue
                  .asBroadcastStream(),
              builder: (context, AsyncSnapshot<DatabaseEvent> sensorSnapshot) {
                Map<String, dynamic> sensorData = {};

                if (sensorSnapshot.hasData &&
                    sensorSnapshot.data?.snapshot.value != null) {
                  sensorData = Map<String, dynamic>.from(
                      sensorSnapshot.data!.snapshot.value as Map);
                }

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: InkWell(
                    onTap: () {
                      Map<String, dynamic> plantData =
                          Map<String, dynamic>.from(plant);
                      plantData['sensorNode'] = jsonNode;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlantStatusScreen(
                            plant: plantData,
                            sensorData: sensorData,
                          ),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('센서 노드: $jsonNode'),
                            Row(
                              children: [
                                const Icon(Icons.water_drop,
                                    size: 16, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                    '마지막 물주기: ${_formatDate(plant['lastWatered'])}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.favorite,
                                    size: 16, color: Colors.green),
                                const SizedBox(width: 4),
                                Text('상태: ${plant['status']}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.thermostat,
                                    size: 16, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text('온도: ${sensorData['온도'] ?? '측정중'}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.opacity,
                                    size: 16, color: Colors.lightBlue),
                                const SizedBox(width: 4),
                                Text('습도: ${sensorData['습도'] ?? '측정중'}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.wb_sunny,
                                    size: 16, color: Colors.yellow),
                                const SizedBox(width: 4),
                                Text('조도: ${sensorData['조도'] ?? '측정중'}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.water,
                                    size: 16, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text('토양습도: ${sensorData['토양습도'] ?? '측정중'}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      trailing: PopupMenuButton(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('식물 삭제하기',
                                    style: TextStyle(color: Colors.red)),
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
                                  title: const Text('식물 삭제'),
                                  content: Text(
                                      '정말로 등록된 ${plant['name']}을(를) 삭제하시겠습니까?'),
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
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '${plant['name']}이(가) 삭제되었습니다'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        elevation: 0,
                                      ),
                                      child: const Text(
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
                                  actionsPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                );
                              },
                            );
                          }
                        },
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                );
              },
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
