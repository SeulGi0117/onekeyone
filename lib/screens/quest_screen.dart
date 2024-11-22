import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/database_service.dart'; // DatabaseService import 추가

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});

  @override
  _QuestScreenState createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen>
    with SingleTickerProviderStateMixin {
  final bool _isWateringDetected = false;
  final DatabaseReference _questRef =
      FirebaseDatabase.instance.ref().child('quests');
  final DatabaseReference _plantsRef =
      FirebaseDatabase.instance.ref().child('plants');
  DateTime? _lastResetDate;
  int _coins = 0;
  final DatabaseReference _coinsRef =
      FirebaseDatabase.instance.ref().child('coins');
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2개의 탭
    _loadCoins();

    // 모든 퀘스트 초기화
    _resetAllQuests();

    // 출석 체크 퀘스트 업데이트 추가
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateAttendanceQuest();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeQuests() async {
    final snapshot = await _questRef.get();
    if (!snapshot.exists) {
      _resetDailyQuests(); // 최초 초기화
    } else {
      // 마지막 초기화 날짜 확인
      final questData = Map<String, dynamic>.from(snapshot.value as Map);
      if (questData['lastResetDate'] != null) {
        _lastResetDate = DateTime.parse(questData['lastResetDate']);

        // 날짜가 바뀌었는지 확인
        if (_shouldResetQuests()) {
          _resetDailyQuests();
        }
      } else {
        _resetDailyQuests();
      }
    }

    // 식물 컬렉터 퀘스트 업데이트를 위한 plants 노드 리스너
    _plantsRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final plants = Map<String, dynamic>.from(event.snapshot.value as Map);
        _updateCollectionQuest(plants.length);
      }
    });

    // 자정 체크를 위한 타이머 설정
    _setupDailyResetTimer();
  }

  // 자정 체크를 위한 타이머 설정
  void _setupDailyResetTimer() {
    // 다음 자정까지의 시간 계산
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);

    // 자정에 실행될 타이머 설정
    Future.delayed(timeUntilMidnight, () {
      _resetDailyQuests();
      _setupDailyResetTimer(); // 다음 날을 위해 타이머 재설정
    });
  }

  // 퀘스트 초기화가 필요한지 확인
  bool _shouldResetQuests() {
    if (_lastResetDate == null) return true;

    final now = DateTime.now();
    final lastReset = _lastResetDate!;

    return now.year != lastReset.year ||
        now.month != lastReset.month ||
        now.day != lastReset.day;
  }

  // 일일 퀘스트 초기화
  Future<void> _resetDailyQuests() async {
    final now = DateTime.now();
    await _questRef.update({
      'watering': {
        'progress': 0,
        'goal': 1,
        'lastUpdate': null,
        'rewarded': false, // 보상 수령 상태도 초기화
      },
      'observation': {
        'progress': 0,
        'lastUpdate': null,
        'rewarded': false,
      },
      'lastResetDate': now.toIso8601String(),
    });
    _lastResetDate = now;
  }

  // 물주기 퀘스트 업데이트 메서드 수정
  Future<void> _updateWateringQuest(double soilMoisture) async {
    if (_shouldResetQuests()) {
      await _resetDailyQuests();
      return;
    }

    final snapshot = await _questRef.child('watering').get();
    if (snapshot.exists) {
      final questData = Map<String, dynamic>.from(snapshot.value as Map);
      final currentProgress = questData['progress'] ?? 0;

      if (soilMoisture >= 50 && !_isWateringDetected && currentProgress < 3) {
        await _questRef.child('watering').update({
          'progress': currentProgress + 1,
          'lastUpdate': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  Future<void> _updateCollectionQuest(int plantCount) async {
    await _questRef.child('collection').update({'progress': plantCount});
  }

  // 코인 로드 메서드 추가
  Future<void> _loadCoins() async {
    final snapshot = await _coinsRef.get();
    if (snapshot.exists) {
      setState(() {
        _coins = (snapshot.value as int?) ?? 0;
      });
    } else {
      await _coinsRef.set(0);
    }
  }

  // 코인 업데이트 메서드 추가
  Future<void> _updateCoins(int amount) async {
    final newAmount = _coins + amount;
    await _coinsRef.set(newAmount);
    setState(() {
      _coins = newAmount;
    });
  }

  // 일일 퀘스트 목록 업데이트
  final List<Map<String, dynamic>> dailyQuests = [
    {
      'title': '물주기 마스터',
      'description': '식물에 물주기 3회 완료하기',
      'progress': 0,
      'goal': 3,
      'reward': 100,
      'icon': Icons.water_drop,
      'type': 'watering',
      'rewarded': false,
    },
    {
      'title': '햇빛 관리',
      'description': '3시간 동안 조도 200lux 유지하기',
      'progress': 0,
      'goal': 1,
      'reward': 100,
      'icon': Icons.wb_sunny,
      'type': 'sunlight',
      'rewarded': false,
    },
    {
      'title': '출석 체크',
      'description': '앱 접속하기',
      'progress': 0,
      'goal': 1,
      'reward': 50,
      'icon': Icons.check_circle,
      'type': 'attendance',
      'rewarded': false,
    },
    {
      'title': '관찰의 달인',
      'description': '식물 상태 체크 5회 하기',
      'progress': 0,
      'goal': 5,
      'reward': 150,
      'icon': Icons.visibility,
      'type': 'observation',
      'rewarded': false,
    },
    {
      'title': '성장 일지 작성',
      'description': '성장 보고서 3회 작성하기',
      'progress': 0,
      'goal': 3,
      'reward': 200,
      'icon': Icons.edit_note,
      'type': 'growth_report',
      'rewarded': false,
    },
  ];

  // 누적 퀘스트 목록 추가
  final List<Map<String, dynamic>> totalQuests = [
    {
      'title': '식물 컬렉터',
      'description': '식물 3종류 등록하기',
      'progress': 0,
      'goal': 3,
      'reward': 200,
      'icon': Icons.collections,
      'type': 'collection',
      'rewarded': false,
    },
    {
      'title': '이름 짓기 마스터',
      'description': '식물 별명 지어주기',
      'progress': 0,
      'goal': 1,
      'reward': 50,
      'icon': Icons.edit,
      'type': 'nickname',
      'rewarded': false,
      'currentStage': 1,
    },
    {
      'title': '물주기 달인',
      'description': '누적 물주기 5회 달성하기',
      'progress': 0,
      'goal': 5,
      'reward': 100,
      'icon': Icons.water_drop,
      'type': 'total_watering',
      'rewarded': false,
      'currentStage': 1,
    },
    {
      'title': '출석 챔피언',
      'description': '10일 연속 출석하기',
      'progress': 0,
      'goal': 10,
      'reward': 300,
      'icon': Icons.calendar_month,
      'type': 'consecutive_attendance',
      'rewarded': false,
    },
  ];

  // AppBar 부분 수정
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('퀘스트'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Row(
            children: [
              const Icon(
                Icons.monetization_on,
                color: Colors.amber,
              ),
              const SizedBox(width: 4),
              Text(
                '$_coins',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '일일 퀘스트'),
            Tab(text: '누적 퀘스트'),
          ],
          labelColor: Colors.green,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuestList(dailyQuests), // 일일 퀘스트 목록
          _buildQuestList(totalQuests), // 누적 퀘스트 목록
        ],
      ),
    );
  }

  // 퀘스트 목록 빌드 메서드
  Widget _buildQuestList(List<Map<String, dynamic>> quests) {
    return StreamBuilder<DatabaseEvent>(
      stream: _questRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final questData =
              Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);

          // 퀘스트 데이터 업데이트
          for (var quest in quests) {
            final type = quest['type'];
            if (questData[type] != null) {
              final questInfo =
                  Map<String, dynamic>.from(questData[type] as Map);
              quest['progress'] = questInfo['progress'] ?? 0;
              quest['rewarded'] = questInfo['rewarded'] ?? false;
            }
          }
        }

        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref().onValue,
          builder: (context, jsonSnapshot) {
            if (jsonSnapshot.hasData &&
                jsonSnapshot.data?.snapshot.value != null) {
              final rootData = Map<String, dynamic>.from(
                  jsonSnapshot.data!.snapshot.value as Map);
              int wateringCount = 0;

              // 각 JSON 노드 확인
              for (var jsonNode in ['JSON', 'JSON2', 'JSON3']) {
                if (rootData[jsonNode]?['ESP32SENSOR'] != null) {
                  final sensorData = Map<String, dynamic>.from(
                      rootData[jsonNode]['ESP32SENSOR'] as Map);
                  final soilMoisture = _parseSoilMoisture(sensorData['토양습도']);

                  // 토양습도가 50% 이상인 경우 카운트 증가
                  if (soilMoisture >= 50) {
                    wateringCount++;
                  }
                }
              }

              // 물주기 퀘스트 업데이트
              for (var quest in quests) {
                if (quest['type'] == 'watering' &&
                    !(quest['rewarded'] ?? false)) {
                  final newProgress =
                      wateringCount > 3 ? 3 : wateringCount; // 최대 3회로 제한
                  quest['progress'] = newProgress;
                  _questRef.child('watering').update({
                    'progress': newProgress,
                    'lastUpdate': DateTime.now().toIso8601String(),
                  });
                }
              }
            }

            // 식물 컬렉터 퀘스트 업데이트
            if (quests.any((quest) => quest['type'] == 'collection')) {
              return StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance.ref().child('plants').onValue,
                builder: (context, plantsSnapshot) {
                  if (plantsSnapshot.hasData &&
                      plantsSnapshot.data?.snapshot.value != null) {
                    final plants = Map<String, dynamic>.from(
                        plantsSnapshot.data!.snapshot.value as Map);
                    final plantCount = plants.length;

                    for (var quest in quests) {
                      if (quest['type'] == 'collection') {
                        quest['progress'] = plantCount;
                        _questRef.child('collection').update({
                          'progress': plantCount,
                          'lastUpdate': DateTime.now().toIso8601String(),
                        });
                      }
                    }
                  }
                  return _buildQuestListView(quests);
                },
              );
            }

            return _buildQuestListView(quests);
          },
        );
      },
    );
  }

  // 퀘스트 목록 UI 부분을 별도 메서드로 분리
  Widget _buildQuestListView(List<Map<String, dynamic>> quests) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: quests.length,
      itemBuilder: (context, index) {
        final quest = quests[index];
        final progress = quest['progress'];
        final goal = quest['goal'];
        final progressPercent = progress / goal;
        final bool isRewarded = quest['rewarded'] ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      quest['icon'] as IconData,
                      color: Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      quest['title'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  quest['description'],
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                if (quest['type'] == 'watering')
                  StreamBuilder<DatabaseEvent>(
                    stream: FirebaseDatabase.instance
                        .ref()
                        .child('JSON/ESP32SENSOR')
                        .onValue,
                    builder: (context, sensorSnapshot) {
                      if (sensorSnapshot.hasData &&
                          sensorSnapshot.data?.snapshot.value != null) {
                        final sensorData = Map<String, dynamic>.from(
                            sensorSnapshot.data!.snapshot.value as Map);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '현재 토양습도: ${sensorData['토양습도'] ?? '측정중...'}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: Colors.grey[200],
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.green),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$progress/$goal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${quest['reward']} 코인',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (progress >= goal)
                      ElevatedButton(
                        onPressed: isRewarded
                            ? null
                            : () async {
                                try {
                                  // 보상 수령 전에 현재 상태 다시 확인
                                  final currentSnapshot = await _questRef
                                      .child(quest['type'])
                                      .get();
                                  if (currentSnapshot.exists) {
                                    final currentData =
                                        Map<String, dynamic>.from(
                                            currentSnapshot.value as Map);
                                    if (currentData['rewarded'] == true) {
                                      setState(() {
                                        quest['rewarded'] = true;
                                      });
                                      return;
                                    }
                                  }

                                  // 보상 지급 및 상태 업데이트
                                  await _updateCoins(quest['reward'] as int);
                                  await _questRef.child(quest['type']).update({
                                    'rewarded': true,
                                    'lastUpdate':
                                        DateTime.now().toIso8601String(),
                                  });

                                  setState(() {
                                    quest['rewarded'] = true;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${quest['reward']} 코인이 지급되었습니다!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  print('보상 지급 오류: $e');
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isRewarded ? Colors.grey : Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          isRewarded ? '완료' : '보상 수령',
                          style: TextStyle(
                            color: isRewarded ? Colors.grey[400] : Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 출도 값 파싱 메서드 추가
  double _parseLuxValue(dynamic value) {
    if (value == null) return 0;
    String strValue = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(strValue) ?? 0;
  }

  // 토양습도 값 파싱 메서드 추가
  double _parseSoilMoisture(dynamic value) {
    if (value == null) return 0;
    String strValue = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(strValue) ?? 0;
  }

  // 출석 체크 퀘스트 업데이트 메서드 수정
  Future<void> _updateAttendanceQuest() async {
    final questRef = FirebaseDatabase.instance.ref().child('quests');
    final snapshot = await questRef.get();

    try {
      if (snapshot.exists) {
        final questData = Map<String, dynamic>.from(snapshot.value as Map);
        final lastUpdate = questData['attendance']?['lastUpdate'] != null
            ? DateTime.parse(questData['attendance']['lastUpdate'])
            : null;
        final now = DateTime.now();

        // 마지막 업데이트가 오늘이 아닌 경우에만 업데이트
        if (lastUpdate == null ||
            lastUpdate.day != now.day ||
            lastUpdate.month != now.month ||
            lastUpdate.year != now.year) {
          // 일일 출석 퀘스트 업데이트
          await questRef.child('attendance').update({
            'progress': 1,
            'lastUpdate': now.toIso8601String(),
            'rewarded': false,
            'goal': 1,
          });

          // 연속 출석 퀘스트 업데이트
          final consecutiveRef = questRef.child('consecutive_attendance');
          final consecutiveSnapshot = await consecutiveRef.get();

          if (consecutiveSnapshot.exists) {
            final consecutiveData =
                Map<String, dynamic>.from(consecutiveSnapshot.value as Map);
            final lastConsecutiveDate = consecutiveData['lastUpdate'] != null
                ? DateTime.parse(consecutiveData['lastUpdate'])
                : null;

            // 어제 출석했는지 확인
            if (lastConsecutiveDate != null &&
                lastConsecutiveDate.difference(now).inDays.abs() == 1) {
              // 연속 출석 증가
              final currentProgress = consecutiveData['progress'] ?? 0;
              if (currentProgress < 10 &&
                  !(consecutiveData['rewarded'] ?? false)) {
                await consecutiveRef.update({
                  'progress': currentProgress + 1,
                  'lastUpdate': now.toIso8601String(),
                });
              }
            } else if (lastConsecutiveDate == null ||
                lastConsecutiveDate.difference(now).inDays.abs() > 1) {
              // 연속 출석 초기화
              await consecutiveRef.update({
                'progress': 1,
                'lastUpdate': now.toIso8601String(),
                'rewarded': false,
              });
            }
          } else {
            // 최초 연속 출석 시작
            await consecutiveRef.set({
              'progress': 1,
              'goal': 10,
              'lastUpdate': now.toIso8601String(),
              'rewarded': false,
            });
          }
        }
      } else {
        // 최초 실행 시
        await questRef.set({
          'attendance': {
            'progress': 1,
            'goal': 1,
            'lastUpdate': DateTime.now().toIso8601String(),
            'rewarded': false,
          },
          'consecutive_attendance': {
            'progress': 1,
            'goal': 10,
            'lastUpdate': DateTime.now().toIso8601String(),
            'rewarded': false,
          },
        });
      }
    } catch (e) {
      print('출석 퀘스트 업데이트 오류: $e');
    }
  }

  // _QuestScreenState 클래스에 초기화 메서드 추가
  Future<void> _resetAllQuests() async {
    try {
      final now = DateTime.now();
      final questRef = FirebaseDatabase.instance.ref().child('quests');

      // 현재 퀘스트 상태 확인
      final snapshot = await questRef.get();
      Map<String, dynamic> currentQuestData = {};

      if (snapshot.exists) {
        currentQuestData = Map<String, dynamic>.from(snapshot.value as Map);
        final lastUpdate = currentQuestData['lastResetDate'] != null
            ? DateTime.parse(currentQuestData['lastResetDate'])
            : null;

        // 날짜가 바뀌지 않았다면 rewarded 상태 유지
        if (lastUpdate != null &&
            lastUpdate.day == now.day &&
            lastUpdate.month == now.month &&
            lastUpdate.year == now.year) {
          return; // 같은 날이면 초기화하지 않음
        }
      }

      // 날짜가 바뀌었거나 데이터가 없는 경우 초기화
      await questRef.set({
        'watering': {
          'progress': 0,
          'goal': 3, // 3회로 수정
          'lastUpdate': now.toIso8601String(),
          'rewarded': false,
        },
        'sunlight': {
          'progress': 0,
          'goal': 1,
          'lastUpdate': now.toIso8601String(),
          'rewarded': false,
        },
        'attendance': {
          'progress': 0,
          'goal': 1,
          'lastUpdate': null,
          'rewarded': false,
        },
        'observation': {
          'progress': 0,
          'goal': 5,
          'lastUpdate': now.toIso8601String(),
          'rewarded': false,
        },
        'growth_report': {
          'progress': 0,
          'goal': 3,
          'lastUpdate': now.toIso8601String(),
          'rewarded': false,
        },
        'lastResetDate': now.toIso8601String(),
      });

      setState(() {});
    } catch (e) {
      print('퀘스트 초기화 오류: $e');
    }
  }

  // ... 기존 메서드들 유지
}
