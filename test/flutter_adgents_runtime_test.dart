import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutteradgents/src/config/flutter_adgents_settings.dart';
import 'package:flutteradgents/src/runtime/flutter_adgents_runtime.dart';

void main() {
  test('detect platform web', () {
    expect(
      detectFlutterAdgentsClientPlatform(forTestsIsWeb: true),
      FlutterAdgentsClientPlatform.web,
    );
  });

  test('detect platform android', () {
    expect(
      detectFlutterAdgentsClientPlatform(
        forTestsIsWeb: false,
        forTestsTarget: TargetPlatform.android,
      ),
      FlutterAdgentsClientPlatform.android,
    );
  });

  test('environmentForApi prefers flavor', () {
    expect(
      environmentForApi(
        const FlutterAdgentsSettings(
          apiBaseUrl: 'http://x',
          projectId: 'p',
          flavor: 'staging',
          defaultEnvironment: 'extra',
        ),
      ),
      'staging',
    );
  });

  test('environmentForApi falls back to defaultEnvironment', () {
    expect(
      environmentForApi(
        const FlutterAdgentsSettings(
          apiBaseUrl: 'http://x',
          projectId: 'p',
          defaultEnvironment: 'prod',
        ),
      ),
      'prod',
    );
  });

  test('normalizeUserIssueDescription keeps text', () {
    expect(normalizeUserIssueDescription('  Bug  '), 'Bug');
  });

  test('normalizeUserIssueDescription empty placeholder English', () {
    expect(normalizeUserIssueDescription('   '), contains('No text'));
  });
}
