import 'package:flutter_test/flutter_test.dart';
import 'package:flutteradgents/src/api/derive_feedback_title.dart';

void main() {
  test('deriveFeedbackIssueTitle short text', () {
    expect(deriveFeedbackIssueTitle('Bug login'), 'Bug login');
  });

  test('deriveFeedbackIssueTitle long first line truncates', () {
    final line = 'x' * 300;
    expect(deriveFeedbackIssueTitle(line).length, 255);
  });
}
