import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../data/discovery_models.dart';
import 'discovery_strings.dart';
import 'feed_profile_content.dart';
import 'feed_reading_progress.dart';

class FeedProfileCard extends StatefulWidget {
  const FeedProfileCard({
    super.key,
    required this.profile,
    required this.enabled,
    required this.onLike,
    required this.onPass,
    this.active = true,
  });
  final FeedProfile profile;
  final bool enabled;
  final bool active;
  final VoidCallback onLike, onPass;

  @override
  State<FeedProfileCard> createState() => _FeedProfileCardState();
}

class _FeedProfileCardState extends State<FeedProfileCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _readingDuration = Duration(seconds: 3);
  late final _readingDelay = AnimationController(
    vsync: this,
    duration: _readingDuration,
    animationBehavior: AnimationBehavior.preserve,
  )..addListener(_readingChanged);
  int _remainingSeconds = _readingDuration.inSeconds;
  final _scrollController = ScrollController(keepScrollOffset: false);
  double _overscroll = 0;
  bool _readyToPass = false;
  bool _canPassThisDrag = false;

  bool get _enabled =>
      widget.active && widget.enabled && _readingDelay.value == 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateReading();
  }

  @override
  void didUpdateWidget(FeedProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      _readingDelay.reset();
      _overscroll = 0;
      _readyToPass = false;
      _canPassThisDrag = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
    _updateReading();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _updateReading();

  void _updateReading() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final visible =
        widget.active &&
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    if (visible && _readingDelay.value < 1) {
      if (!_readingDelay.isAnimating) _readingDelay.forward();
    } else {
      _readingDelay.stop();
    }
  }

  void _readingChanged() {
    final remaining = ((1 - _readingDelay.value) * _readingDuration.inSeconds)
        .ceil();
    if (remaining != _remainingSeconds) {
      setState(() => _remainingSeconds = remaining);
    }
  }

  void _like() {
    if (_enabled) widget.onLike();
  }

  void _pass() {
    if (_enabled) widget.onPass();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readingDelay.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _scroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _overscroll = 0;
      _canPassThisDrag =
          _enabled &&
          notification.dragDetails != null &&
          notification.metrics.extentAfter <= 0.5;
    }
    if (notification is OverscrollNotification &&
        _canPassThisDrag &&
        notification.dragDetails != null &&
        notification.metrics.extentAfter == 0) {
      _overscroll = (_overscroll + notification.overscroll).clamp(0, 1000);
      if (_readyToPass != (_overscroll >= 80)) {
        setState(() {
          _readyToPass = _overscroll >= 80;
        });
      }
    }
    if (notification is ScrollEndNotification) {
      final pass = _readyToPass && _enabled;
      _overscroll = 0;
      _canPassThisDrag = false;
      if (_readyToPass) {
        setState(() {
          _readyToPass = false;
        });
      }
      if (pass) _pass();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final theme = Theme.of(context);
    return Card(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: HistaeTokens.panelGradient(context),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: _enabled ? _like : null,
              child: NotificationListener<ScrollNotification>(
                onNotification: _scroll,
                child: SingleChildScrollView(
                  key: const Key('feed-profile-scroll'),
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FeedProfileContent(
                        firstname: p.firstname,
                        age: p.age,
                        bio: p.bio,
                        distanceLabel: DiscoveryStrings(AppStrings.of(context))
                            .distance(p.distance),
                        traits: p.traits,
                        answers: p.answers,
                      ),
                      const EditorialDivider(),
                      Text(
                        _readyToPass
                            ? AppStrings.of(context)
                                  .messages
                                  .feedProfileCardReleaseToPass
                            : AppStrings.of(context)
                                  .messages
                                  .feedProfileCardDoubleTapToLikeAtThe,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          HistaeButton.outlinedIcon(
                            onPressed: _enabled ? _pass : null,
                            icon: const Icon(Icons.arrow_upward),
                            label: Text(
                              AppStrings.of(context)
                                  .messages
                                  .feedProfileCardPass,
                            ),
                          ),
                          HistaeButton.icon(
                            onPressed: _enabled ? _like : null,
                            icon: const Icon(Icons.favorite_border),
                            label: Text(
                              AppStrings.of(context)
                                  .messages
                                  .feedProfileCardLike,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FeedReadingProgress(
                progress: _readingDelay,
                remainingSeconds: _remainingSeconds,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
