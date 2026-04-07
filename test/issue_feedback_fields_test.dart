import 'dart:typed_data';

import 'package:feedback/feedback.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutteradgents/src/api/issue_feedback_fields.dart';

void main() {
  final emptyPng = Uint8List.fromList([0]);

  test('title and description from extras', () {
    final f = UserFeedback(
      text: 'ignored when extras set',
      screenshot: emptyPng,
      extra: {
        kFlutterAdgentsFeedbackExtraTitle: '  Bug login  ',
        kFlutterAdgentsFeedbackExtraDescription: '  Steps…  ',
      },
    );
    expect(issueTitleForApi(f), 'Bug login');
    expect(issueDescriptionForApi(f), 'Steps…');
  });

  test('title truncated to 255', () {
    final long = 'x' * 300;
    final f = UserFeedback(
      text: '',
      screenshot: emptyPng,
      extra: {kFlutterAdgentsFeedbackExtraTitle: long, kFlutterAdgentsFeedbackExtraDescription: 'd'},
    );
    expect(issueTitleForApi(f).length, 255);
  });

  test('fallback without extras uses text', () {
    final f = UserFeedback(text: 'Only line', screenshot: emptyPng);
    expect(issueTitleForApi(f), 'Only line');
    expect(issueDescriptionForApi(f), 'Only line');
  });

  test('jira assignee account id from extras', () {
    final f = UserFeedback(
      text: 'x',
      screenshot: emptyPng,
      extra: {kFlutterAdgentsFeedbackExtraAssigneeAccountId: '  acc-123  '},
    );
    expect(issueJiraAssigneeAccountIdForApi(f), 'acc-123');
  });

  test('jira assignee absent when not in extras', () {
    final f = UserFeedback(text: 'x', screenshot: emptyPng);
    expect(issueJiraAssigneeAccountIdForApi(f), isNull);
  });
}
