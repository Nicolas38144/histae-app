import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../auth/domain/authenticated_session.dart';
import '../application/report_controller.dart';
import '../data/privacy_models.dart';
import '../data/privacy_repository.dart';
import 'privacy_choice.dart';
import 'privacy_strings.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({
    super.key,
    required this.session,
    required this.target,
    this.matchId,
    this.onBlock,
  });
  final AuthenticatedSession session;
  final String target;
  final String? matchId;
  final Future<void> Function()? onBlock;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late final c = ReportController(
    PrivacyRepository(widget.session),
    widget.target,
    matchId: widget.matchId,
  );
  final _text = TextEditingController();
  ReportReason _reason = ReportReason.inappropriateContent;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
  }

  void _changed() {
    if (!c.accessible || c.submitted) _text.clear();
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    c.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      if (!c.accessible) return const HistaeScaffold(body: SizedBox.shrink());
      final editable = !c.sending && c.pending == null && !c.submitted;
      return HistaeScaffold(
        appBar: AppBar(
          title: Text(AppStrings.of(context).messages.reportPageReportAProfile),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  EditorialCard(
                    eyebrow: AppStrings.of(context)
                        .messages
                        .reportPageCaringForConversations,
                    title: AppStrings.of(context)
                        .messages
                        .reportPageASpaceToFeelAtEase,
                    body: AppStrings.of(context)
                        .messages
                        .reportPageYourReportWillBeReviewedBlocking,
                  ),
                  const SizedBox(height: 24),
                  if (!c.submitted) ...[
                    PrivacyChoice<ReportReason>(
                      value: _reason,
                      label: AppStrings.of(context).messages.reportPageReason,
                      choices: {
                        for (final reason in ReportReason.values)
                          reason: reasonLabel(AppStrings.of(context), reason),
                      },
                      onChanged: editable
                          ? (value) => setState(() => _reason = value)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _text,
                      enabled: editable,
                      minLines: 3,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: AppStrings.of(context)
                            .messages
                            .reportPageDescriptionOptional,
                        alignLabelWithHint: true,
                        helperText: AppStrings.of(context)
                            .messages
                            .reportPageABriefAccountOfWhatHappened,
                      ),
                    ),
                    if (c.validation != null)
                      Text(AppStrings.of(context).clientMessage(c.validation!)),
                    if (c.pending != null)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          AppStrings.of(context)
                              .messages
                              .reportPageTheResponseIsUnconfirmedOnlyThis,
                        ),
                      ),
                    if (c.failure != null)
                      Text(privacyFailure(AppStrings.of(context), c.failure!)),
                    if (c.retrySeconds > 0)
                      Text(
                        AppStrings.of(context).messages
                            .appStringsTryAgainInS(c.retrySeconds),
                      ),
                    const SizedBox(height: 20),
                    HistaeButton(
                      onPressed: c.sending || c.retrySeconds > 0
                          ? null
                          : () => c.submit(_reason, _text.text),
                      child: Text(
                        c.sending
                            ? AppStrings.of(context).messages.chatPageSending
                            : c.pending != null
                            ? AppStrings.of(context)
                                  .messages
                                  .reportPageResumeThisReport
                            : AppStrings.of(context)
                                  .messages
                                  .reportPageSubmitReport,
                      ),
                    ),
                  ] else ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        c.alreadyPending
                            ? AppStrings.of(context)
                                  .messages
                                  .privacyStringsAReportAboutThisPersonIs
                            : AppStrings.of(context)
                                  .messages
                                  .reportPageYourReportWasReceivedThankYou,
                      ),
                    ),
                    if (widget.onBlock != null)
                      OutlinedButton(
                        onPressed: () async {
                          if (!await confirmAction(
                                context,
                                AppStrings.of(context)
                                    .messages
                                    .encounterPageBlockThisPerson,
                                AppStrings.of(context)
                                    .messages
                                    .reportPageConversationsWillEndPreviousMatchesWill,
                                action: AppStrings.of(context)
                                    .messages
                                    .discoveryPageBlock,
                              ) ||
                              !context.mounted ||
                              !c.accessible) {
                            return;
                          }
                          await widget.onBlock!();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: Text(
                          AppStrings.of(context)
                              .messages
                              .reportPageAlsoBlockThisPerson,
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        AppStrings.of(context).messages.conversationHeaderClose,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
