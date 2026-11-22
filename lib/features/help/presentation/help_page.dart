import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/histae_tokens.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../auth/domain/authenticated_session.dart';
import 'casework_page.dart';
import 'feed_guide.dart';
import 'help_scope.dart';
import 'linked_help_answer.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key, this.session});

  final AuthenticatedSession? session;

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
      /* Report the launch failure in the contact section. */
    }
    if (mounted) {
      setState(() {
        _launching = false;
        _failed = !opened;
      });
    }
  }

  Future<void> _openCasework(
    AuthenticatedSession session,
    CaseworkView view,
  ) async {
    if (!session.hasSession) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CaseworkPage(view: view, session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(context).messages;
    final headingStyle = Theme.of(context).textTheme.titleLarge;
    final support = HelpScope.maybeOf(context)?.support;
    final email = support?.email;
    final standards = support?.websiteOrigin?.resolve(
      '/${AppStrings.of(context).localeName}/child-safety/',
    );
    return HistaeScaffold(
      appBar: AppBar(title: Text(text.helpTitle)),
      body: SafeArea(
        child: ListView(
          padding: HistaeTokens.pagePadding,
          children: [
            Text(text.helpIntro, style: headingStyle),
            const SizedBox(height: 20),
            HistaeButton.outlinedIcon(
              key: const Key('help-feed-guide'),
              onPressed: () => showFeedGuide(context),
              icon: const Icon(Icons.swipe_outlined),
              label: Text(text.helpReviewGuide),
            ),
            const SizedBox(height: 20),
            for (final entry in [
              (text.helpFeedQuestion, text.helpFeedAnswer, false),
              (text.helpPhotoQuestion, text.helpPhotoAnswer, false),
              (text.matchesInactivityInfo, text.matchesInactivityPolicy, false),
              (text.helpCreditsQuestion, text.helpCreditsAnswer, false),
              (text.helpPurchasesQuestion, text.helpPurchasesAnswer, false),
              (text.helpRestoreQuestion, text.helpRestoreAnswer, false),
              (text.helpDraftsQuestion, text.helpDraftsAnswer, false),
              (text.helpSafetyQuestion, text.helpSafetyAnswer, false),
              (text.helpChildSafetyQuestion, text.helpChildSafetyAnswer, true),
            ])
              Card(
                child: ExpansionTile(
                  key: entry.$3 ? const Key('help-child-safety') : null,
                  title: Text(entry.$1),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: entry.$3 && standards != null
                          ? LinkedHelpAnswer(
                              key: const Key('help-child-safety-standards'),
                              body: entry.$2,
                              linkLabel: text.helpChildSafetyStandards,
                              onOpenLink: _launching
                                  ? null
                                  : () => _openStandards(standards),
                            )
                          : Text(entry.$2),
                    ),
                    if (entry.$3 && _linkFailed) Text(text.helpLinkFailed),
                  ],
                ),
              ),
            const SizedBox(height: HistaeTokens.sectionSpacing),
            Text(text.helpContactTitle, style: headingStyle),
            const SizedBox(height: HistaeTokens.textSpacing),
            if (widget.session case final session? when session.hasSession) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.support_agent),
                trailing: const Icon(Icons.chevron_right_rounded),
                title: Text(text.caseworkSupport),
                onTap: () => _openCasework(session, CaseworkView.support),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                trailing: const Icon(Icons.chevron_right_rounded),
                title: Text(text.caseworkReports),
                onTap: () => _openCasework(session, CaseworkView.reports),
              ),
            ],
            const SizedBox(height: HistaeTokens.labelSpacing),
            if (email == null)
              Text(text.helpEmailComingSoon)
            else ...[
              if (_failed)
                Semantics(liveRegion: true, child: Text(text.helpEmailFailed)),
              HistaeButton.icon(
                onPressed: _launching ? null : () => _contact(email),
                icon: const Icon(Icons.mail_outline),
                label: Text(text.helpContactButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
