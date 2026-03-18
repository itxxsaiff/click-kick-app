import 'enums.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrl,
    this.region,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? photoUrl;
  final String? region;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': enumToName(role),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'photoUrl': photoUrl,
        'region': region,
      };
}
