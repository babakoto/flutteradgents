import 'package:flutteradgents_feedback/flutteradgents_feedback.dart';
import 'package:flutteradgents/src/api/derive_feedback_title.dart';

/// Clés [UserFeedback.extra] (formulaire titre + description).
const String kFlutterAdgentsFeedbackExtraTitle = 'flutteradgents_title';
const String kFlutterAdgentsFeedbackExtraDescription =
    'flutteradgents_description';

/// `accountId` Jira (multipart `jiraAssigneeAccountId` sur `POST …/issues`).
const String kFlutterAdgentsFeedbackExtraAssigneeAccountId =
    'flutteradgents_assignee_account_id';

const int kIssueTitleMaxLength = 255;

/// Titre pour `POST …/issues` : champ dédié ou repli sur le texte unique historique.
String issueTitleForApi(UserFeedback feedback) {
  final extra = feedback.extra;
  final fromExtra =
      extra != null ? extra[kFlutterAdgentsFeedbackExtraTitle] : null;
  if (fromExtra is String) {
    final t = fromExtra.trim();
    if (t.isNotEmpty) {
      return t.length <= kIssueTitleMaxLength
          ? t
          : t.substring(0, kIssueTitleMaxLength);
    }
  }
  return deriveFeedbackIssueTitle(feedback.text.trim());
}

/// Description pour l’API.
String issueDescriptionForApi(UserFeedback feedback) {
  final extra = feedback.extra;
  final fromExtra =
      extra != null ? extra[kFlutterAdgentsFeedbackExtraDescription] : null;
  if (fromExtra is String) {
    final d = fromExtra.trim();
    if (d.isNotEmpty) return d;
  }
  final text = feedback.text.trim();
  if (text.isNotEmpty) return text;
  return '(Aucun texte — voir la capture jointe.)';
}

/// Assigné Jira optionnel pour la création du ticket.
String? issueJiraAssigneeAccountIdForApi(UserFeedback feedback) {
  final extra = feedback.extra;
  final v = extra != null
      ? extra[kFlutterAdgentsFeedbackExtraAssigneeAccountId]
      : null;
  if (v is String) {
    final t = v.trim();
    if (t.isNotEmpty) {
      return t.length <= 128 ? t : t.substring(0, 128);
    }
  }
  return null;
}
