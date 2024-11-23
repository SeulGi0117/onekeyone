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
            _buildPlantInfoTab(),
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
              const SizedBox(height: 12),
              _buildGrowthReportCard(),
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
                      // 온도 상태
                      StreamBuilder<DatabaseEvent>(
                        stream: _sensorStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData ||
                              snapshot.data?.snapshot.value == null) {
                            return _buildHealthRow(
                              Icons.thermostat,
                              '온도 상태',
                              '측정중...',
                              Colors.grey,
                            );
                          }

                          final sensorData = Map<String, dynamic>.from(
                              snapshot.data!.snapshot.value as Map);
                          final temperature = double.tryParse(sensorData['온도']
                                  .toString()
                                  .replaceAll(RegExp(r'[^0-9.]'), '')) ??
                              0.0;

                          final plantInfo = widget.plant['plantInfo'];
                          if (plantInfo == null ||
                              plantInfo['environmentInfo'] == null) {
                            return _buildHealthRow(
                              Icons.thermostat,
                              '온도 상태',
                              '${temperature.toStringAsFixed(1)}°C',
                              Colors.blue,
                            );
                          }

                          // 온도 범위 파싱 (예: "18~25°C" -> [18, 25])
                          final temperatureRange = plantInfo['environmentInfo']
                                  ['growthTemperature']
                              .toString()
                              .replaceAll(RegExp(r'[^0-9~]'), '')
                              .split('~')
                              .map((s) => double.tryParse(s) ?? 0.0)
                              .toList();

                          if (temperatureRange.length != 2) {
                            return _buildHealthRow(
                              Icons.thermostat,
                              '온도 상태',
                              '${temperature.toStringAsFixed(1)}°C',
                              Colors.blue,
                            );
                          }

                          final minTemp = temperatureRange[0];
                          final maxTemp = temperatureRange[1];

                          Color statusColor;
                          String statusText;
                          String additionalInfo;

                          if (temperature < minTemp) {
                            statusColor = Colors.orange;
                            statusText = '적정수준 미달';
                            additionalInfo =
                                '권장 온도: ${minTemp.toStringAsFixed(0)}~${maxTemp.toStringAsFixed(0)}°C';
                          } else if (temperature > maxTemp) {
                            statusColor = Colors.red;
                            statusText = '적정수준 초과';
                            additionalInfo =
                                '권장 온도: ${minTemp.toStringAsFixed(0)}~${maxTemp.toStringAsFixed(0)}°C';
                          } else {
                            statusColor = Colors.blue;
                            statusText = '적정수준';
                            additionalInfo = '현재 온도가 적정 범위 내에 있습니다';
                          }

                          return _buildHealthRow(
                            Icons.thermostat,
                            '온도 상태',
                            statusText,
                            statusColor,
                            additionalInfo:
                                '현재 온도: ${temperature.toStringAsFixed(1)}°C (${minTemp.toStringAsFixed(0)}~${maxTemp.toStringAsFixed(0)}°C)',
                          );
                        },
                      ),
                      // 조도 상태 (온도 다음으로 이동)
                      StreamBuilder<DatabaseEvent>(
                        stream: _sensorStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData ||
                              snapshot.data?.snapshot.value == null) {
                            return _buildHealthRow(
                              Icons.wb_sunny,
                              '조도 상태',
                              '측정중...',
                              Colors.grey,
                            );
                          }

                          final sensorData = Map<String, dynamic>.from(
                              snapshot.data!.snapshot.value as Map);
                          final lightValue = double.tryParse(sensorData['조도']
                                  .toString()
                                  .replaceAll(RegExp(r'[^0-9.]'), '')) ??
                              0.0;

                          // 조도 범위 설정 (800~10000 lux)
                          const minLight = 800.0;
                          const maxLight = 10000.0;

                          Color statusColor;
                          String statusText;
                          String additionalInfo;

                          if (lightValue < minLight) {
                            statusColor = Colors.orange; // 미달
                            statusText = '적정수준 미달';
                            additionalInfo =
                                '권장 조도: ${minLight.toStringAsFixed(0)}~${maxLight.toStringAsFixed(0)} lux';
                          } else if (lightValue > maxLight) {
                            statusColor = Colors.red; // 초과
                            statusText = '적정수준 초과';
                            additionalInfo =
                                '권장 조도: ${minLight.toStringAsFixed(0)}~${maxLight.toStringAsFixed(0)} lux';
                          } else {
                            statusColor = Colors.blue; // 적정
                            statusText = '적정수준';
                            additionalInfo = '현재 조도가 적정 범위 내에 있습니다';
                          }

                          return _buildHealthRow(
                            Icons.wb_sunny,
                            '조도 상태',
                            statusText,
                            statusColor,
                            additionalInfo:
                                '현재 조도: ${lightValue.toStringAsFixed(1)} lux (${minLight.toStringAsFixed(0)}~${maxLight.toStringAsFixed(0)} lux)',
                          );
                        },
                      ),
                      // 토양 수분 상태
                      StreamBuilder<DatabaseEvent>(
                        stream: _sensorStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData ||
                              snapshot.data?.snapshot.value == null) {
                            return _buildHealthRow(
                              Icons.water_drop,
                              '토양 수분 상태',
                              '측정중...',
                              Colors.grey,
                            );
                          }

                          final sensorData = Map<String, dynamic>.from(
                              snapshot.data!.snapshot.value as Map);
                          final soilMoisture = double.tryParse(
                                  sensorData['토양습도']
                                      .toString()
                                      .replaceAll(RegExp(r'[^0-9.]'), '')) ??
                              0.0;

                          final plantInfo = widget.plant['plantInfo'];
                          if (plantInfo == null ||
                              plantInfo['environmentInfo'] == null) {
                            return _buildHealthRow(
                              Icons.water_drop,
                              '토양 수분 상태',
                              '${soilMoisture.toStringAsFixed(1)}%',
                              Colors.blue,
                            );
                          }

                          // 습도 범위 파싱 (예: "60~70%" -> [60, 70])
                          final humidityRange = plantInfo['environmentInfo']
                                  ['humidity']
                              .toString()
                              .replaceAll(RegExp(r'[^0-9~]'), '')
                              .split('~')
                              .map((s) => double.tryParse(s) ?? 0.0)
                              .toList();

                          if (humidityRange.length != 2) {
                            return _buildHealthRow(
                              Icons.water_drop,
                              '토양 수분 상태',
                              '${soilMoisture.toStringAsFixed(1)}%',
                              Colors.blue,
                            );
                          }

                          final minHumidity = humidityRange[0];
                          final maxHumidity = humidityRange[1];

                          Color statusColor;
                          String statusText;
                          String additionalInfo;

                          if (soilMoisture < minHumidity) {
                            statusColor = Colors.orange;
                            statusText = '적정수준 미달';
                            additionalInfo =
                                '권장 습도: ${minHumidity.toStringAsFixed(0)}~${maxHumidity.toStringAsFixed(0)}%';
                          } else if (soilMoisture > maxHumidity) {
                            statusColor = Colors.red;
                            statusText = '적정수준 초과';
                            additionalInfo =
                                '권장 습도: ${minHumidity.toStringAsFixed(0)}~${maxHumidity.toStringAsFixed(0)}%';
                          } else {
                            statusColor = Colors.blue;
                            statusText = '적정수준';
                            additionalInfo = '현재 습도가 적정 범위 내에 있습니다';
                          }

                          return _buildHealthRow(
                            Icons.water_drop,
                            '토양 수분 상태',
                            statusText,
                            statusColor == Colors.blue
                                ? Colors.blue
                                : statusColor,
                            additionalInfo:
                                '현재 습도: ${soilMoisture.toStringAsFixed(1)}% (${minHumidity.toStringAsFixed(0)}~${maxHumidity.toStringAsFixed(0)}%)',
                          );
                        },
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

  Widget _buildPlantInfoTab() {
    final plantInfo = widget.plant['plantInfo'] as Map<String, dynamic>?;

    if (plantInfo == null) {
      return const Center(child: Text('식물 정보를 찾을 수 없습니다'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plantInfo['images'] != null &&
              (plantInfo['images'] as List).isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (plantInfo['images'] as List).length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        plantInfo['images'][index],
                        width: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),

          // 기본 정보
          _buildInfoSection('기본 정보', [
            if (plantInfo['koreanName'] != null)
              _buildInfoRow('한글명', plantInfo['koreanName']),
            if (plantInfo['englishName'] != null)
              _buildInfoRow('영문명', plantInfo['englishName']),
            if (plantInfo['scientificName'] != null)
              _buildInfoRow('학명', plantInfo['scientificName']),
            if (plantInfo['familyCode'] != null)
              _buildInfoRow('과명', plantInfo['familyCode']),
            if (plantInfo['origin'] != null)
              _buildInfoRow('원산지', plantInfo['origin']),
            if (plantInfo['classification'] != null)
              _buildInfoRow('분류', plantInfo['classification']),
            if (plantInfo['growthType'] != null)
              _buildInfoRow('생육형태', plantInfo['growthType']),
            if (plantInfo['ecologyType'] != null)
              _buildInfoRow('생태', plantInfo['ecologyType']),
          ]),

          // 생육 정보
          if (plantInfo['growthInfo'] != null &&
              (plantInfo['growthInfo'] as Map).isNotEmpty)
            _buildInfoSection('생육 정보', [
              if (plantInfo['growthInfo']['height'] != null)
                _buildInfoRow('성장 높이', plantInfo['growthInfo']['height']),
              if (plantInfo['growthInfo']['width'] != null)
                _buildInfoRow('성장 너비', plantInfo['growthInfo']['width']),
              if (plantInfo['leafPattern'] != null)
                _buildInfoRow('잎무늬', plantInfo['leafPattern']),
              if (plantInfo['smell'] != null)
                _buildInfoRow('냄새', plantInfo['smell']),
            ]),

          // 관리 정보
          if (plantInfo['managementInfo'] != null &&
              (plantInfo['managementInfo'] as Map).isNotEmpty)
            _buildInfoSection('관리 방법', [
              if (plantInfo['managementInfo']['level'] != null)
                _buildInfoRow('관리 난이도', plantInfo['managementInfo']['level']),
              if (plantInfo['managementInfo']['demand'] != null)
                _buildInfoRow('관리요구도', plantInfo['managementInfo']['demand']),
              if (plantInfo['placementLocation'] != null)
                _buildInfoRow('배치 장소', plantInfo['placementLocation']),
              if (plantInfo['managementInfo']['special'] != null)
                _buildInfoRow('특별관리', plantInfo['managementInfo']['special']),
            ]),

          // 병충해 정보 섹션 추가 (기존 병충해 관리 정보와 함께 표시)
          if (plantInfo['pestInfo'] != null ||
              plantInfo['pestControlInfo'] != null)
            _buildInfoSection('병충해 정보', [
              if (plantInfo['pestInfo'] != null)
                _buildInfoRow('발생 병충해', plantInfo['pestInfo']),
              if (plantInfo['pestControlInfo'] != null)
                _buildInfoRow('관리 방법', plantInfo['pestControlInfo']),
            ]),

          // 환경 정보
          if (plantInfo['environmentInfo'] != null &&
              (plantInfo['environmentInfo'] as Map).isNotEmpty)
            _buildInfoSection('환경 정보', [
              if (plantInfo['environmentInfo']['light'] != null)
                _buildInfoRow('빛 요구도', plantInfo['environmentInfo']['light']),
              if (plantInfo['environmentInfo']['humidity'] != null)
                _buildInfoRow('습도', plantInfo['environmentInfo']['humidity']),
              if (plantInfo['environmentInfo']['growthTemperature'] != null)
                _buildInfoRow(
                    '생육 온도', plantInfo['environmentInfo']['growthTemperature']),
              if (plantInfo['environmentInfo']['winterTemperature'] != null)
                _buildInfoRow('겨울 최저온도',
                    plantInfo['environmentInfo']['winterTemperature']),
            ]),

          // 물 주기 정보
          if (plantInfo['waterCycle'] != null &&
              (plantInfo['waterCycle'] as Map).isNotEmpty)
            _buildInfoSection('물 주기', [
              if (plantInfo['waterCycle']['spring'] != null)
                _buildInfoRow('봄', plantInfo['waterCycle']['spring']),
              if (plantInfo['waterCycle']['summer'] != null)
                _buildInfoRow('여름', plantInfo['waterCycle']['summer']),
              if (plantInfo['waterCycle']['autumn'] != null)
                _buildInfoRow('가을', plantInfo['waterCycle']['autumn']),
              if (plantInfo['waterCycle']['winter'] != null)
                _buildInfoRow('겨울', plantInfo['waterCycle']['winter']),
            ]),

          // 기능성 정보
          if (plantInfo['functionInfo'] != null)
            _buildInfoSection('기능성 정보', [
              Text(plantInfo['functionInfo']),
            ]),

          // 독성 정보
          if (plantInfo['toxicity'] != null)
            _buildInfoSection('독성 정보', [
              Text(plantInfo['toxicity']),
            ]),
        ],
      ),
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

  Widget _buildHealthRow(IconData icon, String label, String value, Color color,
      {String? additionalInfo}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (additionalInfo != null)
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                additionalInfo,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontStyle: FontStyle.italic,
                ),
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

  Widget _buildGrowthReportCard() {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.note_alt, color: Colors.green),
            title: const Text('성장 보고서'),
            subtitle: const Text('식물의 성장 과정을 기록해보세요!'),
            onTap: () => _showGrowthReportDialog(),
          ),
        ),
        const SizedBox(height: 12),
        // 성장 보고서 일지 목록
        StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance
              .ref()
              .child('growth_reports')
              .child(widget.plant['id'])
              .child('reports')
              .onValue,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('아직 작성된 성장 보고서가 없습니다'),
                ),
              );
            }

            final reports =
                Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
            final sortedReports = reports.entries.toList()
              ..sort((a, b) {
                final dateA = DateTime.parse(a.value['date']);
                final dateB = DateTime.parse(b.value['date']);
                return dateB.compareTo(dateA); // 최신순 정렬
              });

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '성장 일지',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...sortedReports.map((report) {
                      final date = DateTime.parse(report.value['date']);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: InkWell(
                          onTap: () => _showReportDetailDialog(
                            Map<String, dynamic>.from(report.value),
                            report.key,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          report.value['title'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${date.year}.${date.month}.${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () => _deleteReport(report.key),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                report.value['content'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Divider(),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 성장 보고서 삭제 메서드 추가
  void _deleteReport(String reportId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('성장 보고서 삭제'),
        content: const Text('이 보고서를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseDatabase.instance
                    .ref()
                    .child('growth_reports')
                    .child(widget.plant['id'])
                    .child('reports')
                    .child(reportId)
                    .remove();

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('성장 보고서가 삭제되었습니다'),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                print('보고서 삭제 오류: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // _showGrowthReportDialog 메서드 수정
  void _showGrowthReportDialog(
      {Map<String, dynamic>? existingReport, String? reportId}) {
    final TextEditingController titleController =
        TextEditingController(text: existingReport?['title'] ?? '');
    final TextEditingController reportController =
        TextEditingController(text: existingReport?['content'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingReport != null ? '성장 보고서 수정' : '성장 보고서 작성'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '제목을 입력해주세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reportController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '내용',
                hintText: '식물의 성장 과정이나 특이사항을 기록해보세요',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final title = titleController.text.trim();
                final reportContent = reportController.text.trim();
                if (title.isNotEmpty && reportContent.isNotEmpty) {
                  final reportsRef = FirebaseDatabase.instance
                      .ref()
                      .child('growth_reports')
                      .child(widget.plant['id'])
                      .child('reports');

                  if (existingReport != null && reportId != null) {
                    // 기존 보고서 수정
                    await reportsRef.child(reportId).update({
                      'title': title,
                      'content': reportContent,
                      'lastEdited': DateTime.now().toIso8601String(),
                    });
                  } else {
                    // 새 보고서 작성
                    await reportsRef.push().set({
                      'title': title,
                      'content': reportContent,
                      'date': DateTime.now().toIso8601String(),
                    });

                    // 성장 보고서 퀘스트 진행도 업데이트
                    final questRef = FirebaseDatabase.instance
                        .ref()
                        .child('quests/growth_report');
                    final questSnapshot = await questRef.get();

                    if (questSnapshot.exists) {
                      final questData =
                          Map<String, dynamic>.from(questSnapshot.value as Map);
                      final currentProgress = questData['progress'] ?? 0;
                      final isRewarded = questData['rewarded'] ?? false;

                      if (!isRewarded && currentProgress < 3) {
                        await questRef.update({
                          'progress': currentProgress + 1,
                          'lastUpdate': DateTime.now().toIso8601String(),
                        });
                      }
                    }
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(existingReport != null
                          ? '성장 보고서가 수정되었습니다'
                          : '성장 보고서가 저장되었습니다'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('제목과 내용��� 모두 입력해주세요'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                print('성장 보고서 저장 오류: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('저장 중 오류가 발생했습니다'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text(existingReport != null ? '수정' : '저장'),
          ),
        ],
      ),
    );
  }

  // 보고서 상세 내용을 보여주는 다이얼로그 수정
  void _showReportDetailDialog(Map<String, dynamic> report, String reportId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report['title']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateTime.parse(report['date']).toString().substring(0, 16),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            if (report['lastEdited'] != null) ...[
              Text(
                '마지막 수정: ${DateTime.parse(report['lastEdited']).toString().substring(0, 16)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(report['content']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showGrowthReportDialog(
                  existingReport: report, reportId: reportId);
            },
            child: const Text('수정', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }
}
