import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

/// Retains the main views while their horizontal position follows the gesture.
class MainTabPager extends StatefulWidget {
  const MainTabPager({
    super.key,
    required this.controller,
    required this.selectedIndex,
    required this.onPageChanged,
    required this.children,
  });

  final PageController controller;
  final int selectedIndex;
  final ValueChanged<int> onPageChanged;
  final List<Widget> children;

  @override
  State<MainTabPager> createState() => _MainTabPagerState();
}

class _MainTabPagerState extends State<MainTabPager> {
  bool _scrolling = false;

  bool _scrollChanged(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal) {
      return false;
    }
    if (notification is ScrollStartNotification && !_scrolling) {
      setState(() => _scrolling = true);
    } else if (notification is ScrollEndNotification && _scrolling) {
      setState(() => _scrolling = false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final touchSlop = media.gestureSettings.touchSlop ?? kTouchSlop;
    return MediaQuery(
      // Only the pager needs a deliberate horizontal gesture. Restore device
      // settings below it so vertical reading and child controls stay responsive.
      data: media.copyWith(
        gestureSettings: DeviceGestureSettings(touchSlop: touchSlop * 2.5),
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: _scrollChanged,
        child: PageView(
          key: const Key('main-tab-pages'),
          controller: widget.controller,
          onPageChanged: widget.onPageChanged,
          physics: const ClampingScrollPhysics(),
          allowImplicitScrolling: true,
          // Initialize all tabs at startup and retain them even at either end.
          scrollCacheExtent: ScrollCacheExtent.viewport(
            (widget.children.length - 1).toDouble(),
          ),
          children: [
            for (var index = 0; index < widget.children.length; index++)
              MediaQuery(
                data: media,
                child: Offstage(
                  offstage: !_scrolling && index != widget.selectedIndex,
                  child: TickerMode(
                    enabled: !_scrolling && index == widget.selectedIndex,
                    child: ExcludeFocus(
                      excluding: _scrolling || index != widget.selectedIndex,
                      child: ExcludeSemantics(
                        excluding: _scrolling || index != widget.selectedIndex,
                        child: IgnorePointer(
                          ignoring: _scrolling || index != widget.selectedIndex,
                          child: widget.children[index],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
