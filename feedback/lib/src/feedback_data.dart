// ignore_for_file: public_member_api_docs

import 'package:flutteradgents_feedback/src/feedback_controller.dart';
import 'package:flutter/material.dart';

class FeedbackData extends InheritedWidget {
  const FeedbackData({
    super.key,
    required super.child,
    required this.controller,
  });

  final FeedbackController controller;

  /// Sans abonnement aux mises à jour (ex. callbacks ponctuels).
  static FeedbackData? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<FeedbackData>();
  }

  @override
  bool updateShouldNotify(FeedbackData oldWidget) {
    return oldWidget.controller != controller;
  }
}
