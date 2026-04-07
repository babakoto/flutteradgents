import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutteradgents/src/api/flutter_adgents_api_exception.dart';
import 'package:flutteradgents/src/session/flutter_adgents_session.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:url_launcher/url_launcher.dart';

/// Résultat du flux OAuth Atlassian (connexion JWT).
enum AtlassianOAuthSignInOutcome {
  /// L’utilisateur a fermé le dialogue ou le lancement du navigateur a échoué.
  cancelled,

  /// JWT obtenu après saisie du code d’échange (mobile / onglet séparé web).
  signedIn,

  /// Web : même onglet (`oauth_exchange` / `oauth_error` dans l’URL de la page).
  ///
  /// **iOS / Android / desktop** : secours navigateur externe + deep link ; par défaut
  /// [FlutterAdgentsHosts] enregistre `app_links` pour consommer l’URL. Préférez le flux intégré
  /// qui renvoie [signedIn] sans cette étape.
  redirectStarted,
}

/// `true` si [returnUri] utilise un schéma autre que `http` / `https` (ex. `myapp://oauth`).
///
/// C’est le mode recommandé sur mobile pour que l’API ne renvoie **pas** vers une page web
/// (onboarding / dashboard) mais rouvre l’application native.
bool isNativeOauthDeepLinkReturnUri(String? returnUri) {
  final u = returnUri?.trim();
  if (u == null || u.isEmpty) return false;
  try {
    final parsed = Uri.parse(u);
    final s = parsed.scheme.toLowerCase();
    return s.isNotEmpty && s != 'http' && s != 'https';
  } catch (_) {
    return false;
  }
}

/// Démarre OAuth Atlassian (navigateur), puis JWT via `oauth_exchange` ou dialogue.
///
/// Ce n’est **pas** obligatoire pour l’API : le couple e-mail / mot de passe suffit. OAuth est une alternative.
///
/// [oauthLoginReturnUri] : transmis à l’API en `returnUri` ; sur **web** non vide, la page Atlassian
/// s’ouvre dans le **même onglet** (`_self`) pour que la redirection post-login recharge votre app.
///
/// Hors web, sans [oauthLoginReturnUri] et sans [allowServerDefaultReturnUri], le flux **ne démarre
/// pas** : sinon l’API renvoie souvent vers le tableau de bord web (onboarding) au lieu de l’app hôte.
Future<AtlassianOAuthSignInOutcome> completeSessionWithAtlassianOAuth({
  required BuildContext context,
  required FlutterAdgentsSession session,
  String? inviteToken,
  String? oauthLoginReturnUri,
  bool allowServerDefaultReturnUri = false,

  /// Clé projet SDK (`fad_…`) ou UUID — préfixes OAuth configurés sur le projet (tableau de bord SaaS).
  String? projectId,
}) async {
  final returnUri = oauthLoginReturnUri?.trim();
  if (!kIsWeb &&
      (returnUri == null || returnUri.isEmpty) &&
      !allowServerDefaultReturnUri) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sur mobile : même schéma OAuth que dans le manifeste ; préfixes autorisés = config serveur '
            '+ préfixes enregistrés sur le projet (tableau de bord). Le SDK envoie automatiquement le projectId.',
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    }
    return AtlassianOAuthSignInOutcome.cancelled;
  }

  final start = await session.getAtlassianLoginAuthorizationUrl(
    inviteToken: inviteToken,
    returnUri: returnUri != null && returnUri.isNotEmpty ? returnUri : null,
    projectId: projectId != null && projectId.trim().isNotEmpty
        ? projectId.trim()
        : null,
  );
  if (!context.mounted) return AtlassianOAuthSignInOutcome.cancelled;

  if (!start.configured) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Connexion Atlassian non configurée côté serveur (variables ATLASSIAN_OAUTH_*).',
        ),
      ),
    );
    return AtlassianOAuthSignInOutcome.cancelled;
  }
  final authPageUrl = start.authorizationUrl;
  if (authPageUrl == null || authPageUrl.isEmpty) {
    return AtlassianOAuthSignInOutcome.cancelled;
  }

  final authUri = Uri.parse(authPageUrl);
  final sameTabWeb = kIsWeb && returnUri != null && returnUri.isNotEmpty;

  // iOS / Android / desktop : session d’auth système (ASWebAuthenticationSession, etc.) —
  // évite Safari externe + la feuille « Ouvrir dans l’app ? » sur le deep link custom.
  if (!kIsWeb &&
      returnUri != null &&
      returnUri.isNotEmpty &&
      isNativeOauthDeepLinkReturnUri(returnUri)) {
    final scheme = Uri.parse(returnUri).scheme;
    if (scheme.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('returnUri OAuth invalide (schéma vide).')),
        );
      }
      return AtlassianOAuthSignInOutcome.cancelled;
    }
    try {
      final callbackResult = await FlutterWebAuth2.authenticate(
        url: authPageUrl,
        callbackUrlScheme: scheme,
      );
      final cb = Uri.parse(callbackResult);
      final err = cb.queryParameters['oauth_error'];
      if (err != null && err.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OAuth : $err')),
          );
        }
        return AtlassianOAuthSignInOutcome.cancelled;
      }
      final code = cb.queryParameters['oauth_exchange'];
      if (code == null || code.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Retour Atlassian sans code d’échange.'),
            ),
          );
        }
        return AtlassianOAuthSignInOutcome.cancelled;
      }
      await session.signInWithOAuthExchangeCode(code);
      return AtlassianOAuthSignInOutcome.signedIn;
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') {
        return AtlassianOAuthSignInOutcome.cancelled;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? e.code),
          ),
        );
      }
      return AtlassianOAuthSignInOutcome.cancelled;
    } on FlutterAdgentsApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return AtlassianOAuthSignInOutcome.cancelled;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
      return AtlassianOAuthSignInOutcome.cancelled;
    }
  }

  final launched = kIsWeb
      ? await launchUrl(
          authUri,
          webOnlyWindowName: sameTabWeb ? '_self' : '_blank',
        )
      : await launchUrl(authUri, mode: LaunchMode.externalApplication);

  if (!launched) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir la page Atlassian.')),
      );
    }
    return AtlassianOAuthSignInOutcome.cancelled;
  }

  if (sameTabWeb) {
    return AtlassianOAuthSignInOutcome.redirectStarted;
  }

  if (!context.mounted) return AtlassianOAuthSignInOutcome.cancelled;

  final dialogOk = await _promptOAuthExchangeAndSignIn(context, session);
  return dialogOk
      ? AtlassianOAuthSignInOutcome.signedIn
      : AtlassianOAuthSignInOutcome.cancelled;
}

Future<bool> _promptOAuthExchangeAndSignIn(
  BuildContext context,
  FlutterAdgentsSession session,
) async {
  final codeCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var busy = false;
  String? error;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: !busy,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Finaliser la connexion Atlassian'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Après autorisation sur Atlassian, le serveur vous redirige vers une URL '
                      'contenant oauth_exchange=…. Copiez cette valeur (sans le nom du paramètre) '
                      'et collez-la ci-dessous.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          error!,
                          style:
                              TextStyle(color: Theme.of(ctx).colorScheme.error),
                        ),
                      ),
                    TextFormField(
                      controller: codeCtrl,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'Code d’échange',
                        hintText: 'Valeur après oauth_exchange=',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requis' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setLocal(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await session
                              .signInWithOAuthExchangeCode(codeCtrl.text);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } on FlutterAdgentsApiException catch (e) {
                          setLocal(() {
                            busy = false;
                            error = e.message;
                          });
                        } catch (e) {
                          setLocal(() {
                            busy = false;
                            error = e.toString();
                          });
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Valider'),
              ),
            ],
          );
        },
      );
    },
  );

  codeCtrl.dispose();
  return ok == true;
}
