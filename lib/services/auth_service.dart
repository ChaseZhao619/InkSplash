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
}
