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

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isAccepted => acceptedBy != null;
  bool get isValid => !isExpired && !isAccepted;
}
