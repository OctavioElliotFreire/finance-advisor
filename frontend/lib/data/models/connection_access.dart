class ConnectionAccessEntry {
  const ConnectionAccessEntry({
    required this.connectionId,
    required this.pluggyItemId,
    required this.status,
    required this.granted,
  });

  factory ConnectionAccessEntry.fromJson(Map<String, dynamic> json) {
    return ConnectionAccessEntry(
      connectionId: json['connection_id'] as String,
      pluggyItemId: json['pluggy_item_id'] as String,
      status: json['status'] as String,
      granted: json['granted'] as bool,
    );
  }

  final String connectionId;
  final String pluggyItemId;
  final String status;
  final bool granted;

  ConnectionAccessEntry copyWith({bool? granted}) {
    return ConnectionAccessEntry(
      connectionId: connectionId,
      pluggyItemId: pluggyItemId,
      status: status,
      granted: granted ?? this.granted,
    );
  }
}
