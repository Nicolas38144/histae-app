import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../privacy/presentation/privacy_hub_page.dart';
import '../data/legal_document_opener.dart';
import '../domain/consent_state.dart';
import 'consent_control.dart';
import 'consent_strings.dart';

export '../data/legal_document_opener.dart'
    show DocumentOpener, openLegalDocument;

class ConsentsPage extends StatefulWidget {
  const ConsentsPage({
    super.key,
    required this.session,
    this.openDocument = openLegalDocument,
    this.onboarding = false,
  });
  final AuthenticatedSession session;
  final DocumentOpener openDocument;
  final bool onboarding;

  @override
  State<ConsentsPage> createState() => _ConsentsPageState();
}

class _ConsentsPageState extends State<ConsentsPage> {
  final _choices = <ConsentType, bool>{};
  String? _versionSignature;
  String? _message;
  bool _busy = false;

  Future<void> _save(Map<ConsentType, bool> changes, ConsentState state) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.session.saveConsents(
        changes,
        {
          for (final consent in state.consents)
            consent.type: consent.requiredVersion,
        },
        displayedDocuments: {
          for (final consent in state.consents) consent.type: consent,
        },
      );
      if (mounted) {
        setState(() {
          _choices.clear();
          _message = AppStrings.of(context).choicesSaved;
        });
      }
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() {
          _message = AppStrings.of(context).authFailure(error);
          if (error.code == 'legal_documents_changed') _choices.clear();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _withdraw(PublicConsent consent, ConsentState state) async {
    final strings = AppStrings.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.withdraw),
        content: Text(strings.withdrawalMessage(consent.type)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          HistaeButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.confirmWithdrawal),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) await _save({consent.type: false}, state);
  }

  Future<void> _open(PublicConsent consent) async {
    final url = Uri.tryParse(consent.documentUrl);
    final opened =
        url != null &&
        url.scheme == 'https' &&
        url.userInfo.isEmpty &&
        await widget.openDocument(url);
    if (!opened && mounted) {
      setState(() {
        _message = AppStrings.of(context).openDocumentError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return HistaeScaffold(
      appBar: AppBar(title: Text(strings.consentsTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListenableBuilder(
              listenable: widget.session,
              builder: (context, _) {
                final state = widget.session.consents;
                if (state == null) return const SizedBox.shrink();
                final signature = state.consents
                    .map(
                      (c) =>
                          '${c.type.name}:${c.requiredVersion}:${c.documentLanguage.code}:${c.documentUrl}',
                    )
                    .join('|');
                if (_versionSignature != signature) {
                  _versionSignature = signature;
                  _choices.clear();
                }
                final changes = Map<ConsentType, bool>.fromEntries(
                  _choices.entries.where((e) => e.value || e.key.withdrawable),
                );
                final blocked =
                    _busy ||
                    widget.session.isSynchronizing ||
                    widget.session.retrySeconds > 0;
                final managing =
                    !widget.onboarding &&
                    state.onboardingComplete &&
                    state.requiredActions.isEmpty;
                final displayed = managing
                    ? [
                        ...state.consents.where((c) => c.type.withdrawable),
                        ...state.consents.where((c) => !c.type.withdrawable),
                      ]
                    : state.consents;
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        strings.trustHeading,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const EditorialDivider(),
                    Text(strings.consentsIntro),
                    const SizedBox(height: 12),
                    if (widget.onboarding) Text(strings.onboardingRequired),
                    for (final consent in displayed) ...[
                      if (managing &&
                          (consent.type == ConsentType.sensitive ||
                              consent.type == ConsentType.terms))
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 12),
                          child: Text(
                            consent.type.withdrawable
                                ? AppStrings.of(context)
                                      .messages
                                      .consentsPageYourOptionalConsents
                                : AppStrings.of(context)
                                      .messages
                                      .consentsPageYourRequiredDocuments,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ConsentControl(
                                consent: consent,
                                onOpen: _busy ? null : () => _open(consent),
                                value:
                                    _choices[consent.type] ?? consent.current,
                                onChanged:
                                    blocked ||
                                        (consent.current &&
                                            !consent.type.withdrawable)
                                    ? null
                                    : (value) {
                                        if (!value &&
                                            consent.granted &&
                                            consent.type.withdrawable) {
                                          _withdraw(consent, state);
                                        } else if (managing &&
                                            consent.type.withdrawable) {
                                          _save({consent.type: value}, state);
                                        } else {
                                          setState(() {
                                            _choices[consent.type] = value;
                                          });
                                        }
                                      },
                              ),
                              // An old grant is still withdrawable, but must never
                              // preselect acceptance of the replacement document.
                              if (consent.granted &&
                                  !consent.current &&
                                  consent.type.withdrawable)
                                TextButton(
                                  key: Key('withdraw-${consent.type.wireName}'),
                                  onPressed: blocked
                                      ? null
                                      : () => _withdraw(consent, state),
                                  child: Text(
                                    AppStrings.of(context)
                                        .messages
                                        .consentsPageWithdrawMyPreviousConsent,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_message != null)
                      Semantics(liveRegion: true, child: Text(_message!)),
                    const SizedBox(height: 16),
                    if (!managing)
                      HistaeButton(
                        onPressed: blocked || changes.isEmpty
                            ? null
                            : () => _save(changes, state),
                        child: Text(
                          widget.session.retrySeconds > 0
                              ? strings.retryIn(widget.session.retrySeconds)
                              : strings.saveChoices,
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: blocked ? null : widget.session.synchronize,
                      child: Text(strings.refreshChoices),
                    ),
                    const SizedBox(height: 20),
                    Text(strings.privacyScope),
                    OutlinedButton(
                      onPressed: blocked
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    PrivacyHubPage(session: widget.session),
                              ),
                            ),
                      child: Text(
                        AppStrings.of(context)
                            .messages
                            .consentsPageSessionsDataAndAccountDeletion,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.session.logout,
                      child: Text(strings.logout),
                    ),
                    if (_busy || widget.session.isSynchronizing)
                      LinearProgressIndicator(
                        semanticsLabel: strings.actionInProgress,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
