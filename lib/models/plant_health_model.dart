class PlantHealthStatus {
  final String status;  // 'Healthy' 또는 질병 이름
  final String timestamp;

  PlantHealthStatus({
    required this.status,
    required this.timestamp,
  });

  factory PlantHealthStatus.fromMap(Map<String, dynamic> map) {
    return PlantHealthStatus(
      status: map['status'] ?? 'Unknown',
      timestamp: map['timestamp'] ?? DateTime.now().toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'timestamp': timestamp,
    };
  }
} 