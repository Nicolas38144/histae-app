import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Content scrollers, excluding the horizontal main-tab pager and carousels.
Finder get verticalScrollables => find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable &&
      axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
);
