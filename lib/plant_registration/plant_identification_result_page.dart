import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'plant_detail_page.dart'; // 새로 만들 페이지
import '../services/nongsaro_api_service.dart';  // 추가

class PlantIdentificationResultPage extends StatelessWidget {
  final String imagePath;
  final List<Map<String, dynamic>> plantResults;

  const PlantIdentificationResultPage({
    Key? key,
    required this.imagePath,
    required this.plantResults,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 가장 높은 유사도를 가진 식물 찾기
    final highestProbabilityPlant = plantResults.reduce((a, b) => 
      (a['probability'] as double) > (b['probability'] as double) ? a : b);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('식물 분석 결과'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI 분석 안내 메시지
              const Text(
                'AI가 당신이 촬영한 사진을 분석하였어요.\n내 식물과 가장 비슷한 식물을 선택해주세요!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // 촬영한 이미지
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePath),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              
              // 가장 유사한 식물 정보
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  '이 식물은 ${highestProbabilityPlant['plant_name']}와(과) '
                  '${(highestProbabilityPlant['probability'] * 100).toStringAsFixed(1)}% 유사해요!',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              
              // 유사한 식물 목록 헤더
              const Text(
                '유사한 식물 목록',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // 유사한 식물 목록
              ...plantResults.take(4).map((plant) => PlantResultItemWithImage(
                plantName: plant['plant_name'],
                probability: plant['probability'],
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }
}

class PlantResultItemWithImage extends StatefulWidget {
  final String plantName;
  final double probability;

  const PlantResultItemWithImage({
    Key? key,
    required this.plantName,
    required this.probability,
  }) : super(key: key);

  @override
  _PlantResultItemWithImageState createState() => _PlantResultItemWithImageState();
}

class _PlantResultItemWithImageState extends State<PlantResultItemWithImage> {
  String? imageUrl;
  String? koreanName;

  @override
  void initState() {
    super.initState();
    fetchWikipediaInfo();
  }

  Future<void> fetchWikipediaInfo() async {
    final englishResponse = await http.get(Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&titles=${widget.plantName}&prop=pageimages|langlinks&lllang=ko&format=json&pithumbsize=100'));

    if (englishResponse.statusCode == 200) {
      final data = json.decode(englishResponse.body);
      final pages = data['query']['pages'];
      final pageId = pages.keys.first;
      final page = pages[pageId];

      setState(() {
        if (page.containsKey('thumbnail')) {
          imageUrl = page['thumbnail']['source'];
        }
        if (page.containsKey('langlinks') && page['langlinks'].isNotEmpty) {
          koreanName = page['langlinks'][0]['*'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // 학명에서 공백과 특수문자를 _로 변환
        String searchName = widget.plantName
            .replaceAll('.', '_')
            .replaceAll('[', '_')
            .replaceAll(']', '_')
            .replaceAll('#', '_')
            .replaceAll(' ', '_')
            .replaceAll('(', '_')
            .replaceAll(')', '_')
            .replaceAll('/', '_')
            .replaceAll('\\', '_')
            .replaceAll(',', '_')
            .replaceAll('\'', '_')
            .replaceAll('"', '_');

        // 로딩 표시
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        try {
          // 농사로 API에서 식물 정보 가져오기
          final plantDetails = await NongsaroApiService().getPlantDetails(
            widget.plantName,
            scientificName: searchName,
          );

          // 로딩 다이얼로그 닫기
          Navigator.pop(context);

          if (plantDetails != null) {
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (context) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 헤더 부분
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.eco, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plantDetails['koreanName'] ?? widget.plantName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    // 내용 부분
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 이미지 섹션
                            if (plantDetails['images'] != null && 
                                (plantDetails['images'] as List).isNotEmpty)
                              SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: (plantDetails['images'] as List).length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          plantDetails['images'][index],
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
                            _buildSection('기본 정보', [
                              _buildInfoRow('한글명', plantDetails['koreanName'] ?? '-'),
                              _buildInfoRow('영문명', plantDetails['englishName'] ?? '-'),
                              _buildInfoRow('학명', plantDetails['scientificName'] ?? '-'),
                              _buildInfoRow('과명', plantDetails['familyCode'] ?? '-'),
                              _buildInfoRow('원산지', plantDetails['origin'] ?? '-'),
                            ]),

                            // 생육 정보
                            if (plantDetails['growthInfo'] != null)
                              _buildSection('생육 정보', [
                                _buildInfoRow('성장 높이', plantDetails['growthInfo']['height'] ?? '-'),
                                _buildInfoRow('성장 너비', plantDetails['growthInfo']['width'] ?? '-'),
                              ]),

                            // 나머지 섹션들도 동일한 방식으로 추가...
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('식물 정보를 찾을 수 없습니다')),
            );
          }
        } catch (e) {
          // 로딩 다이얼로그 닫기
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('식물 정보를 불러오는데 실패했습니다: $e')),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.plantName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (koreanName != null)
                    Text(
                      koreanName!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  SizedBox(height: 4),
                  Text(
                    '유사도: ${(widget.probability * 100).toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            if (imageUrl != null)
              Image.network(
                imageUrl!,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              )
            else
              Container(
                width: 100,
                height: 100,
                color: Colors.grey[300],
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _buildSection(String title, List<Widget> children) {
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
