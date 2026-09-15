import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api/api_client.dart';
import 'auth_models.dart';

/// Owns the access token and the auth endpoints. The token lives in the
/// platform keychain, never in plain preferences.
class AuthRepository {
  AuthRepository({ApiClient? client, FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    _client = client ?? ApiClient(readToken: readToken);
  }

  static const _tokenKey = 'wavelength.access_token';

  late final ApiClient _client;
  final FlutterSecureStorage _storage;

  ApiClient get client => _client;

  String? _cachedToken;

  Future<String?> readToken() async {
    if (_cachedToken != null) return _cachedToken;
    try {
      return _cachedToken = await _storage.read(key: _tokenKey);
    } on Exception {
      // Keychain unavailable (e.g. an unsigned desktop build) - treat as
      // signed out rather than crashing on launch.
      return null;
    }
  }

  Future<void> _writeToken(String token) async {
    _cachedToken = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } on Exception {
      // Non-fatal: the session still works for this run, just won't persist.
    }
  }

  Future<OtpRequestResult> requestOtp(String identifier) async {
    final json = await _client.post('/auth/request-otp', body: {'identifier': identifier});
    return OtpRequestResult.fromJson(json);
  }

  /// Verifies the code and stores the returned token before returning.
  Future<CurrentUser> verifyOtp(String identifier, String code) async {
    final json = await _client.post(
      '/auth/verify-otp',
      body: {'identifier': identifier, 'code': code},
    );
    await _writeToken(json['token'] as String);
    return fetchMe();
  }

  Future<CurrentUser> fetchMe() async {
    return CurrentUser.fromJson(await _client.get('/me'));
  }

  Future<void> signOut() async {
    _cachedToken = null;
    try {
      await _storage.delete(key: _tokenKey);
    } on Exception {
      // Already gone.
    }
  }
}
