class AnomalySummary {
  const AnomalySummary({
    required this.id,
    required this.transactionId,
    required this.householdMemberId,
    required this.rule,
    required this.severity,
    required this.score,
    required this.summary,
    required this.status,
    required this.explanation,
    required this.explainedAt,
    required this.createdAt,
  });

  factory AnomalySummary.fromJson(Map<String, dynamic> json) {
    return AnomalySummary(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String?,
      householdMemberId: json['household_member_id'] as String?,
      rule: json['rule'] as String,
      severity: json['severity'] as String,
      score: (json['score'] as num?)?.toDouble(),
      summary: json['summary'] as String,
      status: json['status'] as String,
      explanation: json['explanation'] as String?,
      explainedAt: json['explained_at'] == null
          ? null
          : DateTime.parse(json['explained_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String? transactionId;
  final String? householdMemberId;
  final String rule;
  final String severity;
  final double? score;
  final String summary;
  final String status;
  final String? explanation;
  final DateTime? explainedAt;
  final DateTime createdAt;

  AnomalySummary copyWith({
    String? status,
    String? explanation,
    DateTime? explainedAt,
  }) {
    return AnomalySummary(
      id: id,
      transactionId: transactionId,
      householdMemberId: householdMemberId,
      rule: rule,
      severity: severity,
      score: score,
      summary: summary,
      status: status ?? this.status,
      explanation: explanation ?? this.explanation,
      explainedAt: explainedAt ?? this.explainedAt,
      createdAt: createdAt,
    );
  }
}
