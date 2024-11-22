import 'package:flutter/material.dart';
import 'dart:io';
import '../services/nongsaro_api_service.dart';

class PlantDetailScreen extends StatefulWidget {
  final String plantName;
  final String imagePath;
  final String? probability;
  final String? scientificName;

  PlantDetailScreen({
    required this.plantName,
    required this.imagePath,
    this.probability,
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
    _loadPlantDetails();
  }

  Future<void> _loadPlantDetails() async {
    try {
      final details = await _apiService.getPlantDetails(
        widget.plantName,
      );

      setState(() {
        plantDetails = details;
        isLoading = false;
      });

      if (details == null && mounted) {
        final detailsByScientificName = await _apiService.getPlantDetails(
          widget.plantName,
          scientificName: widget.plantName,
        );

        setState(() {
          plantDetails = detailsByScientificName;
        });

        if (detailsByScientificName == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('식물 정보를 찾을 수 없습니다.')),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plantDetails?['koreanName'] ?? widget.plantName),
      ),
      body: isLoading 
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    children: [
                      Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                      if (plantDetails?['imageUrl']?.isNotEmpty ?? false)
                        Image.network(
                          plantDetails!['imageUrl'],
                          fit: BoxFit.contain,
                          width: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container();
                          },
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection('기본 정보', [
                        _buildInfoRow('한글명', plantDetails?['koreanName'] ?? '-'),
                        _buildInfoRow('영문명', plantDetails?['englishName'] ?? '-'),
                        _buildInfoRow('학명', plantDetails?['scientificName'] ?? '-'),
                        _buildInfoRow('과명', plantDetails?['familyName'] ?? '-'),
                        _buildInfoRow('원산지', plantDetails?['origin'] ?? '-'),
                      ]),
                      _buildSection('식물 특성', [
                        _buildInfoRow('성장 높이', plantDetails?['growthHeight'] ?? '-'),
                        _buildInfoRow('성장 너비', plantDetails?['growthWidth'] ?? '-'),
                        _buildInfoRow('잎 특성', plantDetails?['leafInfo'] ?? '-'),
                        _buildInfoRow('꽃 특성', plantDetails?['flowerInfo'] ?? '-'),
                      ]),
                      _buildSection('관리 방법', [
                        _buildInfoRow('관리 난이도', plantDetails?['managementLevel'] ?? '-'),
                        _buildInfoRow('빛 요구도', plantDetails?['lightDemand'] ?? '-'),
                        _buildInfoRow('생육 온도', plantDetails?['temperature']?['growth'] ?? '-'),
                        _buildInfoRow('겨울 최저온도', plantDetails?['temperature']?['winter'] ?? '-'),
                        _buildInfoRow('습도', plantDetails?['humidity'] ?? '-'),
                      ]),
                      _buildSection('물 주기', [
                        _buildInfoRow('봄', plantDetails?['waterCycle']?['spring'] ?? '-'),
                        _buildInfoRow('여름', plantDetails?['waterCycle']?['summer'] ?? '-'),
                        _buildInfoRow('가을', plantDetails?['waterCycle']?['autumn'] ?? '-'),
                        _buildInfoRow('겨울', plantDetails?['waterCycle']?['winter'] ?? '-'),
                      ]),
                      if (plantDetails?['specialManagement']?.isNotEmpty ?? false)
                        _buildSection('특별 관리', [
                          Text(plantDetails!['specialManagement']),
                        ]),
                      if (plantDetails?['toxicity']?.isNotEmpty ?? false)
                        _buildSection('독성 정보', [
                          Text(plantDetails!['toxicity']),
                        ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
