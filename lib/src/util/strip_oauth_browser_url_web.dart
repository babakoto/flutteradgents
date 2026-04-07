// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Retire `?oauth_exchange=…` / `?oauth_error=…` de la barre d’adresse (évite un second échange au refresh).
void stripOAuthQueryFromBrowserUrl() {
  final loc = html.window.location;
  final path = loc.pathname ?? '/';
  html.window.history.replaceState(null, '', path);
}
