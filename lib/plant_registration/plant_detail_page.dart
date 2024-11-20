import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PlantDetailPage extends StatefulWidget {
  final String plantName;
  final String? koreanName;
  final String? imageUrl; // 이미지 URL 추가

  const PlantDetailPage({
    Key? key,
    required this.plantName,
    this.koreanName,
    this.imageUrl, // 생성자에 이미지 URL 추가
  }) : super(key: key);

  @override
  _PlantDetailPageState createState() => _PlantDetailPageState();
}

class _PlantDetailPageState extends State<PlantDetailPage> {
  String? description;
  Map<String, String>? classification;
  String? scientificName;

  @override
  void initState() {
    super.initState();
    fetchWikipediaDetails();
  }

  Future<void> fetchWikipediaDetails() async {
    // 한국어 페이지 먼저 시도
    var response = await http.get(Uri.parse(
        'https://ko.wikipedia.org/w/api.php?action=query&titles=${widget.koreanName ?? widget.plantName}&prop=extracts|revisions&exintro&format=json&rvprop=content'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final pages = data['query']['pages'];
      final pageId = pages.keys.first;
      final page = pages[pageId];

      if (page['pageid'] != null) {
        // 한국어 페이지가 존재하는 경우
        setState(() {
          if (page.containsKey('extract')) {
            description = page['extract'];
          }
          // 분류 정보와 학명 추출
          extractClassificationAndScientificName(page['revisions'][0]['*']);
        });
      } else {
        // 한국어 페이지가 없는 경우, 영어 페이지 시도
        fetchEnglishWikipediaDetails();
      }
    } else {
      // 요청 실패 시 영어 페이지 시도
      fetchEnglishWikipediaDetails();
    }
  }

  Future<void> fetchEnglishWikipediaDetails() async {
    // ... 기존의 영어 위키피디아 요청 코드 ...
    // 분류 정보와 학명 추출 로직 추가
  }

  void extractClassificationAndScientificName(String wikiContent) {
    // 정규 표현식을 사용하여 분류 정보와 학명 추출
    // 이 부분은 위키피디아의 구조에 따라 조정이 필요할 수 있습니다
    classification = {
      '계 (Kingdom)': extractValue(wikiContent, r'계\s*=\s*(.+)|Kingdom\s*=\s*(.+)') ?? '',
      '문 (Phylum)': extractValue(wikiContent, r'문\s*=\s*(.+)|Phylum\s*=\s*(.+)') ?? '',
      '강 (Class)': extractValue(wikiContent, r'강\s*=\s*(.+)|Class\s*=\s*(.+)') ?? '',
      '목 (Order)': extractValue(wikiContent, r'목\s*=\s*(.+)|Order\s*=\s*(.+)') ?? '',
      '과 (Family)': extractValue(wikiContent, r'과\s*=\s*(.+)|Family\s*=\s*(.+)') ?? '',
      '속 (Genus)': extractValue(wikiContent, r'속\s*=\s*(.+)|Genus\s*=\s*(.+)') ?? '',
      '종 (Species)': extractValue(wikiContent, r'종\s*=\s*(.+)|Species\s*=\s*(.+)') ?? '',
      '생태 (Growth)': extractValue(wikiContent, r'생태\s*=\s*(.+)|Growth\s*=\s*(.+)') ?? '',
    };

    // Clade 정보 추출
    List<String> clades = extractMultipleValues(wikiContent, r'Clade\s*=\s*(.+)');
    classification ??= {}; // classification이 null이면 빈 맵으로 초기화
    for (int i = 0; i < clades.length; i++) {
      classification!['분류군 ${i + 1} (Clade ${i + 1})'] = clades[i];
    }
  }

  String? extractValue(String content, String pattern) {
    final match = RegExp(pattern).firstMatch(content);
    return match?.group(1)?.trim();
  }

  List<String> extractMultipleValues(String content, String pattern) {
    final matches = RegExp(pattern).allMatches(content);
    return matches.map((match) => match.group(1)?.trim() ?? '').toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.koreanName ?? widget.plantName),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.imageUrl != null)
                Image.network(
                  widget.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              SizedBox(height: 16),
              Text(
                widget.plantName,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (widget.koreanName != null)
                Text(
                  widget.koreanName!,
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              SizedBox(height: 16),
              if (classification != null)
                Table(
                  children: classification!.entries.map((entry) {
                    return TableRow(
                      children: [
                        Text(entry.key, style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(entry.value),
                      ],
                    );
                  }).toList(),
                ),
              if (scientificName != null)
                Text('학명: $scientificName', style: TextStyle(fontStyle: FontStyle.italic)),
              SizedBox(height: 16),
              if (description != null)
                Text(description!)
              else
                CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}