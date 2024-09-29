import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'plant_detail_page.dart'; // 새로 만들 페이지

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
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (koreanName != null)
                    Text(
                      koreanName!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  SizedBox(height: 4),
                  Text(
                    '유사도: ${(widget.probability * 100).toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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