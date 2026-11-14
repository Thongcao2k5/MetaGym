enum UserRole {
  member,
  coach,
  admin;

  static UserRole fromApi(Object? value) => switch (value) {
    'MEMBER' => UserRole.member,
    'COACH' => UserRole.coach,
    'ADMIN' => UserRole.admin,
    _ => throw const FormatException('Vai trò người dùng không hợp lệ.'),
  };
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
    this.phone,
    this.avatarUrl,
    this.profile = const {},
  });

  factory AuthUser.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      role: UserRole.fromApi(json['role']),
      status: json['status'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      profile: json['profile'] is Map
          ? Map<String, dynamic>.from(json['profile'] as Map)
          : const {},
    );
  }

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String status;
  final String? phone;
  final String? avatarUrl;
  final Map<String, dynamic> profile;
}

class AuthSession {
  const AuthSession({required this.accessToken, required this.user});

  factory AuthSession.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return AuthSession(
      accessToken: json['accessToken'] as String,
      user: AuthUser.fromJson(json['user']),
    );
  }

  final String accessToken;
  final AuthUser user;
}
