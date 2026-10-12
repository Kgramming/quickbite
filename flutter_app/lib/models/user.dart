import 'package:equatable/equatable.dart';

enum UserRole { customer, admin }

class User extends Equatable {
  final String id;
  final String email;
  final String name;
  final UserRole role;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'customer';
    final role = roleStr == 'admin' ? UserRole.admin : UserRole.customer;

    return User(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: role,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.toString().split('.').last,
      };

  @override
  List<Object?> get props => [id, email, name, role];
}

class AuthResponse extends Equatable {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final User user;

  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int? ?? 86400,
      user: User.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        'expires_in': expiresIn,
        'user': user.toJson(),
      };

  @override
  List<Object?> get props => [accessToken, tokenType, expiresIn, user];
}
