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
              Text(
                '식물 분석',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(imagePath),
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '유사한 식물',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlantDetailPage(
              plantName: widget.plantName,
              koreanName: koreanName,
              imageUrl: imageUrl, // 이미지 URL 전달
            ),
          ),
        );
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

void _showPlantInfo(BuildContext context, Map<String, dynamic> plant) {
  // 학명에서 공백과 특수문자를 _로 변환
  String searchName = plant['scientific_name'] ?? plant['name'];
  searchName = searchName
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

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(plant['name']),
            bottom: TabBar(
              tabs: [
                Tab(text: '실시간 데이터'),
                Tab(text: '식물 정보'),
              ],
              labelColor: Colors.green,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.green,
            ),
          ),
          body: TabBarView(
            children: [
              Center(child: Text('실시간 데이터는 식물 등록 후 확인할 수 있습니다.')),
              FutureBuilder<Map<String, dynamic>?>(
                future: NongsaroApiService().getPlantDetails(
                  plant['name'],
                  scientificName: searchName,  // 변환된 학명 전달
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('오류가 발생했습니다: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData) {
                    // 첫 번째 시도 실패 시, 학명 뒤에 _를 추가하여 다시 시도
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: NongsaroApiService().getPlantDetails(
                        plant['name'],
                        scientificName: '${searchName}_',  // 학명 뒤에 _ 추가
                      ),
                      builder: (context, retrySnapshot) {
                        if (retrySnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final plantDetails = retrySnapshot.data;
                        if (plantDetails == null) {
                          return const Center(
                            child: Text('식물 정보를 찾을 수 없습니다.'),
                          );
                        }

                        return _buildPlantInfoView(plantDetails);
                      },
                    );
                  }

                  return _buildPlantInfoView(snapshot.data!);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildPlantInfoView(Map<String, dynamic> plantDetails) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plantDetails['images'] != null && (plantDetails['images'] as List).isNotEmpty)
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
        _buildInfoSection('기본 정보', [
          _buildInfoRow('한글명', plantDetails['koreanName'] ?? '-'),
          _buildInfoRow('영문명', plantDetails['englishName'] ?? '-'),
          _buildInfoRow('학명', plantDetails['scientificName'] ?? '-'),
          _buildInfoRow('과명', plantDetails['familyCode'] ?? '-'),
          _buildInfoRow('원산지', plantDetails['origin'] ?? '-'),
        ]),
        // 나머지 섹션들도 동일한 방식으로 표시...
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
      SizedBox(height: 8),
      ...children,
      SizedBox(height: 24),
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
