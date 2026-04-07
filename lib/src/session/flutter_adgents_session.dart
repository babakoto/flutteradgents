import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutteradgents/src/api/flutter_adgents_api_exception.dart';
import 'package:flutteradgents/src/session/flutter_adgents_auth_interceptor.dart';
import 'package:flutteradgents/src/session/flutter_adgents_token_storage.dart';

/// Réponse de `GET /api/v1/auth/oauth/atlassian/authorization-url`.
class AtlassianOAuthLoginStart {
  const AtlassianOAuthLoginStart({
    this.authorizationUrl,
    required this.configured,
  });

  final String? authorizationUrl;
  final bool configured;
}

/// Session JWT en mémoire + refresh token persisté ; met à jour l’en-tête `Authorization` du [Dio].
class FlutterAdgentsSession extends ChangeNotifier {
  FlutterAdgentsSession(this._dio, FlutterAdgentsTokenStorage tokenStorage)
      : _tokenStorage = tokenStorage;

  final Dio _dio;
  final FlutterAdgentsTokenStorage _tokenStorage;

  String? _token;
  String? _refreshToken;
  String? _jiraAccountId;

  bool get isSignedIn => _token != null;

  String? get token => _token;

  /// Utilisé par l’intercepteur pour renouveler le JWT après expiration (~15 min côté serveur).
  String? get refreshToken => _refreshToken;

  /// Renseigné après [signIn] si l’API renvoie `jiraAccountId` (profil / PATCH `/me` côté serveur).
  String? get jiraAccountId => _jiraAccountId;

  Future<void> _applyAuthPayload(Map<String, dynamic> data) async {
    if (data['token'] is! String) {
      throw FlutterAdgentsApiException('Réponse auth invalide');
    }
    _token = data['token'] as String;
    final rt = data['refreshToken'];
    _refreshToken = rt is String && rt.trim().isNotEmpty ? rt.trim() : null;
    final ja = data['jiraAccountId'];
    _jiraAccountId = ja is String && ja.trim().isNotEmpty ? ja.trim() : null;
    _dio.options.headers['Authorization'] = 'Bearer $_token';
    await _tokenStorage.write(access: _token!, refresh: _refreshToken);
    notifyListeners();
  }

  /// Relit les jetons persistés (ex. après redémarrage de l’app).
  Future<void> restorePersistedCredentials() async {
    final pair = await _tokenStorage.read();
    if (pair == null) {
      return;
    }
    _token = pair.access;
    _refreshToken = pair.refresh;
    _dio.options.headers['Authorization'] = 'Bearer $_token';
    notifyListeners();
  }

  /// `POST /api/v1/auth/refresh` — appelé par [FlutterAdgentsAuthInterceptor] ou tests.
  Future<void> refreshAccessToken() async {
    final rt = _refreshToken;
    if (rt == null || rt.isEmpty) {
      throw FlutterAdgentsApiException('Session expirée — reconnectez-vous.');
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refreshToken': rt},
        options: Options(
          extra: const {kFlutterAdgentsSkipAuthRefreshExtra: true},
        ),
      );
      final data = res.data;
      if (data == null) {
        throw FlutterAdgentsApiException('Réponse refresh vide');
      }
      await _applyAuthPayload(data);
    } on DioException catch (e) {
      throw _wrapAuth(e);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
        options: Options(
          extra: const {kFlutterAdgentsSkipAuthRefreshExtra: true},
        ),
      );
      final data = res.data;
      if (data == null) {
        throw FlutterAdgentsApiException('Réponse login vide');
      }
      await _applyAuthPayload(data);
    } on DioException catch (e) {
      throw _wrapAuth(e);
    }
  }

  /// URL Atlassian pour démarrer la connexion OAuth (même compte que l’e-mail si l’adresse correspond).
  Future<AtlassianOAuthLoginStart> getAtlassianLoginAuthorizationUrl({
    String? inviteToken,

    /// URL du front où l’API redirige après OAuth (`?oauth_exchange=` ou `?oauth_error=`).
    /// Doit être autorisée côté serveur (`login-completion-frontend-uri` ou préfixes configurés).
    String? returnUri,

    /// Clé SDK `fad_…` ou UUID : l’API fusionne les préfixes OAuth enregistrés sur ce projet (SaaS).
    String? projectId,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/auth/oauth/atlassian/authorization-url',
        queryParameters: {
          if (inviteToken != null && inviteToken.trim().isNotEmpty)
            'inviteToken': inviteToken.trim(),
          if (returnUri != null && returnUri.trim().isNotEmpty)
            'returnUri': returnUri.trim(),
          if (projectId != null && projectId.trim().isNotEmpty)
            'projectId': projectId.trim(),
        },
        options: Options(
          extra: const {kFlutterAdgentsSkipAuthRefreshExtra: true},
        ),
      );
      final data = res.data;
      if (data == null) {
        return const AtlassianOAuthLoginStart(configured: false);
      }
      final url = data['authorizationUrl'];
      final configured = data['configured'] == true;
      return AtlassianOAuthLoginStart(
        authorizationUrl: url is String && url.isNotEmpty ? url : null,
        configured: configured,
      );
    } on DioException catch (e) {
      throw _wrapAuth(e);
    }
  }

  /// Échange le code `oauth_exchange` reçu après redirection (voir doc serveur / page de login web).
  Future<void> signInWithOAuthExchangeCode(String code) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/oauth/atlassian/exchange',
        data: {'code': code.trim()},
        options: Options(
          extra: const {kFlutterAdgentsSkipAuthRefreshExtra: true},
        ),
      );
      final data = res.data;
      if (data == null) {
        throw FlutterAdgentsApiException('Réponse OAuth vide');
      }
      await _applyAuthPayload(data);
    } on DioException catch (e) {
      throw _wrapAuth(e);
    }
  }

  static FlutterAdgentsApiException _wrapAuth(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return FlutterAdgentsApiException(
        data['message'] as String,
        statusCode: e.response?.statusCode,
      );
    }
    return FlutterAdgentsApiException(
      e.message ?? 'Erreur réseau',
      statusCode: e.response?.statusCode,
    );
  }

  void signOut() {
    _token = null;
    _refreshToken = null;
    _jiraAccountId = null;
    _dio.options.headers.remove('Authorization');
    notifyListeners();
    // ignore: discarded_futures
    _tokenStorage.clear();
  }
}
