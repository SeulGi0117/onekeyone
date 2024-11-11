import 'package:flutter/material.dart';
import 'dart:io';
import '../services/nongsaro_api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PlantDetailScreen extends StatefulWidget {
  final String plantName;

  final String imagePath;

  final String? probability;

  final Map<String, dynamic>? existingDetails;

  final bool showRegisterButton;

  final String? scientificName;

  PlantDetailScreen({
    required this.plantName,
    required this.imagePath,
    this.probability,
    this.existingDetails,
    this.showRegisterButton = true,
    this.scientificName,
  });

  @override
  _PlantDetailScreenState createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  final NongsaroApiService _apiService = NongsaroApiService();

  Map<String, dynamic>? plantDetails;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    if (widget.existingDetails != null) {
      setState(() {
        plantDetails = widget.existingDetails;

        isLoading = false;
      });
    } else {
      _loadPlantDetails();
    }
  }

  Future<void> _loadPlantDetails() async {
    try {
      final details = await _apiService.getPlantDetails(
        widget.scientificName ?? widget.plantName
      );

      setState(() {
        plantDetails = details;

        isLoading = false;
      });

      if (details == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('식물 정보를 찾을 수 없습니다.')),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('식물 정보를 불러오는데 실패했습니다.')),
        );
      }
    }
  }

  Future<Map<String, String?>> getWikipediaInfo(String plantName) async {
    try {
      final enResponse = await http.get(
        Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$plantName'),
      );
      
      final krResponse = await http.get(
        Uri.parse('https://ko.wikipedia.org/api/rest_v1/page/summary/$plantName'),
      );
      
      Map<String, String?> result = {
        'image': null,
        'koreanName': null,
      };
      
      if (enResponse.statusCode == 200) {
        final enData = json.decode(enResponse.body);
        result['image'] = enData['thumbnail']?['source'];
      }
      
      if (krResponse.statusCode == 200) {
        final krData = json.decode(krResponse.body);
        result['koreanName'] = krData['title'];
      }
      
      return result;
    } catch (e) {
      print('Wikipedia API 에러: $e');
      return {'image': null, 'koreanName': null};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          plantDetails?['koreanName'] ?? 
          (widget.scientificName ?? widget.plantName),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: plantDetails != null && plantDetails!['images'].isNotEmpty
                  ? Image.network(
                      plantDetails!['images'][0],
                      fit: BoxFit.cover,
                    )
                  : FutureBuilder<Map<String, String?>>(
                      future: getWikipediaInfo(widget.scientificName ?? widget.plantName),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!['image'] != null) {
                          return Image.network(
                            snapshot.data!['image']!,
                            fit: BoxFit.cover,
                          );
                        }
                        return Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.cover,
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 학명과 한글 이름 표시
                  Text(
                    widget.scientificName ?? widget.plantName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (plantDetails?['koreanName'] != null)
                    Text(
                      plantDetails!['koreanName'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  SizedBox(height: 16),
                  _buildPlantInfo(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildCareInfo() {
    if (plantDetails == null) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Care Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        _buildInfoRow('Light', plantDetails?['lightDemand'] ?? ''),
        _buildInfoRow(
            'Water (Spring)', plantDetails?['waterCycle']['spring'] ?? ''),
        _buildInfoRow(
            'Water (Summer)', plantDetails?['waterCycle']['summer'] ?? ''),
        _buildInfoRow(
            'Water (Autumn)', plantDetails?['waterCycle']['autumn'] ?? ''),
        _buildInfoRow(
            'Water (Winter)', plantDetails?['waterCycle']['winter'] ?? ''),
        _buildInfoRow('Growth Info', plantDetails?['growthInfo'] ?? ''),
      ],
    );
  }

  Widget _buildDetailSection() {
    if (plantDetails == null) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plantDetails!['images'].isNotEmpty) ...[
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: plantDetails!['images'].length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Image.network(
                    plantDetails!['images'][index],
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16),
        ],
        _buildSection('기본 정보', [
          _buildInfoRow('한글명', plantDetails!['koreanName']),
          _buildInfoRow('영문명', plantDetails!['englishName']),
          _buildInfoRow('학명', plantDetails!['scientificName']),
          _buildInfoRow('과명', plantDetails!['familyName']),
          _buildInfoRow('원산지', plantDetails!['origin']),
        ]),
        _buildSection('생육 정보', [
          _buildInfoRow('성장 높이', plantDetails!['growthHeight']),
          _buildInfoRow('성장 넓이', plantDetails!['growthWidth']),
          _buildInfoRow('잎 특성', plantDetails!['leafInfo']),
          _buildInfoRow('꽃 특성', plantDetails!['flowerInfo']),
        ]),
        _buildSection('관리 방법', [
          _buildInfoRow('관리 난이도', plantDetails!['managementLevel']),
          _buildInfoRow('빛 요구도', plantDetails!['lightDemand']),
          _buildInfoRow('생육 온도', plantDetails!['temperature']['growth']),
          _buildInfoRow('겨울 최저온도', plantDetails!['temperature']['winter']),
          _buildInfoRow('습도', plantDetails!['humidity']),
        ]),
        _buildSection('물 주기', [
          _buildInfoRow('봄', plantDetails!['waterCycle']['spring']),
          _buildInfoRow('여름', plantDetails!['waterCycle']['summer']),
          _buildInfoRow('가을', plantDetails!['waterCycle']['autumn']),
          _buildInfoRow('겨울', plantDetails!['waterCycle']['winter']),
        ]),
        if (plantDetails!['specialManagement'].isNotEmpty)
          _buildSection('특별 관리', [
            Text(plantDetails!['specialManagement']),
          ]),
        if (plantDetails!['toxicity'].isNotEmpty)
          _buildSection('독성 정보', [
            Text(plantDetails!['toxicity']),
          ]),
        if (plantDetails!['description'].isNotEmpty)
          _buildSection('상세 설명', [
            Text(plantDetails!['description']),
          ]),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        ...children,
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPlantInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plantDetails?['koreanName'] ?? widget.plantName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          _buildSection('기본 정보', [
            _buildInfoRow('학명', plantDetails?['scientificName'] ?? '-'),
            _buildInfoRow('영명', plantDetails?['englishName'] ?? '-'),
            _buildInfoRow('과명', plantDetails?['familyName'] ?? '-'),
            _buildInfoRow('원산지', plantDetails?['origin'] ?? '-'),
          ]),
          Divider(thickness: 1),
          _buildSection('식물 특성', [
            _buildInfoRow('분류', plantDetails?['classification'] ?? '-'),
            _buildInfoRow('생육형태', plantDetails?['growthType'] ?? '-'),
            _buildInfoRow('생장 높이', plantDetails?['growthHeight'] ?? '-'),
            _buildInfoRow('생장 너비', plantDetails?['growthWidth'] ?? '-'),
            _buildInfoRow('생태형', plantDetails?['ecologyType'] ?? '-'),
          ]),
          _buildSection('생육 환경', [
            _buildInfoRow(
                '생육 적온', plantDetails?['temperature']?['growth'] ?? '-'),
            _buildInfoRow('광요구도', plantDetails?['lightDemand'] ?? '-'),
            _buildInfoRow(
                '겨울 최저온도', plantDetails?['temperature']?['winter'] ?? '-'),
            _buildInfoRow('습도', plantDetails?['humidity'] ?? '-'),
          ]),
          _buildSection('관리 정보', [
            _buildInfoRow('관리수준', plantDetails?['managementLevel'] ?? '-'),
            _buildInfoRow('관리요구도', plantDetails?['managementDemand'] ?? '-'),
            _buildInfoRow('배치장소', plantDetails?['placementLocation'] ?? '-'),
            _buildInfoRow('비료', plantDetails?['fertilizer'] ?? '-'),
            _buildInfoRow('토양', plantDetails?['soil'] ?? '-'),
          ]),
          _buildSection('물 주기', [
            _buildInfoRow('봄', plantDetails?['waterCycle']?['spring'] ?? '-'),
            _buildInfoRow('여름', plantDetails?['waterCycle']?['summer'] ?? '-'),
            _buildInfoRow('가을', plantDetails?['waterCycle']?['autumn'] ?? '-'),
            _buildInfoRow('겨울', plantDetails?['waterCycle']?['winter'] ?? '-'),
          ]),
          _buildSection('꽃 정보', [
            _buildInfoRow('꽃피는 계절', plantDetails?['floweringSeason'] ?? '-'),
            _buildInfoRow('꽃색', plantDetails?['flowerColor'] ?? '-'),
          ]),
          if (plantDetails?['toxicity'] != null &&
              plantDetails!['toxicity'].isNotEmpty)
            _buildSection('주의사항', [
              _buildInfoRow('독성', plantDetails!['toxicity']),
            ]),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(value),
        ),
      ],
    );
  }
}
