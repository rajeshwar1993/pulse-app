class Connection {
  final String id;
  final String fromUserId;
  final String toUserId;
  final DateTime createdAt;
  final DateTime? removedAt;
  final String? removedBy;

  Connection({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.createdAt,
    this.removedAt,
    this.removedBy,
  });

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      id: json['id'],
      fromUserId: json['from_user_id'],
      toUserId: json['to_user_id'],
      createdAt: DateTime.parse(json['created_at']),
      removedAt: json['removed_at'] != null
          ? DateTime.parse(json['removed_at'])
          : null,
      removedBy: json['removed_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'created_at': createdAt.toIso8601String(),
      'removed_at': removedAt?.toIso8601String(),
      'removed_by': removedBy,
    };
  }

  bool get isActive => removedAt == null;
  bool get isRemoved => removedAt != null;
}
