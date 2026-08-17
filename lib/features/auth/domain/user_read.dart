class UserRead {
  const UserRead({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.isActive,
    required this.isSuperuser,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
    this.bio,
    this.avatar,
    this.pageName,
  });

  final String id;
  final String fullName;
  final String phoneNumber;
  final String role;
  final bool isActive;
  final bool isSuperuser;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? bio;
  final String? avatar;
  final String? pageName;

  bool get isCreator => role == 'creator' || role == 'admin';

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return 'GN';
    }
    final first = parts.first[0];
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return '$first$second'.toUpperCase();
  }

  factory UserRead.fromJson(Map<String, dynamic> json) {
    return UserRead(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String,
      role: json['role'] as String? ?? 'viewer',
      isActive: json['is_active'] as bool,
      isSuperuser: json['is_superuser'] as bool,
      isVerified: json['is_verified'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      bio: json['bio'] as String?,
      avatar: json['avatar'] as String?,
      pageName: json['page_name'] as String?,
    );
  }
}
