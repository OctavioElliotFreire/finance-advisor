class PluggyConnection {
  const PluggyConnection({
    required this.id,
    required this.pluggyItemId,
    required this.status,
    required this.createdAt,
  });

  factory PluggyConnection.fromJson(Map<String, dynamic> json) {
    return PluggyConnection(
      id: json['id'] as String,
      pluggyItemId: json['pluggy_item_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String pluggyItemId;
  final String status;
  final DateTime createdAt;
}
