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
    super.key,
    required this.plant,
    this.sensorData,
  });

  @override
  _PlantStatusScreenState createState() => _PlantStatusScreenState();
}

class _PlantStatusScreenState extends State<PlantStatusScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isDisposed = false;
  String? _nickname;

  // Stream을 broadcast로 변환하여 여러 번 구독 가능하게 함
  late final Stream<DatabaseEvent> _sensorStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    String sensorNode = widget.plant['sensorNode'] ?? 'JSON';
    _sensorStream = FirebaseDatabase.instance
        .ref()
        .child(sensorNode)
        .child('ESP32SENSOR')
        .onValue
        .asBroadcastStream();
    _nickname = widget.plant['nickname'];

    // 상태 체크 퀘스트 업데이트
    _updateObservationQuest();
  }

  Future<void> _updateObservationQuest() async {
    final questRef =
        FirebaseDatabase.instance.ref().child('quests/observation');
    final snapshot = await questRef.get();

    try {
      if (snapshot.exists) {
        final questData = Map<String, dynamic>.from(snapshot.value as Map);
        final currentProgress = questData['progress'] ?? 0;
        final isRewarded = questData['rewarded'] ?? false;

        // 보상을 받지 않았고 최대 횟수(5회)에 도달하지 않은 경우에만 증가
        if (!isRewarded && currentProgress < 5) {
          await questRef.update({
            'progress': currentProgress + 1,
            'lastUpdate': DateTime.now().toIso8601String(),
            'rewarded': false,
          });
        }
      } else {
        // 최초 실행 시
        await questRef.set({
          'progress': 1,
          'goal': 5,
          'lastUpdate': DateTime.now().toIso8601String(),
          'rewarded': false,
        });
      }
    } catch (e) {
      print('관찰 퀘스트 업데이트 오류: $e');
    }
  }

  void _editNickname() {
    TextEditingController controller = TextEditingController(text: _nickname);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('식물 별명 설정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '식물의 별명을 입력해주세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newNickname = controller.text.trim();
              if (newNickname.isNotEmpty) {
                try {
                  final plantId = widget.plant['id']?.toString();
                  if (plantId == null || plantId.isEmpty) {
                    throw Exception('식물 ID를 찾을 수 없습니다');
                  }

                  // 파이어베이스 레퍼런스 생성
                  final plantRef = FirebaseDatabase.instance
                      .ref()
                      .child('plants')
                      .child(plantId);

                  // 현재 데이터를 가져와서 nickname만 업데이트
                  final snapshot = await plantRef.get();
                  if (snapshot.exists) {
                    final plantData =
                        Map<String, dynamic>.from(snapshot.value as Map);
                    plantData['nickname'] = newNickname;

                    // 전체 데이터 업데이트
                    await plantRef.update(plantData);

                    // 별명 퀘스트 업데이트
                    final questRef = FirebaseDatabase.instance
                        .ref()
                        .child('quests/nickname');
                    final nicknameHistoryRef = FirebaseDatabase.instance
                        .ref()
                        .child('nickname_history');

                    try {
                      // 별명 변경 이력 저장
                      await nicknameHistoryRef.push().set({
                        'plantId': plantId,
                        'nickname': newNickname,
                        'timestamp': DateTime.now().toIso8601String(),
                      });

                      // 퀘스트 데이터 업데이트
                      final questSnapshot = await questRef.get();
                      if (questSnapshot.exists) {
                        final questData = Map<String, dynamic>.from(
                            questSnapshot.value as Map);
                        final isRewarded = questData['rewarded'] ?? false;
                        final currentProgress = questData['progress'] ?? 0;
                        final currentGoal = questData['goal'] ?? 1;

                        // 보상을 받은 상태이고 현재 진행도가 0이면 새로운 진행 시작
                        if (isRewarded && currentProgress == 0) {
                          await questRef.update({
                            'progress': 1,
                            'rewarded': false, // 새로운 진행을 위해 rewarded 상태 초기화
                            'lastUpdate': DateTime.now().toIso8601String(),
                          });
                        }
                        // 보상을 받지 않은 상태에서 목표에 도달하지 않았다면 진행도 증가
                        else if (!isRewarded && currentProgress < currentGoal) {
                          await questRef.update({
                            'progress': currentProgress + 1,
                            'lastUpdate': DateTime.now().toIso8601String(),
                          });
                        }
                      } else {
                        // 최초 실행 시
                        await questRef.set({
                          'progress': 1,
                          'goal': 1,
                          'rewarded': false,
                          'lastUpdate': DateTime.now().toIso8601String(),
                        });
                      }
                    } catch (e) {
                      print('별명 저장 오류: $e');
                      rethrow;
                    }

                    setState(() {
                      _nickname = newNickname;
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('식물 별명이 변경되었습니다'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  print('닉네임 저장 오류: $e');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('별명 저장에 실패했습니다'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
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
          title: Text(_nickname ?? widget.plant['name']),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
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
      key: const ValueKey('realtime_data_stream'),
      stream: _sensorStream, // broadcast stream 사용
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (_isDisposed) return Container();

        Map<String, dynamic> currentSensorData = {};

        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          currentSensorData =
              Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        }

        // 센서값 파싱 함수
        String parseValue(String? value, String unit) {
          if (value == null) return '측정중...';
          // % 또는 lux 등의 단위를 제거하고 숫자만 추출
          String numericValue = value.replaceAll(RegExp(r'[^0-9.]'), '');
          return '$numericValue$unit';
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 20),

              // 식물 이름과 별명 설정 버튼
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.plant['name'],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        InkWell(
                          onTap: _editNickname,
                          child: Row(
                            children: [
                              Text(
                                _nickname != null ? _nickname! : '식물 별명 추가하기',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 센서 데이터 카드들
              _buildSensorCard(
                Icons.thermostat,
                '현재 온도',
                snapshot.hasData
                    ? parseValue(currentSensorData['온도']?.toString(), '°C')
                    : '측정중...',
                Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildSensorCard(
                Icons.opacity,
                '현재 습도',
                snapshot.hasData
                    ? parseValue(currentSensorData['습도']?.toString(), '%')
                    : '측정중...',
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildSensorCard(
                Icons.wb_sunny,
                '현재 조도',
                snapshot.hasData
                    ? parseValue(currentSensorData['조도']?.toString(), ' lux')
                    : '측정중...',
                Colors.yellow,
              ),
              const SizedBox(height: 12),
              _buildSensorCard(
                Icons.water_drop,
                '현재 토양습도',
                snapshot.hasData
                    ? parseValue(currentSensorData['토양습도']?.toString(), '%')
                    : '측정중...',
                Colors.brown,
              ),
              const SizedBox(height: 12),
              _buildCameraCard(),
              const SizedBox(height: 20),

              // 식물 건강 상태 섹션
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '식물 건강 상태',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
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
    final NongsaroApiService apiService = NongsaroApiService();

    return FutureBuilder<Map<String, dynamic>?>(
      future: apiService.getPlantDetails(widget.plant['name']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('식물 정보 조회 오류: ${snapshot.error}');
          return const Center(child: Text('식물 정보를 불러오는데 실패했습니다.'));
        }

        final plantDetails = snapshot.data ?? {
          'koreanName': '-',
          'scientificName': '-',
          'englishName': '-',
          'familyName': '-',
          'origin': '-',
          'growthHeight': '-',
          'growthWidth': '-',
          'leafInfo': '-',
          'flowerInfo': '-',
          'managementLevel': '-',
          'lightDemand': '-',
          'waterCycle': {
            'spring': '-',
            'summer': '-',
            'autumn': '-',
            'winter': '-',
          },
          'temperature': {
            'growth': '-',
            'winter': '-',
          },
          'humidity': '-',
          'specialManagement': '-',
          'toxicity': '-',
        };

        if (snapshot.data == null) {
          print('식물 정보를 찾을 수 없음: ${widget.plant['name']}');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('식물 정보를 찾을 수 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoSection('기본 정보', [
                _buildInfoRow('한글명', plantDetails['koreanName']),
                _buildInfoRow('영문명', plantDetails['englishName']),
                _buildInfoRow('학명', plantDetails['scientificName']),
                _buildInfoRow('과명', plantDetails['familyName']),
              ]),
              _buildInfoSection('식물 특성', [
                _buildInfoRow('원산지', plantDetails['origin']),
                _buildInfoRow('성장 높이', plantDetails['growthHeight']),
                _buildInfoRow('성장 너비', plantDetails['growthWidth']),
                _buildInfoRow('잎 정보', plantDetails['leafInfo']),
                _buildInfoRow('꽃 정보', plantDetails['flowerInfo']),
              ]),
              _buildInfoSection('관리 정보', [
                _buildInfoRow('관리 수준', plantDetails['managementLevel']),
                _buildInfoRow('광 요구도', plantDetails['lightDemand']),
                _buildInfoRow('물 주기',
                    '봄: ${plantDetails['waterCycle']['spring']}, 여름: ${plantDetails['waterCycle']['summer']}, 가을: ${plantDetails['waterCycle']['autumn']}, 겨울: ${plantDetails['waterCycle']['winter']}'),
                _buildInfoRow('성장 온도', plantDetails['temperature']['growth']),
                _buildInfoRow('겨울 온도', plantDetails['temperature']['winter']),
                _buildInfoRow('습도', plantDetails['humidity']),
                _buildInfoRow('특별 관리', plantDetails['specialManagement']),
                _buildInfoRow('독성 정보', plantDetails['toxicity']),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSensorCard(
      IconData icon, String label, String value, Color color) {
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHealthRow(
      IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const Spacer(),
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 24),
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
              style: const TextStyle(
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
                title: const Text('실시간 식물 사진'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
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
      key: const ValueKey('camera_stream'),
      stream: FirebaseDatabase.instance
          .ref()
          .child('JSON/ESP32CAM')
          .onValue
          .asBroadcastStream(),
      builder: (context, snapshot) {
        if (_isDisposed) return Container();

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.grey),
              title: Text('실시간 식물 사진 보기'),
              subtitle: Text('카라 연결 대기중...'),
            ),
          );
        }

        final imageData = snapshot.data!.snapshot.value.toString();

        return Card(
          child: ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.green),
            title: const Text('실시간 식물 사진 보기'),
            subtitle:
                Text('최근 업데이트: ${DateTime.now().toString().substring(11, 16)}'),
            onTap: () {
              if (imageData.startsWith('data:image')) {
                _showCameraImageDialog(context, imageData);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('유효하지 않은 이미지 데이터입니다.')),
                );
              }
            },
          ),
        );
      },
    );
  }
}
