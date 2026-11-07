import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/signed_photo_loader.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../discovery/presentation/feed_profile_content.dart';
import '../application/profile_controller.dart';
import 'profile_owner_photo.dart';

class ProfileFeedPreviewPage extends StatefulWidget {
  const ProfileFeedPreviewPage({
    super.key,
    required this.controller,
    this.photoClient,
  });
  final ProfileController controller;
  final PhotoClientFactory? photoClient;

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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: HistaeTokens.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.of(context)
                      .messages
                      .profileFeedPreviewPageThroughYourWords,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: HistaeTokens.contentSpacing),
                if (preview != null && c.profile?.photo != null) ...[
                  ProfileOwnerPhoto(
                    controller: c,
                    photoClient: widget.photoClient,
                  ),
                  const SizedBox(height: HistaeTokens.contentSpacing),
                ],
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
                const SizedBox(height: HistaeTokens.contentSpacing),
                Text(
                  AppStrings.of(context)
                      .messages
                      .profileFeedPreviewPageTheseAreThePartsOfYour,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
