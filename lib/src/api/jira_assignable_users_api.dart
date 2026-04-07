import 'package:dio/dio.dart';
import 'package:flutteradgents/src/api/flutter_adgents_api_exception.dart';
import 'package:flutteradgents/src/api/jira_assignable_user.dart';
import 'package:flutteradgents/src/config/flutter_adgents_settings.dart';

/// `GET /api/v1/projects/{projectId}/jira/assignable-users`
class JiraAssignableUsersApi {
  JiraAssignableUsersApi(this._dio, this._settings);

  final Dio _dio;
  final FlutterAdgentsSettings _settings;

  /// [query] : filtre texte côté Jira (optionnel). [maxResults] : 1–100 (défaut 50).
  Future<List<JiraAssignableUser>> listAssignableUsers({
    String? query,
    int maxResults = 50,
  }) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/v1/projects/${_settings.projectId}/jira/assignable-users',
        queryParameters: <String, dynamic>{
          if (query != null && query.isNotEmpty) 'query': query,
          'maxResults': maxResults,
        },
      );
      final data = res.data;
      if (data == null) {
        return const [];
      }
      return data
          .map(
            (e) => JiraAssignableUser.fromJson(
                Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } on DioException catch (e) {
      throw _wrap(e);
    }
  }

  static FlutterAdgentsApiException _wrap(DioException e) {
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
}
