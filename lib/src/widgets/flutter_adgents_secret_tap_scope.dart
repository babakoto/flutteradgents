import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutteradgents/src/flutter_adgents_show_feedback.dart';

NavigatorState? _findNavigatorStateInSubtree(Element root) {
  NavigatorState? found;
  void walk(Element element) {
    if (found != null) return;
    final Object? s = element is StatefulElement ? element.state : null;
    if (s is NavigatorState) {
      found = s;
      return;
    }
    element.visitChildren(walk);
  }

  walk(root);
  return found;
}

/// Contexte adapté pour [Navigator.push] / [FlutterAdgents.showFeedback] : d’abord
/// [Navigator.maybeOf], sinon premier [NavigatorState] dans le sous-arbre de [scope].
///
/// Nécessaire quand ce widget est **au-dessus** du [Navigator] (ex. retour de
/// [MaterialApp.builder]) : le [BuildContext] du scope n’a alors pas le [Navigator] en ancêtre.
BuildContext? flutterAdgentsNavigatorContextForOverlay(BuildContext scope) {
  final fromAncestor = Navigator.maybeOf(scope);
  if (fromAncestor != null && fromAncestor.mounted) {
    return fromAncestor.context;
  }
  final Element? el = scope as Element?;
  if (el == null) return null;
  final found = _findNavigatorStateInSubtree(el);
  if (found != null && found.mounted) {
    return found.context;
  }
  return null;
}

/// Déclenche l’action après [requiredTapCount] appuis dans la fenêtre [resetDuration].
///
/// Si [onActivated] est `null`, le package ouvre le flux feedback (`FlutterAdgents.showFeedback`,
/// SnackBars par défaut). Il faut un ancêtre [FlutterAdgentsInherited] ; le [Navigator] peut être
/// soit un ancêtre du scope, soit un descendant (cas [MaterialApp.builder]).
///
/// Utilise un [Listener] en `translucent` : les gestes continuent de fonctionner sur les enfants
/// (boutons, listes, etc.).
class FlutterAdgentsSecretTapScope extends StatefulWidget {
  const FlutterAdgentsSecretTapScope({
    super.key,
    required this.child,
    this.onActivated,
    this.requiredTapCount = 5,
    this.resetDuration = const Duration(seconds: 2),
  });

  final Widget child;

  /// Si `null`, ouverture du feedback FlutterAdgents par défaut (SnackBars intégrées).
  final VoidCallback? onActivated;

  /// Nombre de touchers nécessaires (défaut : 5).
  final int requiredTapCount;

  /// Sans nouveau toucher pendant ce délai, le compteur repart à zéro.
  final Duration resetDuration;

  @override
  State<FlutterAdgentsSecretTapScope> createState() =>
      _FlutterAdgentsSecretTapScopeState();
}

class _FlutterAdgentsSecretTapScopeState
    extends State<FlutterAdgentsSecretTapScope> {
  int _count = 0;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  void _activate() {
    if (!mounted) return;
    final custom = widget.onActivated;
    if (custom != null) {
      custom();
      return;
    }
    final navCtx = flutterAdgentsNavigatorContextForOverlay(context);
    if (navCtx != null) {
      unawaited(flutterAdgentsShowFeedback(navCtx));
      return;
    }
    assert(() {
      debugPrint(
        'FlutterAdgentsSecretTapScope: aucun Navigator trouvé sous ce widget ; '
        'vérifiez MaterialApp (home / routes) ou fournissez onActivated.',
      );
      return true;
    }());
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.requiredTapCount <= 0) return;
    _reset?.cancel();
    _count++;
    if (_count >= widget.requiredTapCount) {
      _reset?.cancel();
      _count = 0;
      _activate();
      return;
    }
    _reset = Timer(widget.resetDuration, () => _count = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: widget.child,
    );
  }
}
