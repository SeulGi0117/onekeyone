import 'package:flutter/material.dart';

class QuestScreen extends StatefulWidget {
  @override
  _QuestScreenState createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  bool _showAllDailyQuests = false;
  bool _showAllWeeklyQuests = false;

  final List<String> dailyQuests = [
    '아침 출석하기',
    '물 주기',
    '3시간 동안 햇빛 쬐기',
    '상시 모니터링 확인하기',
    '식물 성장 기록하기',
    '영양제 주기',
    '잎 닦아주기',
    '온도 체크하기',
  ];

  final List<String> weeklyQuests = [
    '물 5번 주기',
    '10일 동안 건강한 상태 유지하기',
    '일주일 동안 식물 행복하게 하기',
    '새 화분으로 옮겨심기',
    '친구에게 식물 자랑하기',
    '식물 사진 찍기',
    '식물 관련 책 읽기',
    '식물 영양제 구매하기',
  ];

  Widget _buildQuestList(String title, List<String> quests, bool showAll, VoidCallback onTapMore) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ...quests.take(showAll ? quests.length : 4).map((quest) => 
          CheckboxListTile(
            title: Text(quest),
            value: false,
            onChanged: (bool? value) {},
          )
        ),
        if (quests.length > 4 && !showAll)
          TextButton(
            child: Text('더보기'),
            onPressed: onTapMore,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('퀘스트'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuestList('일일 퀘스트', dailyQuests, _showAllDailyQuests, () {
                setState(() {
                  _showAllDailyQuests = true;
                });
              }),
              SizedBox(height: 20),
              _buildQuestList('누적 퀘스트', weeklyQuests, _showAllWeeklyQuests, () {
                setState(() {
                  _showAllWeeklyQuests = true;
                });
              }),
            ],
          ),
        ),
      ),
    );
  }
}
