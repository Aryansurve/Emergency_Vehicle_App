import 'dart:convert';

class User {
  final String id;
  final String role;
  final String verificationStatus;

  User({
    required this.id,
    required this.role,
    required this.verificationStatus,
  });

  // A factory constructor to create a User from the JWT payload
  factory User.fromToken(String token) {
    final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1])))
    );
    return User(
      id: payload['id'],
      role: payload['role'],
      verificationStatus: payload['verificationStatus'],
    );
  }
}