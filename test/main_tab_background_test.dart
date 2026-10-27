import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histae_app/app/main_tab_pager.dart';
import 'package:histae_app/app/theme.dart';
import 'package:histae_app/core/widgets/histae_scaffold.dart';

void main() {
  testWidgets('the route background stays stationary throughout a tab swipe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PageController(initialPage: 1);
    addTearDown(controller.dispose);
    var selected = 1;
    const frame = Key('background-frame');
    await tester.pumpWidget(
      MaterialApp(
        theme: histaeTheme(Brightness.dark),
        home: RepaintBoundary(
          key: frame,
          child: StatefulBuilder(
            builder: (context, setState) => HistaeScaffold(
              body: MainTabPager(
                controller: controller,
                selectedIndex: selected,
                onPageChanged: (index) => setState(() => selected = index),
                children: const [
                  HistaeScaffold(body: SizedBox.expand()),
                  HistaeScaffold(body: SizedBox.expand()),
                  HistaeScaffold(body: SizedBox.expand()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<Uint8List> pixels() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(frame),
      );
      return (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          return data!.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      }))!;
    }

    final initial = await pixels();
    final gesture = await tester.startGesture(const Offset(250, 400));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(controller.page, allOf(greaterThan(1), lessThan(2)));
    expect(listEquals(await pixels(), initial), isTrue);
    await gesture.moveBy(const Offset(-180, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(listEquals(await pixels(), initial), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
