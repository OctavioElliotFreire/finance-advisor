import 'household_member.dart';

class InviteSummary {
  const InviteSummary({
    required this.id,
    required this.email,
    required this.role,
    required this.expiresAt,
    required this.acceptedAt,
    required this.createdAt,
  });

  factory InviteSummary.fromJson(Map<String, dynamic> json) {
    return InviteSummary(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String email;
  final String role;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime createdAt;
}

class InviteResult {
  const InviteResult({required this.outcome, this.member, this.invite});

  factory InviteResult.fromJson(Map<String, dynamic> json) {
    return InviteResult(
      outcome: json['outcome'] as String,
      member: json['member'] == null
          ? null
          : HouseholdMember.fromJson(json['member'] as Map<String, dynamic>),
      invite: json['invite'] == null
          ? null
          : InviteSummary.fromJson(json['invite'] as Map<String, dynamic>),
    );
  }

  final String outcome;
  final HouseholdMember? member;
  final InviteSummary? invite;
}

class InvitePreview {
  const InvitePreview({
    required this.householdName,
    required this.email,
    required this.role,
    required this.expired,
    required this.accepted,
  });

  factory InvitePreview.fromJson(Map<String, dynamic> json) {
    return InvitePreview(
      householdName: json['household_name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      expired: json['expired'] as bool,
      accepted: json['accepted'] as bool,
    );
  }

  final String householdName;
  final String email;
  final String role;
  final bool expired;
  final bool accepted;
}

class AcceptInviteResult {
  const AcceptInviteResult({required this.householdId, required this.householdName});

  factory AcceptInviteResult.fromJson(Map<String, dynamic> json) {
    return AcceptInviteResult(
      householdId: json['household_id'] as String,
      householdName: json['household_name'] as String,
    );
  }

  final String householdId;
  final String householdName;
}
