import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import 'feed_guide.dart';
import 'help_scope.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  bool _launching = false, _failed = false, _linkFailed = false;

  Future<void> _openStandards(Uri uri) async {
    if (_launching) return;
    setState(() {
      _launching = true;
      _linkFailed = false;
    });
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      /* Keep the in-app safety guidance available. */
    }
    if (mounted) {
      setState(() {
        _launching = false;
        _linkFailed = !opened;
      });
    }
  }

  Future<void> _contact(String email) async {
    if (_launching) return;
    setState(() {
      _launching = true;
      _failed = false;
    });
    final subject = AppStrings.of(context).messages.helpEmailSubject;
    var opened = false;
    try {
      opened = await launchUrl(
        Uri(
          scheme: 'mailto',
          path: email,
          query: 'subject=${Uri.encodeComponent(subject)}',
        ),
      );
    } catch (_) {
      /* Keep the address visible for manual use. */
    }
    if (mounted) {
      setState(() {
        _launching = false;
        _failed = !opened;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).messages;
    final support = HelpScope.maybeOf(context)?.support;
    final email = support?.email;
    final standards = support?.websiteOrigin?.resolve(
      '/${AppStrings.of(context).localeName}/child-safety/',
    );
    return HistaeScaffold(
      appBar: AppBar(title: Text(text.helpTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(text.helpIntro, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            HistaeButton.outlinedIcon(
              key: const Key('help-feed-guide'),
              onPressed: () => showFeedGuide(context),
              icon: const Icon(Icons.swipe_outlined),
              label: Text(text.helpReviewGuide),
            ),
            const SizedBox(height: 20),
            for (final entry in [
              (text.helpFeedQuestion, text.helpFeedAnswer),
              (text.helpPhotoQuestion, text.helpPhotoAnswer),
              (text.matchesInactivityInfo, text.matchesInactivityPolicy),
              (text.helpCreditsQuestion, text.helpCreditsAnswer),
              (text.helpPurchasesQuestion, text.helpPurchasesAnswer),
              (text.helpRestoreQuestion, text.helpRestoreAnswer),
              (text.helpDraftsQuestion, text.helpDraftsAnswer),
              (text.helpSafetyQuestion, text.helpSafetyAnswer),
              (text.helpChildSafetyQuestion, text.helpChildSafetyAnswer),
            ])
              Card(
                child: ExpansionTile(
                  title: Text(entry.$1),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(entry.$2),
                    ),
                  ],
                ),
              ),
            if (standards != null) ...[
              const SizedBox(height: 20),
              HistaeButton.outlinedIcon(
                key: const Key('help-child-safety-standards'),
                onPressed: _launching ? null : () => _openStandards(standards),
                icon: const Icon(Icons.policy_outlined),
                label: Text(text.helpChildSafetyStandards),
              ),
            ],
            if (_linkFailed) Text(text.helpLinkFailed),
            const SizedBox(height: 24),
            Text(
              text.helpContactTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (email == null)
              Text(text.helpEmailComingSoon)
            else ...[
              SelectableText(email),
              const SizedBox(height: 12),
              HistaeButton.icon(
                onPressed: _launching ? null : () => _contact(email),
                icon: const Icon(Icons.mail_outline),
                label: Text(text.helpContactButton),
              ),
            ],
            if (_failed) Text(text.helpEmailFailed),
          ],
        ),
      ),
    );
  }
}
