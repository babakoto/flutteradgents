// Package flutteradgents : capture type « feedback » + envoi vers l’API (auth + issues).
export 'package:flutteradgents_feedback/flutteradgents_feedback.dart'
    show
        BetterFeedback,
        FeedbackBuilder,
        FeedbackController,
        FeedbackMode,
        FeedbackSheetDragHandle,
        FeedbackThemeData,
        OnSubmit,
        UserFeedback;

export 'src/api/flutter_adgents_api_exception.dart';
export 'src/api/jira_assignable_user.dart';
export 'src/api/jira_assignable_users_api.dart';
export 'src/api/issue_create_result.dart';
export 'src/api/issue_feedback_fields.dart';
export 'src/config/flutter_adgents_defaults.dart';
export 'src/config/flutter_adgents_settings.dart';
export 'src/runtime/flutter_adgents_runtime.dart'
    show
        detectFlutterAdgentsClientPlatform,
        effectiveClientPlatform,
        enrichIssueDescriptionWithRuntimeMetadata,
        environmentForApi,
        normalizeUserIssueDescription;
export 'src/runtime/issue_description_metadata.dart';
export 'src/flutter_adgents.dart';
export 'src/session/flutter_adgents_session.dart';
export 'src/widgets/flutter_adgents_hosts.dart';
export 'src/widgets/flutter_adgents_inherited.dart';
export 'src/widgets/flutter_adgents_oauth_return_listener.dart'
    show
        FlutterAdgentsOAuthReturnListener,
        FlutterAdgentsOAuthReturnOutcome,
        FlutterAdgentsOnOAuthReturn;
export 'src/widgets/flutter_adgents_issue_feedback_builder.dart'
    show flutterAdgentsIssueFeedbackBuilder;
export 'src/widgets/flutter_adgents_secret_tap_scope.dart';
export 'src/widgets/atlassian_oauth_sign_in_flow.dart'
    show
        AtlassianOAuthSignInOutcome,
        completeSessionWithAtlassianOAuth,
        isNativeOauthDeepLinkReturnUri;
export 'src/widgets/sign_in_page.dart' show pushFlutterAdgentsSignInPage;
export 'src/widgets/sign_in_sheet.dart' show showFlutterAdgentsSignInDialog;
