class HouseholdMember {
  const HouseholdMember({
    required this.id,
    required this.appUserId,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    return HouseholdMember(
      id: json['id'] as String,
      appUserId: json['app_user_id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String appUserId;
  final String email;
  final String role;
  final DateTime createdAt;
}
