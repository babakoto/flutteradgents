import 'package:dio/dio.dart';
import 'package:flutteradgents/src/session/flutter_adgents_session.dart';

/// Évite les boucles sur [refreshAccessToken] et les routes publiques.
const String kFlutterAdgentsSkipAuthRefreshExtra = 'fad_skip_auth_refresh';

/// Rafraîchit le JWT via `POST /api/v1/auth/refresh` sur 401/403 puis relance la requête.
final class FlutterAdgentsAuthInterceptor extends QueuedInterceptor {
  FlutterAdgentsAuthInterceptor(this._session, this._dio);

  final FlutterAdgentsSession _session;
  final Dio _dio;

  static bool _isAuthRefreshPath(String path) {
    return path.contains('/api/v1/auth/refresh') ||
        path.contains('/api/v1/auth/login') ||
        path.contains('/api/v1/auth/register') ||
        path.contains('/api/v1/auth/oauth/atlassian/exchange');
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.requestOptions.extra[kFlutterAdgentsSkipAuthRefreshExtra] == true) {
      handler.next(err);
      return;
    }
    final code = err.response?.statusCode;
    if (code != 401 && code != 403) {
      handler.next(err);
      return;
    }
    final path = err.requestOptions.path;
    if (_isAuthRefreshPath(path)) {
      handler.next(err);
      return;
    }
    final rt = _session.refreshToken;
    if (rt == null || rt.isEmpty) {
      handler.next(err);
      return;
    }
    try {
      await _session.refreshAccessToken();
      final token = _session.token;
      if (token == null || token.isEmpty) {
        handler.next(err);
        return;
      }
      final ro = err.requestOptions;
      ro.headers['Authorization'] = 'Bearer $token';
      final clone = await _dio.fetch(ro);
      handler.resolve(clone);
    } catch (_) {
      _session.signOut();
      handler.next(err);
    }
  }
}
