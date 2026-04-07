import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutteradgents/src/api/flutter_adgents_api_exception.dart';
import 'package:flutteradgents/src/api/issue_create_result.dart';
import 'package:flutteradgents/src/widgets/flutter_adgents_inherited.dart';
import 'package:flutteradgents/src/widgets/sign_in_page.dart';

void _showDefaultIssueCreatedSnackBar(
  BuildContext context,
  IssueCreateResult result,
) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final err = result.status == IssueSyncStatus.jiraError;
  final open = result.status == IssueSyncStatus.open;
  messenger.showSnackBar(
    SnackBar(
      content: Text(result.userFacingSummary),
      backgroundColor: err
          ? Colors.orange.shade900
          : open
              ? Colors.blueGrey.shade800
              : null,
      duration: const Duration(seconds: 6),
    ),
  );
}

void _showDefaultSubmissionErrorSnackBar(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text('Échec : $error'),
      backgroundColor: Colors.red.shade800,
    ),
  );
}

/// Implémentation partagée de [FlutterAdgents.showFeedback] et du secret tap sans [onActivated].
Future<void> flutterAdgentsShowFeedback(
  BuildContext context, {
  String? inviteToken,
  void Function(Object error)? onSubmissionError,
  void Function()? onSubmissionSuccess,
  void Function(IssueCreateResult result)? onIssueCreated,
}) async {
  final inh = FlutterAdgentsInherited.of(context);
  if (!inh.session.isSignedIn) {
    final ok = await pushFlutterAdgentsSignInPage(
      context,
      session: inh.session,
      inviteToken: inviteToken,
    );
    if (!ok || !context.mounted) return;
  }
  if (!context.mounted) return;
  BetterFeedback.of(context).show((UserFeedback feedback) async {
    try {
      final result = await inh.submitUserFeedback(feedback);
      onSubmissionSuccess?.call();
      if (onIssueCreated != null) {
        onIssueCreated(result);
      } else if (context.mounted) {
        _showDefaultIssueCreatedSnackBar(context, result);
      }
    } on FlutterAdgentsApiException catch (e) {
      if (onSubmissionError != null) {
        onSubmissionError(e);
      } else if (context.mounted) {
        _showDefaultSubmissionErrorSnackBar(context, e);
      }
    } catch (e) {
      if (onSubmissionError != null) {
        onSubmissionError(e);
      } else if (context.mounted) {
        _showDefaultSubmissionErrorSnackBar(context, e);
      }
    }
  });
}
