import 'package:flutter/foundation.dart';
import 'package:flutteradgents/src/config/flutter_adgents_settings.dart';

/// Détecte la plateforme d’exécution (alignée sur l’enum API `Platform`).
///
/// [forTests] permet de forcer une valeur dans les tests unitaires.
FlutterAdgentsClientPlatform detectFlutterAdgentsClientPlatform({
  bool? forTestsIsWeb,
  TargetPlatform? forTestsTarget,
}) {
  if (forTestsIsWeb ?? kIsWeb) {
    return FlutterAdgentsClientPlatform.web;
  }
  final t = forTestsTarget ?? defaultTargetPlatform;
  switch (t) {
    case TargetPlatform.android:
      return FlutterAdgentsClientPlatform.android;
    case TargetPlatform.iOS:
      return FlutterAdgentsClientPlatform.ios;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return FlutterAdgentsClientPlatform.desktop;
    case TargetPlatform.fuchsia:
      return FlutterAdgentsClientPlatform.embedded;
  }
}

/// Plateforme effective : réglage explicite ou détection auto.
FlutterAdgentsClientPlatform effectiveClientPlatform(
    FlutterAdgentsSettings settings) {
  return settings.clientPlatform ?? detectFlutterAdgentsClientPlatform();
}

/// User-entered text only ; English placeholder if empty.
String normalizeUserIssueDescription(String userDescription) {
  final base = userDescription.trim();
  if (base.isEmpty) {
    return '(No text — see attached screenshot.)';
  }
  return base;
}

/// Champ `environment` multipart : priorité au **flavor**, sinon [FlutterAdgentsSettings.defaultEnvironment].
String? environmentForApi(FlutterAdgentsSettings settings) {
  final flavor = settings.flavor?.trim();
  if (flavor != null && flavor.isNotEmpty) {
    return flavor;
  }
  final env = settings.defaultEnvironment?.trim();
  if (env != null && env.isNotEmpty) {
    return env;
  }
  return null;
}

/// @nodoc Conservé pour compat ; préférez [normalizeUserIssueDescription] + [enrichIssueDescriptionWithFullMetadata].
@Deprecated(
    'Use normalizeUserIssueDescription + enrichIssueDescriptionWithFullMetadata')
String enrichIssueDescriptionWithRuntimeMetadata(
  String userDescription,
  FlutterAdgentsSettings settings,
) {
  return normalizeUserIssueDescription(userDescription);
}
