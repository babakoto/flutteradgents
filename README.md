# flutteradgents

![FlutterAdgents logo](assets/logo.png)

Flutteradgents is a solution designed for testers and QA teams responsible for app validation. **Directly from within the project**, it allows users to log in with their Jira account, capture screenshots, add annotations, and easily create and assign bug tickets to developers.

Each generated ticket automatically includes all the essential information needed for faster resolution, such as:  
🌍 Environment: dev  
📟 Platform: iOS  
📱 Device: iPhone 17 Pro · iOS 26.2  
🔢 Build number: 1  
📌 Build version: 1.0.0  
📲 App name: Demo

![FlutterAdgents package overview](assets/logo.png)


In your app `pubspec.yaml`:

```yaml  
dependencies:   
 flutteradgents: x.x.x 
```  

## Get started

```dart
return FlutterAdgentsHosts(
  settings: FlutterAdgentsSettings.simple(
    projectId: 'fad_XXXXXXXX', // Step 1
    flavor: 'develop', // Step 2
  ),
  child: MaterialApp(
    builder: FlutterAdgents.materialAppBuilder, // Step 3
  ),
);
```

## How testers open the login screen

With the default setup, **`FlutterAdgents.materialAppBuilder` listens for a “secret tap”**: the user must **tap 5 times quickly** on the app (anywhere on the content). That opens the FlutterAdgents flow; **if the user is not signed in yet, the login page is shown first.**

You can change the required number of taps by wrapping the builder yourself, for example:

```dart
builder: (context, child) => FlutterAdgents.materialAppBuilder(
  context,
  child,
  secretTapCount: 5, // default
),
```

## Example app

An executable example is available in `example/`.

```bash
cd example
flutter pub get
flutter run
```
