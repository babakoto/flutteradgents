import 'package:flutter/material.dart';
import 'package:flutteradgents/src/api/flutter_adgents_api_exception.dart';
import 'package:flutteradgents/src/session/flutter_adgents_session.dart';
import 'package:flutteradgents/src/widgets/atlassian_oauth_sign_in_flow.dart';
import 'package:flutteradgents/src/widgets/flutter_adgents_inherited.dart';

/// Page plein écran de connexion (JWT). Retourne `true` via [Navigator.pop] si succès.
///
/// [inviteToken] : transmis au serveur si l’utilisateur arrive d’un flux d’invitation (OAuth login).
Future<bool> pushFlutterAdgentsSignInPage(
  BuildContext context, {
  required FlutterAdgentsSession session,
  String? inviteToken,
}) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (ctx) => _FlutterAdgentsSignInScaffold(
        session: session,
        inviteToken: inviteToken,
      ),
    ),
  );
  return ok == true;
}

class _FlutterAdgentsSignInScaffold extends StatefulWidget {
  const _FlutterAdgentsSignInScaffold({
    required this.session,
    this.inviteToken,
  });

  final FlutterAdgentsSession session;
  final String? inviteToken;

  @override
  State<_FlutterAdgentsSignInScaffold> createState() =>
      _FlutterAdgentsSignInScaffoldState();
}

class _FlutterAdgentsSignInScaffoldState
    extends State<_FlutterAdgentsSignInScaffold> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _atlassianBusy = false;
  String? _error;
  void Function()? _oauthDeepLinkListener;

  @override
  void dispose() {
    if (_oauthDeepLinkListener != null) {
      widget.session.removeListener(_oauthDeepLinkListener!);
      _oauthDeepLinkListener = null;
    }
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _attachSessionListenerUntilSignedIn() {
    if (_oauthDeepLinkListener != null) {
      widget.session.removeListener(_oauthDeepLinkListener!);
      _oauthDeepLinkListener = null;
    }
    void listener() {
      if (!mounted) return;
      if (widget.session.isSignedIn) {
        widget.session.removeListener(listener);
        _oauthDeepLinkListener = null;
        Navigator.of(context).pop(true);
      }
    }

    _oauthDeepLinkListener = listener;
    widget.session.addListener(listener);
  }

  Future<void> _submitPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.session.signIn(
        email: _email.text,
        password: _password.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FlutterAdgentsApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _startAtlassian() async {
    setState(() {
      _atlassianBusy = true;
      _error = null;
    });
    try {
      final inh = FlutterAdgentsInherited.maybeOf(context);
      final oauthReturn = inh?.settings.oauthLoginReturnUri;
      final allowDefault =
          inh?.settings.allowOauthWithServerDefaultReturnUri ?? false;
      final outcome = await completeSessionWithAtlassianOAuth(
        context: context,
        session: widget.session,
        inviteToken: widget.inviteToken,
        oauthLoginReturnUri: oauthReturn,
        allowServerDefaultReturnUri: allowDefault,
        projectId: inh?.settings.projectId,
      );
      if (mounted && outcome == AtlassianOAuthSignInOutcome.signedIn) {
        Navigator.of(context).pop(true);
      } else if (mounted &&
          outcome == AtlassianOAuthSignInOutcome.redirectStarted) {
        _attachSessionListenerUntilSignedIn();
      }
    } on FlutterAdgentsApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _atlassianBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final busy = _loading || _atlassianBusy;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
        ),
        title: const Text('Connexion'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 56, color: cs.primary),
                    const SizedBox(height: 16),
                    Text(
                      'FlutterAdgents',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connectez-vous pour envoyer un signalement. '
                      'L’API utilise un jeton JWT : e-mail + mot de passe, ou Atlassian (OAuth) en alternative.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    if (widget.inviteToken != null &&
                        widget.inviteToken!.trim().isNotEmpty) ...[
                      Material(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'Si vous venez d’une invitation, utilisez l’e-mail indiqué dans le message.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_error != null) ...[
                      Material(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: cs.onErrorContainer),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    OutlinedButton.icon(
                      onPressed: busy ? null : _startAtlassian,
                      icon: _atlassianBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link),
                      label: const Text('Continuer avec Atlassian'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: cs.outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'ou e-mail',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                        Expanded(child: Divider(color: cs.outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty || !v.contains('@')
                              ? 'Email invalide'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      enabled: !busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitPassword(),
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: busy ? null : _submitPassword,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Se connecter'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
