import 'dart:async';

import 'package:flutteradgents_feedback/flutteradgents_feedback.dart';
// ignore: implementation_imports — `FeedbackTheme` n’est pas exporté par package:flutteradgents_feedback.
import 'package:flutteradgents_feedback/src/theme/feedback_theme.dart' show FeedbackTheme;
import 'package:flutter/material.dart';
import 'package:flutteradgents/src/api/flutter_adgents_api_exception.dart';
import 'package:flutteradgents/src/api/issue_feedback_fields.dart';
import 'package:flutteradgents/src/api/jira_assignable_user.dart';
import 'package:flutteradgents/src/api/jira_assignable_users_api.dart';
import 'package:flutteradgents/src/widgets/flutter_adgents_inherited.dart';

/// Thème aligné sur [FeedbackTheme] (même fond que la bottom sheet, pas le [Theme] racine).
ThemeData _themeForFeedbackSheet(BuildContext context) {
  final root = Theme.of(context);
  final ft = FeedbackTheme.of(context);
  final brightness = ft.brightness;
  final base = ColorScheme.fromSeed(
    seedColor: root.colorScheme.primary,
    brightness: brightness,
  );
  final sheet = ft.feedbackSheetColor;
  final lifted = Color.alphaBlend(
    (brightness == Brightness.dark ? Colors.white : Colors.black)
        .withValues(alpha: 0.10),
    sheet,
  );
  final liftedMore = Color.alphaBlend(
    (brightness == Brightness.dark ? Colors.white : Colors.black)
        .withValues(alpha: 0.16),
    sheet,
  );
  final scheme = base.copyWith(
    surface: sheet,
    onSurface: brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.96)
        : Colors.black87,
    onSurfaceVariant:
        brightness == Brightness.dark ? Colors.white70 : Colors.black54,
    outlineVariant:
        brightness == Brightness.dark ? Colors.white24 : Colors.black26,
    surfaceContainerHighest: liftedMore,
    surfaceContainerHigh: lifted,
    primary: root.colorScheme.primary,
    onPrimary: root.colorScheme.onPrimary,
    primaryContainer: root.colorScheme.primaryContainer,
    onPrimaryContainer: root.colorScheme.onPrimaryContainer,
    secondaryContainer: root.colorScheme.secondaryContainer,
    onSecondaryContainer: root.colorScheme.onSecondaryContainer,
    error: base.error,
    onError: base.onError,
  );
  return root.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: sheet,
    canvasColor: sheet,
  );
}

/// [FeedbackBuilder] par défaut : titre + description + assigné Jira optionnel (aligné sur l’API).
Widget flutterAdgentsIssueFeedbackBuilder(
  BuildContext context,
  OnSubmit onSubmit,
  ScrollController? scrollController,
) {
  return _IssueTitleDescriptionFeedback(
    onSubmit: onSubmit,
    scrollController: scrollController,
  );
}

class _IssueTitleDescriptionFeedback extends StatefulWidget {
  const _IssueTitleDescriptionFeedback({
    required this.onSubmit,
    required this.scrollController,
  });

  final OnSubmit onSubmit;
  final ScrollController? scrollController;

  @override
  State<_IssueTitleDescriptionFeedback> createState() =>
      _IssueTitleDescriptionFeedbackState();
}

class _IssueTitleDescriptionFeedbackState
    extends State<_IssueTitleDescriptionFeedback> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _assigneeSearch;

  Timer? _assigneeDebounce;
  JiraAssignableUser? _selectedAssignee;
  List<JiraAssignableUser> _assigneeResults = const [];
  bool _assigneeLoading = false;
  String? _assigneeError;
  bool _assigneeUnavailable = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _description = TextEditingController();
    _assigneeSearch = TextEditingController();
  }

  @override
  void dispose() {
    _assigneeDebounce?.cancel();
    _title.dispose();
    _description.dispose();
    _assigneeSearch.dispose();
    super.dispose();
  }

  void _scheduleAssigneeFetch(String rawQuery) {
    final inh = FlutterAdgentsInherited.maybeOf(context);
    if (inh == null) return;
    _assigneeDebounce?.cancel();
    _assigneeDebounce = Timer(const Duration(milliseconds: 380),
        () => _fetchAssignees(inh, rawQuery));
  }

  Future<void> _fetchAssignees(
      FlutterAdgentsInherited inh, String rawQuery) async {
    if (!mounted) return;
    setState(() {
      _assigneeLoading = true;
      _assigneeError = null;
    });
    try {
      final api = JiraAssignableUsersApi(inh.dio, inh.settings);
      final q = rawQuery.trim();
      final list = await api.listAssignableUsers(
        query: q.isEmpty ? null : q,
        maxResults: 25,
      );
      if (!mounted) return;
      setState(() {
        _assigneeLoading = false;
        _assigneeResults = list;
        _assigneeUnavailable = false;
      });
    } on FlutterAdgentsApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _assigneeLoading = false;
        _assigneeResults = const [];
        final msg = e.message.toLowerCase();
        if (e.statusCode == 404) {
          final noJiraConfig = msg.contains('aucune configuration jira') ||
              msg.contains('configuration jira pour ce projet');
          if (noJiraConfig) {
            _assigneeUnavailable = true;
            _assigneeError = null;
          } else if (msg.contains('projet introuvable')) {
            _assigneeUnavailable = false;
            _assigneeError =
                'Projet introuvable : l’UUID dans les réglages (ID projet) n’existe pas '
                'sur l’API pour ce compte. Après OAuth / un autre login, copiez l’UUID '
                'd’un projet du **tableau de bord** ouvert avec le **même** utilisateur.';
          } else {
            _assigneeUnavailable = false;
            _assigneeError = e.message;
          }
        } else if (e.statusCode == 403 && msg.contains('accès projet refusé')) {
          _assigneeUnavailable = false;
          _assigneeError =
              'Accès au projet refusé : ce compte n’est pas membre de ce projet. '
              'Vérifiez l’UUID ou demandez une invitation.';
        } else {
          _assigneeUnavailable = false;
          _assigneeError = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assigneeLoading = false;
        _assigneeResults = const [];
        _assigneeError = e.toString();
      });
    }
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    bool alignLabelWithHint = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final r = BorderRadius.circular(16);
    final idle = cs.outlineVariant.withValues(alpha: 0.4);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: idle, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(
          color: Color.alphaBlend(
            cs.primary.withValues(alpha: 0.88),
            cs.surface,
          ),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide:
            BorderSide(color: cs.error.withValues(alpha: 0.9), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: cs.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ft = FeedbackTheme.of(context);
    return Theme(
      data: _themeForFeedbackSheet(context),
      child: Builder(
        builder: (context) {
          return _buildSheetBody(context, ft);
        },
      ),
    );
  }

  Widget _buildSheetBody(BuildContext context, FeedbackThemeData ft) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final inh = FlutterAdgentsInherited.maybeOf(context);
    final topPad = widget.scrollController != null ? 10.0 : 8.0;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    const footerReserve = 96.0;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              ListView(
                controller: widget.scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    20, topPad, 20, footerReserve + bottomInset + 12),
                children: [
                  Row(
                    children: [
                      Icon(Icons.mark_chat_unread_rounded,
                          color: cs.primary, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Signaler un problème',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    FeedbackLocalizations.of(context).feedbackDescriptionText,
                    style: (theme.textTheme.bodyMedium ?? const TextStyle())
                        .copyWith(
                          height: 1.35,
                        )
                        .merge(ft.bottomSheetDescriptionStyle),
                  ),
                  if (widget.scrollController != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Glissez la poignée vers le haut pour agrandir le formulaire.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _title,
                          style: theme.textTheme.bodyLarge,
                          decoration: _fieldDecoration(
                            context,
                            label: 'Titre *',
                            hint: 'Résumé du ticket (max. 255 caractères)',
                          ),
                          maxLength: 255,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Requis';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _description,
                          style: theme.textTheme.bodyLarge,
                          decoration: _fieldDecoration(
                            context,
                            label: 'Description *',
                            hint: 'Étapes, comportement attendu…',
                            alignLabelWithHint: true,
                          ),
                          minLines: 4,
                          maxLines: 8,
                          textInputAction: TextInputAction.newline,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Requis';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _AssigneeSection(
                          theme: theme,
                          cs: cs,
                          inheritedAvailable: inh != null,
                          selected: _selectedAssignee,
                          searchController: _assigneeSearch,
                          results: _assigneeResults,
                          loading: _assigneeLoading,
                          errorText: _assigneeError,
                          unavailable: _assigneeUnavailable,
                          fieldDecoration: _fieldDecoration,
                          onSearchChanged: (s) {
                            if (_selectedAssignee != null) return;
                            _scheduleAssigneeFetch(s);
                          },
                          onSearchTap: () {
                            if (inh != null &&
                                _assigneeSearch.text.trim().isEmpty) {
                              _fetchAssignees(inh, '');
                            }
                          },
                          onPick: (u) {
                            setState(() {
                              _selectedAssignee = u;
                              _assigneeSearch.clear();
                              _assigneeResults = const [];
                              _assigneeError = null;
                            });
                          },
                          onClearSelection: () {
                            setState(() {
                              _selectedAssignee = null;
                              _assigneeResults = const [];
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              if (widget.scrollController != null)
                const FeedbackSheetDragHandle(),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: ft.feedbackSheetColor,
            border: Border(
              top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.35 : 0.08,
                ),
                blurRadius: 16,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    foregroundColor: cs.onPrimary,
                  ),
                  onPressed: () async {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    final title = _title.text.trim();
                    final desc = _description.text.trim();
                    final extras = <String, dynamic>{
                      kFlutterAdgentsFeedbackExtraTitle: title,
                      kFlutterAdgentsFeedbackExtraDescription: desc,
                    };
                    final a = _selectedAssignee;
                    if (a != null) {
                      extras[kFlutterAdgentsFeedbackExtraAssigneeAccountId] =
                          a.accountId;
                    }
                    await widget.onSubmit(desc, extras: extras);
                  },
                  icon: Icon(Icons.send_rounded, size: 20, color: cs.onPrimary),
                  label: Text(
                    FeedbackLocalizations.of(context).submitButtonText,
                    style: TextStyle(color: cs.onPrimary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Avatar Jira : photo réseau si [avatarUrl] est fourni par l’API, sinon initiales.
class _JiraAssigneeAvatar extends StatelessWidget {
  const _JiraAssigneeAvatar({
    required this.displayName,
    required this.avatarUrl,
    required this.radius,
    required this.fallbackBackground,
    required this.fallbackForeground,
  });

  final String displayName;
  final String? avatarUrl;
  final double radius;
  final Color fallbackBackground;
  final Color fallbackForeground;

  String get _initial {
    final t = displayName.trim();
    if (t.isEmpty) return '?';
    return t.characters.first.toUpperCase();
  }

  Widget _initialsCircle() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: fallbackBackground,
      foregroundColor: fallbackForeground,
      child: Text(
        _initial,
        style: TextStyle(
          fontSize: radius <= 18 ? 14 : 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    if (url == null || url.isEmpty) {
      return _initialsCircle();
    }
    final size = radius * 2;
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _initialsCircle(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return SizedBox(
            width: size,
            height: size,
            child: ColoredBox(
              color: fallbackBackground,
              child: Center(
                child: SizedBox(
                  width: radius * 0.85,
                  height: radius * 0.85,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fallbackForeground,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AssigneeSection extends StatelessWidget {
  const _AssigneeSection({
    required this.theme,
    required this.cs,
    required this.inheritedAvailable,
    required this.selected,
    required this.searchController,
    required this.results,
    required this.loading,
    required this.errorText,
    required this.unavailable,
    required this.fieldDecoration,
    required this.onSearchChanged,
    required this.onSearchTap,
    required this.onPick,
    required this.onClearSelection,
  });

  final ThemeData theme;
  final ColorScheme cs;
  final bool inheritedAvailable;
  final JiraAssignableUser? selected;
  final TextEditingController searchController;
  final List<JiraAssignableUser> results;
  final bool loading;
  final String? errorText;
  final bool unavailable;
  final InputDecoration Function(
    BuildContext context, {
    required String label,
    String? hint,
    bool alignLabelWithHint,
  }) fieldDecoration;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchTap;
  final ValueChanged<JiraAssignableUser> onPick;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final sectionBorder = Border.all(
      color: cs.outlineVariant.withValues(alpha: 0.38),
      width: 1,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
            border: sectionBorder,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.groups_2_rounded, size: 22, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Assigné Jira',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        'Optionnel',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!inheritedAvailable)
                Text(
                  'Contexte FlutterAdgents indisponible — assignation désactivée.',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                )
              else if (unavailable)
                Text(
                  'Aucune config Jira sur ce projet — vous pouvez quand même envoyer le ticket.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                )
              else ...[
                if (selected != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: cs.surface.withValues(alpha: 0.72),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: cs.primary.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: _JiraAssigneeAvatar(
                          displayName: selected!.displayName,
                          avatarUrl: selected!.avatarUrl,
                          radius: 22,
                          fallbackBackground: cs.primary,
                          fallbackForeground: cs.onPrimary,
                        ),
                        title: Text(
                          selected!.displayName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.15,
                          ),
                        ),
                        subtitle: selected!.emailAddress != null
                            ? Text(
                                selected!.emailAddress!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Text(
                                'ID : ${selected!.accountId}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                        trailing: IconButton.filledTonal(
                          tooltip: 'Retirer',
                          onPressed: onClearSelection,
                          style: IconButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ),
                    ),
                  ),
                if (selected == null) ...[
                  TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    onTap: onSearchTap,
                    textInputAction: TextInputAction.search,
                    decoration: fieldDecoration(
                      context,
                      label: 'Rechercher un utilisateur',
                      hint: 'Nom affiché, email…',
                    ).copyWith(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.person_search_rounded,
                          color: cs.primary.withValues(alpha: 0.85),
                          size: 22,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 48,
                      ),
                      suffixIcon: loading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: cs.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorText!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.error,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (results.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.32),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: results.length,
                            itemBuilder: (ctx, i) {
                              final u = results[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => onPick(u),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          _JiraAssigneeAvatar(
                                            displayName: u.displayName,
                                            avatarUrl: u.avatarUrl,
                                            radius: 20,
                                            fallbackBackground:
                                                cs.secondaryContainer,
                                            fallbackForeground:
                                                cs.onSecondaryContainer,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  u.displayName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme.bodyLarge
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: -0.15,
                                                  ),
                                                ),
                                                if (u.emailAddress != null)
                                                  Text(
                                                    u.emailAddress!,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: cs.outline,
                                            size: 22,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
