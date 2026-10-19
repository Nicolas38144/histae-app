import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../discovery/presentation/feed_profile_content.dart';
import '../application/profile_controller.dart';

class ProfileFeedPreviewPage extends StatefulWidget {
  const ProfileFeedPreviewPage({super.key, required this.controller});
  final ProfileController controller;

  @override
  State<ProfileFeedPreviewPage> createState() => _ProfileFeedPreviewPageState();
}

class _ProfileFeedPreviewPageState extends State<ProfileFeedPreviewPage> {
  late final _resourceKey = widget.controller.session.resourceKey;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      if (!c.accessible || c.session.resourceKey != _resourceKey) {
        return const HistaeScaffold(body: SizedBox.shrink());
      }
      final preview = c.feedPreviewAt(DateTime.now().toUtc());
      return HistaeScaffold(
        appBar: AppBar(
          title: Text(
            AppStrings.of(context)
                .messages
                .profileFeedPreviewPageMyProfileInTheFeed,
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: c.load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.of(context)
                        .messages
                        .profileFeedPreviewPageThroughYourWords,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.of(context)
                        .messages
                        .profileFeedPreviewPageTheseAreThePartsOfYour,
                  ),
                  const SizedBox(height: 20),
                  if (c.loading)
                    LinearProgressIndicator(
                      semanticsLabel: AppStrings.of(context)
                          .messages
                          .profileFeedPreviewPageRefreshingYourPreview,
                    ),
                  if (preview == null)
                    Text(
                      AppStrings.of(context)
                          .messages
                          .profileFeedPreviewPageYourPreviewCannotBeShownReturn,
                    )
                  else
                    Card(
                      color: Colors.transparent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: HistaeTokens.panelGradient(context),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: FeedProfileContent(
                            firstname: preview.firstname,
                            age: preview.age,
                            bio: preview.bio,
                            distanceLabel: AppStrings.of(context)
                                .messages
                                .profileFeedPreviewPageDistanceDependsOnTheViewer,
                            traits: preview.traits,
                            answers: preview.answers,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
