import 'package:flutter/foundation.dart';
import 'package:flutteradgents/src/config/flutter_adgents_defaults.dart';

/// Plateforme client pour les issues (alignée sur l’API Spring `Platform`).
enum FlutterAdgentsClientPlatform {
  web('WEB'),
  android('ANDROID'),
  ios('IOS'),
  desktop('DESKTOP'),
  embedded('EMBEDDED');

  const FlutterAdgentsClientPlatform(this.apiValue);

  final String apiValue;
}

/// Paramètres du SDK : URL de l’API (résolue automatiquement si omise) et projet cible.
///
/// **OAuth Atlassian (mobile)** : le serveur doit recevoir en `returnUri` **exactement** le même
/// deep link que celui déclaré dans l’app (ex. `monapp://oauth`). Utilisez [mobileApp] ou
/// [buildOauthDeepLink] pour éviter les erreurs de copier-coller.
class FlutterAdgentsSettings {
  const FlutterAdgentsSettings({
    required this.apiBaseUrl,
    required this.projectId,
    this.clientPlatform,
    this.defaultEnvironment,
    this.flavor,
    this.oauthLoginReturnUri,
    this.allowOauthWithServerDefaultReturnUri = false,
  });

  /// Point d’entrée **minimal** : communique avec l’API hébergée (ou localhost en debug),
  /// OAuth web = origine courante, OAuth natif = [kFlutterAdgentsDefaultOAuthScheme] (surcharge possible).
  ///
  /// [oauthScheme] : uniquement hors web ; doit correspondre au schéma déclaré dans le projet natif.
  ///
  /// [flavor] : envoyé en `environment` sur les issues (défaut [kFlutterAdgentsSdkDefaultFlavor]).
  factory FlutterAdgentsSettings.simple({
    required String projectId,
    String? oauthScheme,
    String? flavor,
  }) {
    final pid = projectId.trim().replaceAll(RegExp(r'\s+'), '');
    if (pid.isEmpty) {
      throw ArgumentError.value(
        projectId,
        'projectId',
        'projectId ne peut pas être vide.',
      );
    }
    final rawFlavor = flavor?.trim();
    final flavorResolved = (rawFlavor != null && rawFlavor.isNotEmpty)
        ? rawFlavor
        : kFlutterAdgentsSdkDefaultFlavor;
    final api = resolveDefaultApiBaseUrl();
    if (kIsWeb) {
      return FlutterAdgentsSettings(
        apiBaseUrl: api,
        projectId: pid,
        oauthLoginReturnUri: webOAuthReturnUriFromCurrentOrigin(),
        allowOauthWithServerDefaultReturnUri: false,
        flavor: flavorResolved,
      );
    }
    final rawScheme = oauthScheme?.trim();
    final scheme = (rawScheme != null && rawScheme.isNotEmpty)
        ? rawScheme
        : kFlutterAdgentsDefaultOAuthScheme;
    final deep = buildOauthDeepLink(
      scheme: scheme,
      path: kFlutterAdgentsDefaultOAuthPath,
    );
    return FlutterAdgentsSettings(
      apiBaseUrl: api,
      projectId: pid,
      oauthLoginReturnUri: deep,
      allowOauthWithServerDefaultReturnUri: false,
      flavor: flavorResolved,
    );
  }

  /// [apiBaseUrl] est **optionnel** : voir [resolveDefaultApiBaseUrl].
  @Deprecated(
    'Utilisez FlutterAdgentsSettings.simple(projectId: …) pour une intégration standard.',
  )
  factory FlutterAdgentsSettings.auto({
    required String projectId,
    String? apiBaseUrl,
    FlutterAdgentsClientPlatform? clientPlatform,
    String? defaultEnvironment,
    String? flavor,
    String? oauthLoginReturnUri,
    bool allowOauthWithServerDefaultReturnUri = false,
  }) {
    return FlutterAdgentsSettings(
      apiBaseUrl: _resolveApiBaseUrl(apiBaseUrl),
      projectId: projectId,
      clientPlatform: clientPlatform,
      defaultEnvironment: defaultEnvironment,
      flavor: flavor,
      oauthLoginReturnUri: oauthLoginReturnUri,
      allowOauthWithServerDefaultReturnUri:
          allowOauthWithServerDefaultReturnUri,
    );
  }

  /// Configuration **iOS / Android / desktop** : impose un deep link OAuth (custom scheme de **votre** app).
  ///
  /// [apiBaseUrl] est **optionnel** : voir [resolveDefaultApiBaseUrl].
  ///
  /// [oauthDeepLinkReturnUri] est envoyé tel quel à l’API (`returnUri`) puis par le serveur à
  /// Atlassian : après login, le navigateur rouvre l’app sur cette URL (`?oauth_exchange=…`).
  /// Doit correspondre à `AndroidManifest` / `Info.plist` (voir README).
  @Deprecated(
    'Utilisez FlutterAdgentsSettings.simple(projectId:, oauthScheme:) pour une intégration standard.',
  )
  factory FlutterAdgentsSettings.mobileApp({
    required String projectId,
    required String oauthDeepLinkReturnUri,
    String? apiBaseUrl,
    FlutterAdgentsClientPlatform? clientPlatform,
    String? defaultEnvironment,
    String? flavor,
  }) {
    final d = oauthDeepLinkReturnUri.trim();
    if (d.isEmpty) {
      throw ArgumentError.value(
        oauthDeepLinkReturnUri,
        'oauthDeepLinkReturnUri',
        'Le deep link OAuth ne peut pas être vide sur mobile.',
      );
    }
    return FlutterAdgentsSettings(
      apiBaseUrl: _resolveApiBaseUrl(apiBaseUrl),
      projectId: projectId,
      clientPlatform: clientPlatform,
      defaultEnvironment: defaultEnvironment,
      flavor: flavor,
      oauthLoginReturnUri: d,
      allowOauthWithServerDefaultReturnUri: false,
    );
  }

  /// Construit l’URL de retour OAuth **native** : `{scheme}://{path}` (ex. `monapp://oauth`).
  ///
  /// Utilisez le **même** schéma que dans la config native ; [path] est souvent `oauth`.
  static String buildOauthDeepLink({
    required String scheme,
    String path = 'oauth',
  }) {
    final s = scheme.trim();
    final p = path.trim().replaceAll(RegExp(r'^/+'), '');
    if (s.isEmpty) {
      throw ArgumentError.value(
          scheme, 'scheme', 'Le schéma ne peut pas être vide.');
    }
    if (p.isEmpty) {
      throw ArgumentError.value(
          path, 'path', 'Le chemin ne peut pas être vide.');
    }
    return '$s://$p';
  }

  /// Origine de la page **web** courante (sans query), pour `returnUri` OAuth même-onglet.
  ///
  /// À utiliser uniquement si `kIsWeb` ; sinon lève [StateError].
  static String webOAuthReturnUriFromCurrentOrigin() {
    if (!kIsWeb) {
      throw StateError(
        'webOAuthReturnUriFromCurrentOrigin() : réservé au web ; sur mobile utilisez '
        'FlutterAdgentsSettings.simple(projectId: …).',
      );
    }
    final b = Uri.base;
    return Uri(
      scheme: b.scheme,
      host: b.host,
      port: b.hasPort ? b.port : null,
      path: b.path.isEmpty ? '/' : b.path,
    ).toString();
  }

  /// Sans slash final, ex. `http://localhost:8080`
  final String apiBaseUrl;

  /// Identifiant du projet dans les URL API : **UUID** ou **clé SDK** `fad_…` (affichée après
  /// création du projet sur le tableau de bord et sur la fiche projet).
  final String projectId;

  /// Si non null, forcé pour le paramètre API `clientPlatform`. Sinon **détection auto**
  /// ([detectFlutterAdgentsClientPlatform]) au moment de l’envoi.
  final FlutterAdgentsClientPlatform? clientPlatform;

  /// Contexte technique (version, build, etc.) : envoyé en `environment` si [flavor] est vide ;
  /// sinon ajouté en bas de la **description** si différent du flavor.
  final String? defaultEnvironment;

  /// Nom du flavor / variante de build, ex. `String.fromEnvironment('FLUTTERADGENTS_FLAVOR')`.
  /// Sert de **`environment`** API en priorité et apparaît dans la description.
  final String? flavor;

  /// Si non null, transmis en `returnUri` au démarrage OAuth Atlassian : l’utilisateur est
  /// renvoyé sur cette URL après auth (query `oauth_exchange` / `oauth_error`). Sur **web**,
  /// le flux ouvre souvent la page Atlassian dans **le même onglet** pour que le retour recharge
  /// l’app sur cette URL.
  ///
  /// **Sur iOS / Android / desktop**, ce doit être le **custom scheme de l’app hôte**
  /// (ex. `monapp://oauth`), identique à la déclaration native — pas l’URL du dashboard.
  /// Préférez [FlutterAdgentsSettings.mobileApp] pour le forcer.
  ///
  /// **Obligatoire sur iOS / Android / desktop** (sauf si [allowOauthWithServerDefaultReturnUri])
  /// pour éviter que l’API renvoie vers le front par défaut (souvent le tableau de bord web).
  final String? oauthLoginReturnUri;

  /// Si `true`, autorise OAuth Atlassian **sans** [oauthLoginReturnUri] hors web : le serveur
  /// utilise alors son URL de complétion par défaut (souvent onboarding / dashboard). À `false`
  /// en production dans l’app hôte.
  final bool allowOauthWithServerDefaultReturnUri;

  static String? _normalizeApiBaseUrl(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    return t.replaceAll(RegExp(r'/+$'), '');
  }

  static String _resolveApiBaseUrl(String? explicit) {
    final o = _normalizeApiBaseUrl(explicit);
    if (o != null) return o;
    return resolveDefaultApiBaseUrl();
  }

  /// URL de base de l’API sans slash final, déterminée **dans le package** :
  ///
  /// 1. `--dart-define=FLUTTERADGENTS_API_BASE_URL=…` (prioritaire)
  /// 2. `--dart-define=FLUTTERADGENTS_API_URL=…`
  /// 3. `--dart-define=API_BASE_URL=…`
  /// 4. Mode **debug** : `http://10.0.2.2:8080` sur Android (émulateur), sinon
  ///    `http://localhost:8080` (y compris **web** debug pour API locale)
  /// 5. Mode **release / profile** : [kFlutterAdgentsDefaultHostedApiBaseUrl]
  ///    (`flutter_adgents_defaults.dart`)
  /// 6. Secours : `http://localhost:8080`
  static String resolveDefaultApiBaseUrl() {
    return 'https://api.flutteradgents.com';
  }

  FlutterAdgentsSettings copyWith({
    String? apiBaseUrl,
    String? projectId,
    FlutterAdgentsClientPlatform? clientPlatform,
    String? defaultEnvironment,
    String? flavor,
    String? oauthLoginReturnUri,
    bool? allowOauthWithServerDefaultReturnUri,
    bool clearClientPlatform = false,
    bool clearEnvironment = false,
    bool clearFlavor = false,
    bool clearOauthLoginReturnUri = false,
  }) {
    return FlutterAdgentsSettings(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      projectId: projectId ?? this.projectId,
      clientPlatform:
          clearClientPlatform ? null : (clientPlatform ?? this.clientPlatform),
      defaultEnvironment: clearEnvironment
          ? null
          : (defaultEnvironment ?? this.defaultEnvironment),
      flavor: clearFlavor ? null : (flavor ?? this.flavor),
      oauthLoginReturnUri: clearOauthLoginReturnUri
          ? null
          : (oauthLoginReturnUri ?? this.oauthLoginReturnUri),
      allowOauthWithServerDefaultReturnUri:
          allowOauthWithServerDefaultReturnUri ??
              this.allowOauthWithServerDefaultReturnUri,
    );
  }
}
