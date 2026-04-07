import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage du couple access / refresh par URL d’API (changement d’URL = autre espace de clés).
class FlutterAdgentsTokenStorage {
  FlutterAdgentsTokenStorage(String apiBaseUrl)
      : _keyPrefix = _namespaceFor(apiBaseUrl);

  final String _keyPrefix;
  static const _accessKey = 'access';
  static const _refreshKey = 'refresh';

  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  static String _namespaceFor(String apiBaseUrl) {
    final n = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return 'fad.${n.hashCode.abs()}';
  }

  Future<void> write({required String access, String? refresh}) async {
    await _storage.write(key: '$_keyPrefix.$_accessKey', value: access);
    if (refresh != null && refresh.isNotEmpty) {
      await _storage.write(key: '$_keyPrefix.$_refreshKey', value: refresh);
    } else {
      await _storage.delete(key: '$_keyPrefix.$_refreshKey');
    }
  }

  Future<({String access, String? refresh})?> read() async {
    final access = await _storage.read(key: '$_keyPrefix.$_accessKey');
    if (access == null || access.isEmpty) {
      return null;
    }
    final String? refresh =
        await _storage.read(key: '$_keyPrefix.$_refreshKey');
    return (access: access, refresh: refresh);
  }

  Future<void> clear() async {
    await _storage.delete(key: '$_keyPrefix.$_accessKey');
    await _storage.delete(key: '$_keyPrefix.$_refreshKey');
  }
}
