import 'package:flutter/material.dart';

import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../data/discovery_models.dart';
import 'discovery_strings.dart';
import 'feed_profile_content.dart';

class FeedProfileCard extends StatefulWidget {
  const FeedProfileCard({
    super.key,
    required this.profile,
    required this.enabled,
    required this.onLike,
    required this.onPass,
  });
  final FeedProfile profile;
  final bool enabled;
  final VoidCallback onLike, onPass;
  @override
  State<FeedProfileCard> createState() => _FeedProfileCardState();
}

class _FeedProfileCardState extends State<FeedProfileCard> {
  double _overscroll = 0;
  bool _readyToPass = false;
  bool _canPassThisDrag = false;
  bool _scroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _overscroll = 0;
      _canPassThisDrag =
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
      final pass = _readyToPass && widget.enabled;
      _overscroll = 0;
      _canPassThisDrag = false;
      if (_readyToPass) {
        setState(() {
          _readyToPass = false;
        });
      }
      if (pass) widget.onPass();
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.enabled ? widget.onLike : null,
          child: NotificationListener<ScrollNotification>(
            onNotification: _scroll,
            child: SingleChildScrollView(
              key: const Key('feed-profile-scroll'),
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
                    distanceLabel: DiscoveryStrings.distance(p.distance),
                    traits: p.traits,
                    answers: p.answers,
                  ),
                  const EditorialDivider(),
                  Text(
                    _readyToPass ? 'Relâchez pour passer' : 'Double appui pour aimer.\nEn fin de lecture, glissez vers le haut pour passer.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.enabled ? widget.onPass : null,
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('Passer'),
                      ),
                      HistaeButton.icon(
                        onPressed: widget.enabled ? widget.onLike : null,
                        icon: const Icon(Icons.favorite_border),
                        label: const Text('J’aime'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
