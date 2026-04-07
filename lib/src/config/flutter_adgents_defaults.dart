// Valeurs figées du SDK : un seul backend « officiel », schéma OAuth par défaut, etc.
// Fork / self-host : modifiez ce fichier ou utilisez `--dart-define=FLUTTERADGENTS_API_BASE_URL=…`.

/// Hôte API **hors debug** quand aucun `dart-define` d’URL n’est fourni.
const String kFlutterAdgentsDefaultHostedApiBaseUrl =
    'https://api.flutteradgents.com';

/// Schéma du deep link OAuth **par défaut** : même valeur dans `AndroidManifest` / `Info.plist`.
/// Si votre app en utilise un autre, passez `oauthScheme` à [FlutterAdgentsSettings.simple].
const String kFlutterAdgentsDefaultOAuthScheme = 'flutteradgents';

/// Chemin du deep link OAuth (souvent `oauth` → `monschema://oauth`).
const String kFlutterAdgentsDefaultOAuthPath = 'oauth';

/// Valeur du champ `environment` côté API pour les issues (mode [FlutterAdgentsSettings.simple]).
const String kFlutterAdgentsSdkDefaultFlavor = 'production';
