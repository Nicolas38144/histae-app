import 'package:flutter/widgets.dart';

import '../application/push_controller.dart';

class PushScope extends InheritedNotifier<PushController> {
  const PushScope({
    super.key,
    required PushController? controller,
    required super.child,
  }) : super(notifier: controller);

  static PushController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PushScope>()?.notifier;
}
