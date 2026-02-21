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

  Connection copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    DateTime? createdAt,
    DateTime? removedAt,
    String? removedBy,
  }) {
    return Connection(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      createdAt: createdAt ?? this.createdAt,
      removedAt: removedAt ?? this.removedAt,
      removedBy: removedBy ?? this.removedBy,
    );
  }

  bool get isActive => removedAt == null;
  bool get isRemoved => removedAt != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Connection &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fromUserId == other.fromUserId &&
          toUserId == other.toUserId &&
          createdAt == other.createdAt &&
          removedAt == other.removedAt &&
          removedBy == other.removedBy;

  @override
  int get hashCode => Object.hash(
        id,
        fromUserId,
        toUserId,
        createdAt,
        removedAt,
        removedBy,
      );

  @override
  String toString() =>
      'Connection(id: $id, from: $fromUserId, to: $toUserId, active: $isActive)';
}
