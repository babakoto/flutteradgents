# feedback (vendored pour FlutterAdgents)

Base : [feedback 3.2.0](https://pub.dev/packages/feedback) (Apache-2.0).

**Modifications**

1. **`FeedbackThemeData.useFullScreenFeedbackForm`** (défaut `false`) : si `true`, la bottom sheet **n’est plus affichée** pendant l’annotation — la capture occupe (presque) tout l’écran. Le formulaire s’ouvre via **`FeedbackController.presentFeedbackForm()`** (bouton **+** dans la barre d’outils), en **dialog plein écran**.
2. Sinon, le bouton **+** appelle toujours `DraggableScrollableController.animateTo(1.0)` si `sheetIsDraggable` est `true`.

`FlutterAdgentsHosts` active `useFullScreenFeedbackForm` par défaut (`useFullScreenFeedbackForm: true`).

Pour revenir au package pub : `flutteradgents/pubspec.yaml` → `feedback: ^3.2.0` (comportements ci-dessus perdus).
