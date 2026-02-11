class Profile {
  final String id;
  final String email;
  final String displayName;
  final String avatarUrl;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.timezone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String,
      timezone: json['timezone'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'timezone': timezone,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Profile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? timezone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
