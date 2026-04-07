import 'package:dio/dio.dart';
import 'package:feedback/feedback.dart';
import 'package:flutteradgents/src/api/flutter_adgents_api_exception.dart';
import 'package:flutteradgents/src/api/issue_create_result.dart';
import 'package:flutteradgents/src/api/issue_feedback_fields.dart';
import 'package:flutteradgents/src/config/flutter_adgents_settings.dart';
import 'package:flutteradgents/src/runtime/flutter_adgents_runtime.dart';
import 'package:flutteradgents/src/runtime/issue_description_metadata.dart';
import 'package:http_parser/http_parser.dart';

/// Appels `POST /api/v1/projects/{projectId}/issues` (multipart).
class IssuesApi {
  IssuesApi(this._dio, this._settings);

  final Dio _dio;
  final FlutterAdgentsSettings _settings;

  /// Envoie titre, description et capture PNG (champs `title` / `description` de l’API).
  /// Retourne le corps JSON : vérifiez [IssueCreateResult.status] (l’API peut répondre 200 avec `JIRA_ERROR`).
  Future<IssueCreateResult> createFromUserFeedback(
    UserFeedback feedback, {
    String? defaultJiraAssigneeAccountId,
  }) async {
    final title = issueTitleForApi(feedback);
    final rawDescription = issueDescriptionForApi(feedback);
    final description =
        await enrichIssueDescriptionWithFullMetadata(rawDescription, _settings);

    final map = <String, dynamic>{
      'title': title,
      'description': description,
    };
    final env = environmentForApi(_settings);
    if (env != null && env.isNotEmpty) {
      map['environment'] = env;
    }
    map['clientPlatform'] = effectiveClientPlatform(_settings).apiValue;
    var assigneeId = issueJiraAssigneeAccountIdForApi(feedback);
    assigneeId ??= defaultJiraAssigneeAccountId;
    if (assigneeId != null && assigneeId.trim().isNotEmpty) {
      map['jiraAssigneeAccountId'] = assigneeId.trim();
    }

    final form = FormData.fromMap(map);
    if (feedback.screenshot.isNotEmpty) {
      form.files.add(
        MapEntry(
          'files',
          MultipartFile.fromBytes(
            feedback.screenshot,
            filename: 'flutteradgents_feedback.png',
            contentType: MediaType('image', 'png'),
          ),
        ),
      );
    }

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/projects/${_settings.projectId}/issues',
        data: form,
      );
      final data = res.data;
      if (data == null) {
        throw FlutterAdgentsApiException('Réponse issue vide');
      }
      return IssueCreateResult.fromJson(data);
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
