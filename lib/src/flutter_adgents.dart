import 'package:flutter/material.dart';
import 'package:flutteradgents/src/api/issue_create_result.dart';
import 'package:flutteradgents/src/flutter_adgents_show_feedback.dart';
import 'package:flutteradgents/src/widgets/flutter_adgents_secret_tap_scope.dart';

/// API statique du package : ouverture du flux feedback + envoi d’issue.
class FlutterAdgents {
  FlutterAdgents._();

  /// À passer à [MaterialApp.builder] (ou [WidgetsApp.builder]) pour activer le **secret tap**
  /// (5 appuis par défaut) qui appelle [showFeedback] avec SnackBars par défaut si vous ne
  /// surchargez pas les callbacks.
  ///
  /// Le [Navigator] est **sous** le builder Flutter : [FlutterAdgentsSecretTapScope] résout tout
  /// seul un [BuildContext] valide pour [Navigator.push] (connexion / feedback).
  ///
  /// Composez avec votre propre builder : `(c, w) => votreWidget(c, FlutterAdgents.materialAppBuilder(c, w))`.
  static Widget materialAppBuilder(
    BuildContext context,
    Widget? child, {
    int secretTapCount = 5,
    Duration secretTapResetDuration = const Duration(seconds: 2),
  }) {
    return FlutterAdgentsSecretTapScope(
      requiredTapCount: secretTapCount,
      resetDuration: secretTapResetDuration,
      child: child ?? const SizedBox.shrink(),
    );
  }

  /// Ouvre l’UI de capture / annotation ([BetterFeedback]).
  /// Si aucun JWT n’est présent, ouvre d’abord une **page** de connexion (`/api/v1/auth/login`
  /// ou OAuth Atlassian).
  ///
  /// [inviteToken] : optionnel, transmis au flux OAuth Atlassian si l’utilisateur vient d’une invitation.
  ///
  /// [onIssueCreated] reçoit le corps JSON (statut `SYNCED_TO_JIRA` vs `JIRA_ERROR`, clé Jira, etc.).
  /// Si [onIssueCreated] / [onSubmissionError] sont omis, le package affiche des **SnackBar** par défaut.
  static Future<void> showFeedback(
    BuildContext context, {
    String? inviteToken,
    void Function(Object error)? onSubmissionError,
    void Function()? onSubmissionSuccess,
    void Function(IssueCreateResult result)? onIssueCreated,
  }) {
    return flutterAdgentsShowFeedback(
      context,
      inviteToken: inviteToken,
      onSubmissionError: onSubmissionError,
      onSubmissionSuccess: onSubmissionSuccess,
      onIssueCreated: onIssueCreated,
    );
  }
}
