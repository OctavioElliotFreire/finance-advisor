import 'dart:convert';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
    required this.email,
  });

  factory AuthSession.fromSupabaseJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (json['expires_at'] as int) * 1000,
        isUtc: true,
      ),
      userId: user['id'] as String,
      email: user['email'] as String? ?? '',
    );
  }

  /// Builds a session from Supabase's invite/magic-link redirect fragment
  /// (`#access_token=...&refresh_token=...&expires_at=...&type=invite`),
  /// which — unlike the normal login/signup token response — carries no
  /// nested `user` object. `userId`/`email` come from decoding the access
  /// token's own JWT payload instead of an extra `/auth/v1/user` call.
  factory AuthSession.fromInviteRedirectFragment(Map<String, String> fragment) {
    final accessToken = fragment['access_token']!;
    final claims = _decodeJwtPayload(accessToken);
    return AuthSession(
      accessToken: accessToken,
      refreshToken: fragment['refresh_token']!,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        int.parse(fragment['expires_at']!) * 1000,
        isUtc: true,
      ),
      userId: claims['sub'] as String,
      email: claims['email'] as String? ?? '',
    );
  }

  static Map<String, dynamic> _decodeJwtPayload(String token) {
    final payload = base64Url.normalize(token.split('.')[1]);
    return jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;
  }

  factory AuthSession.fromStorageJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      userId: json['userId'] as String,
      email: json['email'] as String,
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String userId;
  final String email;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  Map<String, dynamic> toStorageJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'userId': userId,
    'email': email,
  };
}
