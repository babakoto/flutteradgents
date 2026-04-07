import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutteradgents/src/api/flutter_adgents_api_exception.dart';
import 'package:flutteradgents/src/util/strip_oauth_browser_url.dart';
import 'package:flutteradgents/src/widgets/flutter_adgents_inherited.dart';

/// Résultat du traitement d’une URL de retour OAuth (`oauth_exchange` ou `oauth_error`).
@immutable
class FlutterAdgentsOAuthReturnOutcome {
  const FlutterAdgentsOAuthReturnOutcome._({
    required this.signedIn,
    this.message,
  });

  const FlutterAdgentsOAuthReturnOutcome.signedIn()
      : this._(signedIn: true, message: null);

  const FlutterAdgentsOAuthReturnOutcome.error(String message)
      : this._(signedIn: false, message: message);

  final bool signedIn;

  /// Message utilisateur si [signedIn] est `false`.
  final String? message;
}

typedef FlutterAdgentsOnOAuthReturn = void Function(
  BuildContext context,
  FlutterAdgentsOAuthReturnOutcome outcome,
);

void _showDefaultOAuthSnackBars(
  ScaffoldMessengerState? messenger,
  FlutterAdgentsOAuthReturnOutcome outcome,
) {
  if (messenger == null) return;
  if (outcome.signedIn) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Connecté avec Atlassian.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  final msg = outcome.message;
  if (msg != null && msg.isNotEmpty) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Écoute les deep links natifs ([AppLinks]) et, sur le web, l’URL initiale (`Uri.base`)
/// pour finaliser OAuth via [FlutterAdgentsSession.signInWithOAuthExchangeCode].
///
/// Doit être placé **sous** [FlutterAdgentsInherited] (ex. enfant de [FlutterAdgentsHosts]).
///
/// Si [onOutcome] est `null`, des **SnackBar** par défaut sont affichés via un
/// [ScaffoldMessenger] enveloppant [child]. Sinon seul votre callback est invoqué.
class FlutterAdgentsOAuthReturnListener extends StatefulWidget {
  const FlutterAdgentsOAuthReturnListener({
    super.key,
    required this.child,
    this.onOutcome,
  });

  final Widget child;
  final FlutterAdgentsOnOAuthReturn? onOutcome;

  @override
  State<FlutterAdgentsOAuthReturnListener> createState() =>
      _FlutterAdgentsOAuthReturnListenerState();
}

class _FlutterAdgentsOAuthReturnListenerState
    extends State<FlutterAdgentsOAuthReturnListener> {
  final AppLinks _appLinks = AppLinks();
  final GlobalKey<ScaffoldMessengerState> _snackMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Uri>? _oauthLinkSub;
  String? _lastConsumedExchangeCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _consumeOAuthFromUri(
        Uri.base,
        stripWebLocationAfter: kIsWeb,
      );
      if (!kIsWeb) {
        await _listenOAuthDeepLinks();
      }
    });
  }

  Future<void> _listenOAuthDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null && mounted) {
        await _consumeOAuthFromUri(
          initial,
          stripWebLocationAfter: false,
        );
      }
    } catch (_) {}
    _oauthLinkSub = _appLinks.uriLinkStream.listen((uri) {
      unawaited(
        _consumeOAuthFromUri(uri, stripWebLocationAfter: false),
      );
    });
  }

  Future<void> _consumeOAuthFromUri(
    Uri uri, {
    required bool stripWebLocationAfter,
  }) async {
    if (!mounted) return;
    final qp = uri.queryParameters;
    final code = qp['oauth_exchange'];
    final err = qp['oauth_error'];
    if ((code == null || code.isEmpty) && (err == null || err.isEmpty)) {
      return;
    }
    if (code != null && code.isNotEmpty && code == _lastConsumedExchangeCode) {
      return;
    }
    final session = FlutterAdgentsInherited.of(context).session;
    final custom = widget.onOutcome;
    try {
      if (code != null && code.isNotEmpty) {
        await session.signInWithOAuthExchangeCode(code);
        if (!mounted) return;
        _lastConsumedExchangeCode = code;
        const outcome = FlutterAdgentsOAuthReturnOutcome.signedIn();
        if (custom != null) {
          custom(context, outcome);
        } else {
          _showDefaultOAuthSnackBars(
            _snackMessengerKey.currentState,
            outcome,
          );
        }
      } else if (err != null && err.isNotEmpty) {
        if (!mounted) return;
        final outcome = FlutterAdgentsOAuthReturnOutcome.error('OAuth : $err');
        if (custom != null) {
          custom(context, outcome);
        } else {
          _showDefaultOAuthSnackBars(
            _snackMessengerKey.currentState,
            outcome,
          );
        }
      }
    } on FlutterAdgentsApiException catch (e) {
      if (!mounted) return;
      final outcome = FlutterAdgentsOAuthReturnOutcome.error(e.message);
      if (custom != null) {
        custom(context, outcome);
      } else {
        _showDefaultOAuthSnackBars(
          _snackMessengerKey.currentState,
          outcome,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final outcome = FlutterAdgentsOAuthReturnOutcome.error('$e');
      if (custom != null) {
        custom(context, outcome);
      } else {
        _showDefaultOAuthSnackBars(
          _snackMessengerKey.currentState,
          outcome,
        );
      }
    }
    if (stripWebLocationAfter && kIsWeb) {
      stripOAuthQueryFromBrowserUrl();
    }
  }

  @override
  void dispose() {
    _oauthLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onOutcome != null) {
      return widget.child;
    }
    return ScaffoldMessenger(
      key: _snackMessengerKey,
      child: widget.child,
    );
  }
}
