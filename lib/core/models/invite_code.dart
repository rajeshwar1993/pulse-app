class InviteCode {
  final String id;
  final String code;
  final String creatorId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? acceptedBy;
  final DateTime? acceptedAt;

  InviteCode({
    required this.id,
    required this.code,
    required this.creatorId,
    required this.createdAt,
    required this.expiresAt,
    this.acceptedBy,
    this.acceptedAt,
  });

  factory InviteCode.fromJson(Map<String, dynamic> json) {
    return InviteCode(
      id: json['id'],
      code: json['code'],
      creatorId: json['creator_id'],
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: DateTime.parse(json['expires_at']),
      acceptedBy: json['accepted_by'],
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'creator_id': creatorId,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'accepted_by': acceptedBy,
      'accepted_at': acceptedAt?.toIso8601String(),
    };
  }

  InviteCode copyWith({
    String? id,
    String? code,
    String? creatorId,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? acceptedBy,
    DateTime? acceptedAt,
  }) {
    return InviteCode(
      id: id ?? this.id,
      code: code ?? this.code,
      creatorId: creatorId ?? this.creatorId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isAccepted => acceptedBy != null;
  bool get isValid => !isExpired && !isAccepted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InviteCode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          creatorId == other.creatorId &&
          createdAt == other.createdAt &&
          expiresAt == other.expiresAt &&
          acceptedBy == other.acceptedBy &&
          acceptedAt == other.acceptedAt;

  @override
  int get hashCode => Object.hash(
        id,
        code,
        creatorId,
        createdAt,
        expiresAt,
        acceptedBy,
        acceptedAt,
      );

  @override
  String toString() =>
      'InviteCode(code: $code, creator: $creatorId, valid: $isValid)';
}
