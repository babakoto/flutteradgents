import 'package:flutter_test/flutter_test.dart';
import 'package:flutteradgents/src/api/issue_create_result.dart';

void main() {
  test('fromJson synced', () {
    final r = IssueCreateResult.fromJson({
      'id': 'a',
      'projectId': 'b',
      'title': 'T',
      'status': 'SYNCED_TO_JIRA',
      'jiraIssueKey': 'PROJ-1',
      'jiraIssueUrl': 'https://x/browse/PROJ-1',
      'errorMessage': null,
    });
    expect(r.isSyncedToJira, true);
    expect(r.userFacingSummary, contains('PROJ-1'));
  });

  test('fromJson jira error shows message', () {
    final r = IssueCreateResult.fromJson({
      'id': 'a',
      'projectId': 'b',
      'title': 'T',
      'status': 'JIRA_ERROR',
      'jiraIssueKey': null,
      'errorMessage': '401 Unauthorized',
    });
    expect(r.userFacingSummary, contains('401'));
  });
}
