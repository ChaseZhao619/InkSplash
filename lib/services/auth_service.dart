import '../models.dart';
import 'api_client.dart';

class AuthService {
  const AuthService(this._api);

  final EpaperApiClient _api;

  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    final json = await _api.postJson(
      '/api/auth/register',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(json);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _api.postJson(
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(json);
  }

  Future<User> me(String bearerToken) async {
    final json = await _api.getJson('/api/me', bearerToken: bearerToken);
    return User.fromJson(json);
  }

  Future<void> requestEmailVerification(String bearerToken) async {
    await _api.postJson(
      '/api/auth/verify-email/request',
      bearerToken: bearerToken,
    );
  }

  Future<User> confirmEmailVerification({required String token}) async {
    final json = await _api.postJson(
      '/api/auth/verify-email/confirm',
      body: {'token': token},
    );
    return User.fromJson(json);
  }

  Future<void> requestPasswordReset({required String email}) async {
    await _api.postJson(
      '/api/auth/password-reset/request',
      body: {'email': email},
    );
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    await _api.postJson(
      '/api/auth/password-reset/confirm',
      body: {'token': token, 'new_password': newPassword},
    );
  }
}
