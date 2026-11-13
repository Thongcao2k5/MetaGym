class AdminUserItem {
  const AdminUserItem({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    required this.status,
    this.memberLimit,
    this.createdAt,
  });

  factory AdminUserItem.fromJson(Map<String, dynamic> json) => AdminUserItem(
    id: json['id'] as String,
    email: json['email'] as String,
    fullName: json['fullName'] as String? ?? 'Chưa đặt tên',
    phone: json['phone'] as String?,
    role: json['role'] as String? ?? 'MEMBER',
    status: json['status'] as String? ?? 'ACTIVE',
    memberLimit: json['memberLimit'] as int?,
    createdAt: json['createdAt'] as String?,
  );

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String role;
  final String status;
  final int? memberLimit;
  final String? createdAt;

  bool get isActive => status == 'ACTIVE';
  bool get isCoach => role == 'COACH';
  bool get isMember => role == 'MEMBER';

  String get roleLabel => switch (role) {
    'COACH' => 'Huấn luyện viên',
    'ADMIN' => 'Quản trị viên',
    _ => 'Hội viên',
  };
}

class AdminPlanItem {
  const AdminPlanItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.durationDays,
    required this.status,
  });

  factory AdminPlanItem.fromJson(Map<String, dynamic> json) => AdminPlanItem(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    price: (json['price'] as num).toInt(),
    durationDays: json['durationDays'] as int,
    status: json['status'] as String? ?? 'ACTIVE',
  );

  final String id;
  final String name;
  final String? description;
  final int price;
  final int durationDays;
  final String status;

  bool get isActive => status == 'ACTIVE';
}
