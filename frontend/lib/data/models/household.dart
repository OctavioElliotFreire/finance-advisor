class Household {
  const Household({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.role,
  });

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      role: json['role'] as String,
    );
  }

  final String id;
  final String name;
  final DateTime createdAt;
  final String role;
}
