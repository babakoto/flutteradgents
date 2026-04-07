import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutteradgents/src/config/flutter_adgents_settings.dart';
import 'package:flutteradgents/src/runtime/flutter_adgents_runtime.dart';

/// Enrichit la description : bloc unique en **anglais** avec **emojis**
/// (environment, platform, device, build number, version, app name).
Future<String> enrichIssueDescriptionWithFullMetadata(
  String userDescription,
  FlutterAdgentsSettings settings,
) async {
  final head = normalizeUserIssueDescription(userDescription);
  final lines = <String>[
    '---',
    '📋 Feedback context',
  ];

  final envDisplay = _environmentDisplay(settings);
  if (envDisplay != null && envDisplay.isNotEmpty) {
    lines.add('🌍 Environment: $envDisplay');
  }

  lines.add('📟 Platform: ${effectiveClientPlatform(settings).apiValue}');

  final device = await _tryDeviceSummary();
  if (device != null) {
    lines.add('📱 Device: ${device.$1} · ${device.$2}');
  }

  try {
    final p = await PackageInfo.fromPlatform();
    lines.add('🔢 Build number: ${p.buildNumber}');
    lines.add('📌 Build version: ${p.version}');
    lines.add('📲 App name: ${p.appName}');
  } catch (e, st) {
    debugPrint('flutteradgents: PackageInfo unavailable: $e\n$st');
  }

  return '${head.trimRight()}\n\n${lines.join('\n')}';
}

/// Combined environment label (flavor + defaultEnvironment when both differ).
String? _environmentDisplay(FlutterAdgentsSettings settings) {
  final flavor = settings.flavor?.trim();
  final extra = settings.defaultEnvironment?.trim();
  if (flavor != null &&
      flavor.isNotEmpty &&
      extra != null &&
      extra.isNotEmpty &&
      flavor.toLowerCase() != extra.toLowerCase()) {
    return '$flavor · $extra';
  }
  return environmentForApi(settings);
}

/// `(device label, OS version string)` for the 📱 line.
Future<(String, String)?> _tryDeviceSummary() async {
  try {
    final info = await DeviceInfoPlugin().deviceInfo;
    return _deviceSummary(info);
  } catch (e, st) {
    debugPrint('flutteradgents: DeviceInfo unavailable: $e\n$st');
    return null;
  }
}

(String, String)? _deviceSummary(BaseDeviceInfo info) {
  switch (info) {
    case AndroidDeviceInfo(:final manufacturer, :final model, :final version):
      final device = [manufacturer, model].where((s) => s.isNotEmpty).join(' ');
      final os = 'Android ${version.release} (SDK ${version.sdkInt})';
      return (device.isEmpty ? 'Android device' : device, os);
    case IosDeviceInfo(
        :final name,
        :final model,
        :final systemName,
        :final systemVersion
      ):
      final device =
          name.isNotEmpty ? name : (model.isNotEmpty ? model : 'iOS device');
      final os = '$systemName $systemVersion';
      return (device, os);
    case WebBrowserInfo(:final browserName, :final platform):
      final device = platform != null && platform.isNotEmpty ? platform : 'Web';
      final os = browserName.name;
      return (device, os);
    case MacOsDeviceInfo(:final modelName, :final model, :final osRelease):
      final device =
          modelName.isNotEmpty ? modelName : (model.isNotEmpty ? model : 'Mac');
      return (device, 'macOS $osRelease');
    case WindowsDeviceInfo(
        :final computerName,
        :final displayVersion,
        :final productName
      ):
      final device = computerName.isNotEmpty ? computerName : 'Windows PC';
      final os = displayVersion.isNotEmpty ? displayVersion : productName;
      return (device, 'Windows $os');
    case LinuxDeviceInfo(:final prettyName, :final name, :final version):
      final device = prettyName.isNotEmpty ? prettyName : name;
      final ver = version != null && version.isNotEmpty ? version : '';
      return (device, ver.isNotEmpty ? 'Linux $ver' : 'Linux');
    default:
      final data = info.data;
      if (data.isEmpty) {
        return null;
      }
      return (
        'Device',
        data.entries.map((e) => '${e.key}=${e.value}').take(6).join(', ')
      );
  }
}
