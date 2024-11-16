import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/database_service.dart';

class PlantListScreen extends StatelessWidget {
  final DatabaseService _databaseService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('내 식물 목록'),
      ),
      body: StreamBuilder(
        stream: _databaseService.getPlantData(),
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류가 발생했습니다'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return Center(child: Text('등록된 식물이 없습니다'));
          }

          Map<dynamic, dynamic> plants = 
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          return ListView.builder(
            itemCount: plants.length,
            itemBuilder: (context, index) {
              String key = plants.keys.elementAt(index);
              Map<dynamic, dynamic> plant = plants[key];
              
              return ListTile(
                leading: plant['imagePath'] != null 
                    ? Image.network(plant['imagePath'])
                    : Icon(Icons.local_florist),
                title: Text(plant['name'] ?? '이름 없음'),
                subtitle: Text(plant['description'] ?? '설명 없음'),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _databaseService.deletePlant(key),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 새 식물 추가 화면으로 이동
        },
        child: Icon(Icons.add),
      ),
    );
  }
} 