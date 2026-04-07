/// Utilisateur renvoyé par `GET …/jira/assignable-users` (proxy Jira assignable search).
class JiraAssignableUser {
  const JiraAssignableUser({
    required this.accountId,
    required this.displayName,
    required this.active,
    this.emailAddress,
    this.avatarUrl,
  });

  final String accountId;
  final String displayName;
  final bool active;
  final String? emailAddress;

  /// URL de l’avatar Jira (proxy API : `avatarUrls` côté Jira), si présent.
  final String? avatarUrl;

  factory JiraAssignableUser.fromJson(Map<String, dynamic> json) {
    final rawAvatar = json['avatarUrl'];
    final avatar = rawAvatar is String && rawAvatar.trim().isNotEmpty
        ? rawAvatar.trim()
        : null;
    return JiraAssignableUser(
      accountId: json['accountId'] as String,
      displayName:
          json['displayName'] as String? ?? json['accountId'] as String,
      active: json['active'] as bool? ?? true,
      emailAddress: json['emailAddress'] as String?,
      avatarUrl: avatar,
    );
  }
}
