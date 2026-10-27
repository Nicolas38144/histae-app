import 'package:flutter/widgets.dart';

import '../application/help_controller.dart';

class HelpScope extends InheritedWidget {
  const HelpScope({super.key, required this.controller, required super.child});
  final HelpController? controller;

  static HelpController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HelpScope>()?.controller;

  @override
  bool updateShouldNotify(HelpScope oldWidget) =>
      oldWidget.controller != controller;
}
