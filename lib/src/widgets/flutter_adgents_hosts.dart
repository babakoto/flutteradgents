import 'dart:async';

import 'package:dio/dio.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutteradgents/src/config/flutter_adgents_settings.dart';
import 'package:flutteradgents/src/session/flutter_adgents_auth_interceptor.dart';
import 'package:flutteradgents/src/session/flutter_adgents_session.dart';
import 'package:flutteradgents/src/session/flutter_adgents_token_storage.dart';
import 'package:flutteradgents/src/widgets/flutter_adgents_inherited.dart';
import 'package:flutteradgents/src/widgets/flutter_adgents_issue_feedback_builder.dart';
import 'package:flutteradgents/src/widgets/flutter_adgents_oauth_return_listener.dart';

/// Enveloppe l’app avec [BetterFeedback] (package [feedback](https://pub.dev/packages/feedback))
/// et fournit [FlutterAdgentsInherited] (réglages + session + client HTTP).
///
/// Placez typiquement [MaterialApp] dans [child], au même niveau que dans la doc `feedback`.
///
/// **Hauteur de la feuille** ([FeedbackThemeData.feedbackSheetHeight]) : plus elle est **élevée**,
/// plus la **capture** à annoter devient **petite** (le package `feedback` réserve cette fraction
/// d’écran au panneau). Ignoré si [useFullScreenFeedbackForm] est `true` (pas de bottom sheet).
///
/// Pour une intégration **sans** [FlutterAdgentsSettings] explicite, utilisez [FlutterAdgentsHosts.forProject].
class FlutterAdgentsHosts extends StatefulWidget {
  /// Même comportement que le constructeur principal avec [FlutterAdgentsSettings.simple].
  factory FlutterAdgentsHosts.forProject({
    Key? key,
    required String projectId,
    String? oauthScheme,
    String? flavor,
    required Widget child,
    ThemeMode? feedbackThemeMode,
    FeedbackThemeData? feedbackTheme,
    FeedbackThemeData? feedbackDarkTheme,
    FeedbackMode feedbackMode = FeedbackMode.draw,
    double feedbackPixelRatio = 3,
    FeedbackBuilder? feedbackBuilder,
    bool useFullScreenFeedbackForm = true,
    bool handleOAuthReturnUris = true,
    FlutterAdgentsOnOAuthReturn? onOAuthReturn,
  }) {
    return FlutterAdgentsHosts(
      key: key,
      settings: FlutterAdgentsSettings.simple(
        projectId: projectId,
        oauthScheme: oauthScheme,
        flavor: flavor,
      ),
      feedbackThemeMode: feedbackThemeMode,
      feedbackTheme: feedbackTheme,
      feedbackDarkTheme: feedbackDarkTheme,
      feedbackMode: feedbackMode,
      feedbackPixelRatio: feedbackPixelRatio,
      feedbackBuilder: feedbackBuilder,
      useFullScreenFeedbackForm: useFullScreenFeedbackForm,
      handleOAuthReturnUris: handleOAuthReturnUris,
      onOAuthReturn: onOAuthReturn,
      child: child,
    );
  }

  const FlutterAdgentsHosts({
    super.key,
    required this.settings,
    required this.child,
    this.feedbackThemeMode,
    this.feedbackTheme,
    this.feedbackDarkTheme,
    this.feedbackMode = FeedbackMode.draw,
    this.feedbackPixelRatio = 3,
    this.feedbackBuilder,
    this.useFullScreenFeedbackForm = true,
    this.handleOAuthReturnUris = true,
    this.onOAuthReturn,
  });

  final FlutterAdgentsSettings settings;
  final Widget child;
  final ThemeMode? feedbackThemeMode;
  final FeedbackThemeData? feedbackTheme;
  final FeedbackThemeData? feedbackDarkTheme;
  final FeedbackMode feedbackMode;
  final double feedbackPixelRatio;

  /// Si `true` (défaut), pas de bottom sheet pendant l’annotation : le formulaire s’ouvre en
  /// **plein écran** via le bouton **+** de la barre d’outils (fork `packages/feedback`).
  final bool useFullScreenFeedbackForm;

  /// Si null, formulaire **titre + description** aligné sur `POST …/issues`.
  final FeedbackBuilder? feedbackBuilder;

  /// Si `true` (défaut), consomme `oauth_exchange` / `oauth_error` depuis l’URL web initiale
  /// et les deep links natifs ([app_links](https://pub.dev/packages/app_links)) pour finaliser OAuth.
  final bool handleOAuthReturnUris;

  /// Si non null, remplace le **retour visuel par défaut** (SnackBar intégrées au package).
  /// Sinon : message « Connecté avec Atlassian. » ou texte d’erreur après OAuth.
  final FlutterAdgentsOnOAuthReturn? onOAuthReturn;

  @override
  State<FlutterAdgentsHosts> createState() => _FlutterAdgentsHostsState();
}

class _FlutterAdgentsHostsState extends State<FlutterAdgentsHosts> {
  late Dio _dio;
  late FlutterAdgentsSession _session;

  void _initHttpStack() {
    _dio = Dio(
      BaseOptions(
        baseUrl: widget.settings.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 90),
        headers: {'Accept': 'application/json'},
      ),
    );
    final storage = FlutterAdgentsTokenStorage(widget.settings.apiBaseUrl);
    _session = FlutterAdgentsSession(_dio, storage);
    _session.addListener(_onSession);
    _dio.interceptors.add(FlutterAdgentsAuthInterceptor(_session, _dio));
    unawaited(_session.restorePersistedCredentials());
  }

  @override
  void initState() {
    super.initState();
    _initHttpStack();
  }

  void _onSession() => setState(() {});

  @override
  void didUpdateWidget(FlutterAdgentsHosts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.apiBaseUrl != widget.settings.apiBaseUrl ||
        oldWidget.settings.projectId != widget.settings.projectId) {
      _session.removeListener(_onSession);
      _dio.close(force: true);
      _initHttpStack();
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _dio.close(force: true);
    super.dispose();
  }

  FeedbackThemeData? _effectiveFeedbackTheme(FeedbackThemeData? original) {
    if (original == null) return null;
    if (!widget.useFullScreenFeedbackForm) return original;
    return original.copyWith(useFullScreenFeedbackForm: true);
  }

  /// Bouton déconnexion à côté du « + » formulaire, avant Annuler / couleurs.
  FeedbackThemeData _withFeedbackLogoutButton(FeedbackThemeData base) {
    final prior = base.controlsColumnExtraActions;
    final accent = base.activeFeedbackModeColor;
    return base.copyWith(
      controlsColumnExtraActions: (BuildContext ctx) {
        final list = <Widget>[...?prior?.call(ctx)];
        final inh = FlutterAdgentsInherited.maybeOf(ctx);
        if (inh != null && inh.session.isSignedIn) {
          list.add(
            IconButton(
              key: const ValueKey<String>('flutter_adgents_feedback_logout'),
              tooltip: 'Déconnexion',
              icon: Icon(
                Icons.logout_rounded,
                color: accent,
              ),
              onPressed: () {
                inh.session.signOut();
                try {
                  BetterFeedback.of(ctx).hide();
                } catch (_) {}
                ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                  const SnackBar(
                    content: Text('Déconnexion effectuée'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          );
        }
        return list;
      },
    );
  }

  FeedbackThemeData? _themeWithSdkExtras(FeedbackThemeData? base) {
    if (base == null) {
      return null;
    }
    return _withFeedbackLogoutButton(base);
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.useFullScreenFeedbackForm;
    final theme = _themeWithSdkExtras(
      _effectiveFeedbackTheme(widget.feedbackTheme) ??
          (full
              ? FeedbackThemeData.light()
                  .copyWith(useFullScreenFeedbackForm: true)
              : null),
    );
    final darkTheme = _themeWithSdkExtras(
      _effectiveFeedbackTheme(widget.feedbackDarkTheme) ??
          (full
              ? FeedbackThemeData.dark()
                  .copyWith(useFullScreenFeedbackForm: true)
              : null),
    );

    var feedbackChild = widget.child;
    if (widget.handleOAuthReturnUris) {
      feedbackChild = FlutterAdgentsOAuthReturnListener(
        onOutcome: widget.onOAuthReturn,
        child: feedbackChild,
      );
    }

    return FlutterAdgentsInherited(
      settings: widget.settings,
      session: _session,
      dio: _dio,
      child: BetterFeedback(
        themeMode: widget.feedbackThemeMode,
        theme: theme,
        darkTheme: darkTheme,
        mode: widget.feedbackMode,
        pixelRatio: widget.feedbackPixelRatio,
        localizationsDelegates: [
          GlobalFeedbackLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        feedbackBuilder:
            widget.feedbackBuilder ?? flutterAdgentsIssueFeedbackBuilder,
        child: feedbackChild,
      ),
    );
  }
}
