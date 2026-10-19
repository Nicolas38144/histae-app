import 'package:flutter/widgets.dart';

import '../data/rewarded_video_gateway.dart';

class RewardedVideoScope extends InheritedWidget {
  const RewardedVideoScope({
    super.key,
    required this.gateway,
    required super.child,
  });
  final RewardedVideoGateway? gateway;
  static RewardedVideoGateway? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RewardedVideoScope>()?.gateway;
  @override
  bool updateShouldNotify(RewardedVideoScope oldWidget) =>
      gateway != oldWidget.gateway;
}
