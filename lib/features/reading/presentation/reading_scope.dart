import 'package:flutter/widgets.dart';

import '../application/reading_controller.dart';

class ReadingScope extends InheritedNotifier<ReadingController> {
  const ReadingScope({
    super.key,
    required ReadingController controller,
    required super.child,
  }) : super(notifier: controller);

  static ReadingController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReadingScope>()?.notifier;
}
