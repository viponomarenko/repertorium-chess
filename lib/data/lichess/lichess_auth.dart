/// Lichess OAuth2 PKCE login (F-LI-01..04).
///
/// Public, unregistered client: `client_id` = bundle id; redirect through a
/// reverse-domain custom scheme (`app.tabiya://oauth`). AppAuth performs
/// PKCE with S256, the only method Lichess accepts.
library;

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants.dart';

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

/// Keychain / Keystore storage. The token never goes to the database,
/// logs or backups (9.3).
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();
  static const key = 'lichess_token';
  final FlutterSecureStorage _s;

  String? _cache;
  bool _loaded = false;

  @override
  Future<String?> read() async {
    if (_loaded) return _cache;
    _cache = await _s.read(key: key);
    _loaded = true;
    return _cache;
  }

  @override
  Future<void> write(String token) async {
    await _s.write(key: key, value: token);
    _cache = token;
    _loaded = true;
  }

  @override
  Future<void> delete() async {
    await _s.delete(key: key);
    _cache = null;
    _loaded = true;
  }
}

class LichessOAuth {
  LichessOAuth({FlutterAppAuth? appAuth}) : _appAuth = appAuth ?? const FlutterAppAuth();
  final FlutterAppAuth _appAuth;

  static const readScopes = ['study:read'];
  static const writeScopes = ['study:read', 'study:write'];

  /// Opens the Lichess login page and returns an access token.
  /// Throws on cancellation / failure.
  Future<String> login({List<String> scopes = readScopes}) async {
    final r = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        AppInfo.bundleId,
        AppInfo.oauthRedirect,
        scopes: scopes,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: 'https://lichess.org/oauth',
          tokenEndpoint: 'https://lichess.org/api/token',
        ),
      ),
    );
    final token = r.accessToken;
    if (token == null || token.isEmpty) throw StateError('No access token');
    return token;
  }
}
