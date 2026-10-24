import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';

typedef SubscriptionPlanSlide = ({String id, String label, Widget child});

/// Shared by the public catalogue and subscription management.
/// One offer at a time, without imposing a height that could truncate its text.
class SubscriptionPlanCarousel extends StatefulWidget {
  const SubscriptionPlanCarousel({
    super.key,
    required this.slides,
    this.initialSlideId,
  }) : assert(slides.length > 0);

  final List<SubscriptionPlanSlide> slides;
  final String? initialSlideId;

  @override
  State<SubscriptionPlanCarousel> createState() =>
      _SubscriptionPlanCarouselState();
}

class _SubscriptionPlanCarouselState extends State<SubscriptionPlanCarousel> {
  late final PageController _pages;
  final _heights = <String, double>{};
  late int _index;

  int get _preferredIndex {
    final index = widget.slides.indexWhere(
      (slide) => slide.id == widget.initialSlideId,
    );
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _index = _preferredIndex;
    _pages = PageController(initialPage: _index, viewportFraction: 0.92);
  }

  @override
  void didUpdateWidget(SubscriptionPlanCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = oldWidget.slides[_index].id;
    final next = widget.slides.indexWhere((slide) => slide.id == selected);
    final nextIndex = next < 0 ? _preferredIndex : next;
    _heights.removeWhere(
      (id, _) => !widget.slides.any((slide) => slide.id == id),
    );
    if (nextIndex != _index) {
      _index = nextIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(_index);
      });
    }
  }

  void _goTo(int index) {
    if (index == _index || !_pages.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _resize(String id, double height) {
    if (!mounted ||
        _heights[id] == height ||
        !widget.slides.any((slide) => slide.id == id)) {
      return;
    }
    setState(() => _heights[id] = height);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context).messages;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final height =
        _heights[widget.slides[_index].id] ??
        _heights.values.firstOrNull ??
        MediaQuery.sizeOf(context).height * 0.75;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.slides.length > 1) ...[
          Theme(
            // RawChip's Material must also reveal the gradient behind it.
            data: theme.copyWith(canvasColor: Colors.transparent),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (var index = 0; index < widget.slides.length; index++)
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(
                        side: index == _index
                            ? BorderSide.none
                            : BorderSide(color: colors.outlineVariant),
                      ),
                      gradient: index == _index
                          ? HistaeTokens.actionGradient
                          : null,
                      color: index == _index
                          ? null
                          : colors.surfaceContainerLow,
                    ),
                    child: ChoiceChip(
                      key: ValueKey('plan-selector-${widget.slides[index].id}'),
                      label: Text(widget.slides[index].label),
                      selected: index == _index,
                      showCheckmark: false,
                      selectedColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      side: BorderSide.none,
                      labelStyle: theme.textTheme.bodySmall?.copyWith(
                        color: index == _index
                            ? HistaeTokens.night
                            : colors.onSurface,
                        fontWeight: index == _index
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      onSelected: (_) => _goTo(index),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        AnimatedContainer(
          alignment: Alignment.topCenter,
          height: height,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: PageView.builder(
            key: const Key('subscription-plan-pages'),
            controller: _pages,
            itemCount: widget.slides.length,
            allowImplicitScrolling: true,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final slide = widget.slides[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: _PlanSize(
                    key: ValueKey(slide.id),
                    onHeight: (height) => _resize(slide.id, height),
                    child: slide.child,
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.slides.length > 1)
          Row(
            children: [
              IconButton(
                tooltip: copy.subscriptionPreviousOffer,
                onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    copy.subscriptionOfferPosition(
                      _index + 1,
                      widget.slides.length,
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              IconButton(
                tooltip: copy.subscriptionNextOffer,
                onPressed: _index < widget.slides.length - 1
                    ? () => _goTo(_index + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
      ],
    );
  }
}

class _PlanSize extends SingleChildRenderObjectWidget {
  const _PlanSize({super.key, required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _PlanSizeRenderObject(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _PlanSizeRenderObject renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _PlanSizeRenderObject extends RenderProxyBox {
  _PlanSizeRenderObject(this.onHeight);
  ValueChanged<double> onHeight;
  double? _lastHeight;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _lastHeight) return;
    _lastHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}
