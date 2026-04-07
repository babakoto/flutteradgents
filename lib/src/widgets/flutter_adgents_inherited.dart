import 'package:dio/dio.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutteradgents/src/api/issue_create_result.dart';
import 'package:flutteradgents/src/api/issues_api.dart';
import 'package:flutteradgents/src/config/flutter_adgents_settings.dart';
import 'package:flutteradgents/src/session/flutter_adgents_session.dart';

class FlutterAdgentsInherited extends InheritedWidget {
  const FlutterAdgentsInherited({
    super.key,
    required this.settings,
    required this.session,
    required this.dio,
    required super.child,
  });

  final FlutterAdgentsSettings settings;
  final FlutterAdgentsSession session;
  final Dio dio;

  static FlutterAdgentsInherited of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<FlutterAdgentsInherited>();
    assert(
        scope != null, 'Placez FlutterAdgentsHosts au-dessus de ce contexte.');
    return scope!;
  }

  /// Sans dépendance d’abonnement (ex. formulaire feedback hors arbre direct).
  static FlutterAdgentsInherited? maybeOf(BuildContext context) {
    return context.findAncestorWidgetOfExactType<FlutterAdgentsInherited>();
  }

  Future<IssueCreateResult> submitUserFeedback(UserFeedback feedback) {
    return IssuesApi(dio, settings).createFromUserFeedback(
      feedback,
      defaultJiraAssigneeAccountId: session.jiraAccountId,
    );
  }

  @override
  bool updateShouldNotify(FlutterAdgentsInherited oldWidget) {
    return settings != oldWidget.settings || dio != oldWidget.dio;
  }
}
