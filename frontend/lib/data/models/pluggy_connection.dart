class PluggyConnection {
  const PluggyConnection({
    required this.id,
    required this.pluggyItemId,
    required this.status,
    required this.createdAt,
    this.createdById,
    this.createdByEmail,
  });

  factory PluggyConnection.fromJson(Map<String, dynamic> json) {
    final createdBy = json['created_by'] as Map<String, dynamic>?;
    return PluggyConnection(
      id: json['id'] as String,
      pluggyItemId: json['pluggy_item_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdById: createdBy?['id'] as String?,
      createdByEmail: createdBy?['email'] as String?,
    );
  }

  final String id;
  final String pluggyItemId;
  final String status;
  final DateTime createdAt;
  final String? createdById;
  final String? createdByEmail;
}
