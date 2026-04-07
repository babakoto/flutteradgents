import 'package:flutter/material.dart';
import 'package:flutteradgents/src/api/flutter_adgents_api_exception.dart';
import 'package:flutteradgents/src/session/flutter_adgents_session.dart';
import 'package:flutteradgents/src/widgets/atlassian_oauth_sign_in_flow.dart';
import 'package:flutteradgents/src/widgets/flutter_adgents_inherited.dart';

/// Dialogue simple : OAuth Atlassian ou e-mail / mot de passe ; retourne `true` si la connexion a réussi.
Future<bool> showFlutterAdgentsSignInDialog(
  BuildContext context, {
  required FlutterAdgentsSession session,
  String? inviteToken,
}) async {
  final email = TextEditingController();
  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var loading = false;
  var atlassianBusy = false;
  String? error;
  void Function()? oauthDeepLinkListener;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: !loading && !atlassianBusy,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          final busy = loading || atlassianBusy;
          return AlertDialog(
            title: const Text('Connexion FlutterAdgents'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'JWT via e-mail / mot de passe ou Atlassian (OAuth).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              setLocal(() {
                                atlassianBusy = true;
                                error = null;
                              });
                              try {
                                final inh =
                                    FlutterAdgentsInherited.maybeOf(ctx);
                                final oauthReturn =
                                    inh?.settings.oauthLoginReturnUri;
                                final allowDefault = inh?.settings
                                        .allowOauthWithServerDefaultReturnUri ??
                                    false;
                                final outcome =
                                    await completeSessionWithAtlassianOAuth(
                                  context: ctx,
                                  session: session,
                                  inviteToken: inviteToken,
                                  oauthLoginReturnUri: oauthReturn,
                                  allowServerDefaultReturnUri: allowDefault,
                                  projectId: inh?.settings.projectId,
                                );
                                if (outcome ==
                                        AtlassianOAuthSignInOutcome.signedIn &&
                                    ctx.mounted) {
                                  Navigator.pop(ctx, true);
                                } else if (outcome ==
                                    AtlassianOAuthSignInOutcome
                                        .redirectStarted) {
                                  if (oauthDeepLinkListener != null) {
                                    session
                                        .removeListener(oauthDeepLinkListener!);
                                    oauthDeepLinkListener = null;
                                  }
                                  void listener() {
                                    if (session.isSignedIn) {
                                      session.removeListener(listener);
                                      oauthDeepLinkListener = null;
                                      if (ctx.mounted) Navigator.pop(ctx, true);
                                    }
                                  }

                                  oauthDeepLinkListener = listener;
                                  session.addListener(listener);
                                }
                              } on FlutterAdgentsApiException catch (e) {
                                setLocal(() => error = e.message);
                              } catch (e) {
                                setLocal(() => error = e.toString());
                              } finally {
                                setLocal(() => atlassianBusy = false);
                              }
                            },
                      icon: atlassianBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link, size: 18),
                      label: const Text('Atlassian'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !busy,
                      validator: (v) =>
                          v == null || v.isEmpty || !v.contains('@')
                              ? 'Email invalide'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: password,
                      decoration:
                          const InputDecoration(labelText: 'Mot de passe'),
                      obscureText: true,
                      enabled: !busy,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Requis' : null,
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
                          loading = true;
                          error = null;
                        });
                        try {
                          await session.signIn(
                            email: email.text,
                            password: password.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } on FlutterAdgentsApiException catch (e) {
                          setLocal(() {
                            loading = false;
                            error = e.message;
                          });
                        } catch (e) {
                          setLocal(() {
                            loading = false;
                            error = e.toString();
                          });
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Se connecter'),
              ),
            ],
          );
        },
      );
    },
  );

  if (oauthDeepLinkListener != null) {
    session.removeListener(oauthDeepLinkListener!);
    oauthDeepLinkListener = null;
  }
  email.dispose();
  password.dispose();
  return ok == true;
}
