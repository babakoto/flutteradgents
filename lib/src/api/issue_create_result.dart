/// Statut renvoyé par `POST …/issues` (aligné sur [IssueStatus] côté API).
enum IssueSyncStatus {
  open,
  syncedToJira,
  jiraError,
  unknown;

  static IssueSyncStatus fromApi(String? raw) {
    switch (raw) {
      case 'OPEN':
        return IssueSyncStatus.open;
      case 'SYNCED_TO_JIRA':
        return IssueSyncStatus.syncedToJira;
      case 'JIRA_ERROR':
        return IssueSyncStatus.jiraError;
      default:
        return IssueSyncStatus.unknown;
    }
  }
}

/// Réponse JSON de création d’issue (permet de savoir si Jira a bien reçu le ticket).
class IssueCreateResult {
  const IssueCreateResult({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
    this.jiraIssueKey,
    this.jiraIssueUrl,
    this.jiraAssigneeAccountId,
    this.errorMessage,
  });

  final String id;
  final String projectId;
  final String title;
  final IssueSyncStatus status;
  final String? jiraIssueKey;
  final String? jiraIssueUrl;
  final String? jiraAssigneeAccountId;
  final String? errorMessage;

  bool get isSyncedToJira => status == IssueSyncStatus.syncedToJira;

  factory IssueCreateResult.fromJson(Map<String, dynamic> j) {
    return IssueCreateResult(
      id: j['id'] as String,
      projectId: j['projectId'] as String,
      title: j['title'] as String? ?? '',
      status: IssueSyncStatus.fromApi(j['status'] as String?),
      jiraIssueKey: j['jiraIssueKey'] as String?,
      jiraIssueUrl: j['jiraIssueUrl'] as String?,
      jiraAssigneeAccountId: j['jiraAssigneeAccountId'] as String?,
      errorMessage: j['errorMessage'] as String?,
    );
  }

  /// Message court pour SnackBar / logs.
  String get userFacingSummary {
    switch (status) {
      case IssueSyncStatus.syncedToJira:
        final k = jiraIssueKey;
        return k != null ? 'Ticket Jira créé : $k' : 'Synchronisé avec Jira.';
      case IssueSyncStatus.jiraError:
        final m = errorMessage;
        return m != null && m.isNotEmpty
            ? 'Jira : échec — $m'
            : 'Jira : échec (voir les logs serveur ou la réponse API).';
      case IssueSyncStatus.open:
        return 'Issue enregistrée (aucune config Jira sur ce projet, ou outil non utilisé).';
      case IssueSyncStatus.unknown:
        return 'Issue enregistrée (statut inconnu).';
    }
  }
}
