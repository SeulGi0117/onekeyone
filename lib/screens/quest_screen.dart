import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/database_service.dart'; // DatabaseService import 추가

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});

  @override
  _QuestScreenState createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  final bool _isWateringDetected = false;
  final DatabaseReference _questRef =
      FirebaseDatabase.instance.ref().child('quests');
  final DatabaseReference _plantsRef =
      FirebaseDatabase.instance.ref().child('plants');
  DateTime? _lastResetDate;
  int _coins = 0;
  final DatabaseReference _coinsRef =
      FirebaseDatabase.instance.ref().child('coins');

  @override
  void initState() {
    super.initState();
    _initializeQuests();
    _loadCoins();
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

  // 퀘스트 데이터 예시
  final List<Map<String, dynamic>> quests = [
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
      'title': '식물 컬렉터',
      'description': '식물 3종류 등록하기',
      'progress': 0,
      'goal': 3,
      'reward': 200,
      'icon': Icons.collections,
      'type': 'collection',
      'rewarded': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일일 퀘스트'),
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
      ),
      body: Column(
        children: [
          // 상단 진행 상황 카드
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '오늘의 퀘스트 진행률',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '4/9',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: 4 / 9,
                      backgroundColor: Colors.grey[200],
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.green),
                      minHeight: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 퀘스트 목록
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _questRef.onValue,
              builder: (context, questSnapshot) {
                // 퀘스트 데이터 업데이트
                if (questSnapshot.hasData &&
                    questSnapshot.data?.snapshot.value != null) {
                  final questData = Map<String, dynamic>.from(
                      questSnapshot.data!.snapshot.value as Map);

                  // 퀘스트 진행도 업데이트
                  for (var quest in quests) {
                    switch (quest['type']) {
                      case 'watering':
                        quest['progress'] =
                            questData['watering']?['progress'] ?? 0;
                        quest['rewarded'] =
                            questData['watering']?['rewarded'] ?? false;
                        break;
                      case 'observation':
                        quest['progress'] =
                            questData['observation']?['progress'] ?? 0;
                        quest['rewarded'] =
                            questData['observation']?['rewarded'] ?? false;
                        break;
                      case 'collection':
                        quest['progress'] =
                            questData['collection']?['progress'] ?? 0;
                        quest['rewarded'] =
                            questData['collection']?['rewarded'] ?? false;
                        break;
                    }
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: quests.length,
                  itemBuilder: (context, index) {
                    final quest = quests[index];
                    final progress = quest['progress'];
                    final goal = quest['goal'];
                    final progressPercent = progress / goal;

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
                                      sensorSnapshot.data?.snapshot.value !=
                                          null) {
                                    final sensorData =
                                        Map<String, dynamic>.from(sensorSnapshot
                                            .data!.snapshot.value as Map);
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
                                          const AlwaysStoppedAnimation<Color>(
                                        Colors.green,
                                      ),
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
                                    onPressed: quest['rewarded']
                                        ? null
                                        : () async {
                                            await _updateCoins(
                                                quest['reward'] as int);
                                            // 보상 수령 상태 업데이트
                                            await _questRef
                                                .child(quest['type'])
                                                .update({
                                              'rewarded': true,
                                            });
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    '${quest['reward']} 코인이 지급되었습니다!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: quest['rewarded']
                                          ? Colors.grey
                                          : Colors.green,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: Text(
                                      quest['rewarded'] ? '보상 수령 완료' : '보상 수령',
                                      style: TextStyle(
                                        color: quest['rewarded']
                                            ? Colors.grey[400]
                                            : Colors.white,
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
              },
            ),
          ),
        ],
      ),
    );
  }

  // ... 기존 메서드들 유지
}
