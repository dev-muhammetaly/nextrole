enum UserRole {
  employee,
  employer,
  admin;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'employer':
        return UserRole.employer;
      case 'employee':
      default:
        return UserRole.employee;
    }
  }

  String toDbString() => name;
}

class UserProfile {
  final String id;
  final String? fullName;
  final UserRole role;
  final String? companyName;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    this.fullName,
    required this.role,
    this.companyName,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      role: UserRole.fromString(json['role'] as String? ?? 'employee'),
      companyName: json['company_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role.toDbString(),
      'company_name': companyName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
