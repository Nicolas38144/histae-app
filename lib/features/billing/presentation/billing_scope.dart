import 'package:flutter/widgets.dart';

import '../application/billing_controller.dart';

class BillingScope extends InheritedWidget {
  const BillingScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final BillingController? controller;

  static BillingController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BillingScope>()?.controller;

  @override
  bool updateShouldNotify(BillingScope oldWidget) =>
      oldWidget.controller != controller;
}
