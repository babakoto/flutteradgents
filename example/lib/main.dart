import 'package:flutter/material.dart';
import 'package:flutteradgents/flutteradgents.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterAdgentsHosts.forProject(
      projectId: 'fad_demo_project_id',
      flavor: 'develop',
      child: MaterialApp(
        title: 'flutteradgents example',
        debugShowCheckedModeBanner: false,
        builder: FlutterAdgents.materialAppBuilder,
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutteradgents example')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => FlutterAdgents.showFeedback(context),
          child: const Text('Open feedback'),
        ),
      ),
    );
  }
}
