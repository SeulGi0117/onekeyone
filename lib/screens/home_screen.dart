import 'package:flutter/material.dart';
import '../game_screens/plant_game_screen.dart';
import '../plant_registration/plant_registration_page.dart';

class HomeScreen extends StatelessWidget {
  final List<Map<String, dynamic>> plants = [
    {'name': 'Monstera Deliciosa', 'humidity': '25-60%'},
    {'name': 'Fiddle Leaf Fig', 'humidity': '50%-70%'},
    {'name': 'Peperomia Obtusifolia', 'humidity': '50%-70%'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {
              // 알림 기능 구현
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: plants.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: AssetImage('assets/plant_placeholder.png'),
                    ),
                    title: Text(plants[index]['name']),
                    subtitle: Text('습도: ${plants[index]['humidity']}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlantGameScreen(
                            plantName: plants[index]['name'],
                            coins: 300,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            child: Text('식물 추가하기'),
            onPressed: () {
              // 식물 등록 페이지로 이동
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PlantRegistrationPage()),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.local_florist), label: 'Plants'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          if (index == 1) {
            // Plants 탭을 눌렀을 때 첫 번째 식물의 게임 화면으로 이동
            if (plants.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlantGameScreen(
                    plantName: plants[0]['name'],
                    coins: 300,
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }
}
