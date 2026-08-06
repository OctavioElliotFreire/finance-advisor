class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.question,
    required this.answer,
    required this.askedByEmail,
    required this.createdAt,
  });

  factory AssistantMessage.fromJson(Map<String, dynamic> json) {
    return AssistantMessage(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      askedByEmail: json['asked_by_email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String question;
  final String answer;
  final String askedByEmail;
  final DateTime createdAt;
}
