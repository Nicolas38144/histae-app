import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../privacy/presentation/privacy_hub_page.dart';
import '../domain/consent_state.dart';
import 'consent_strings.dart';

typedef DocumentOpener = Future<bool> Function(Uri url);

Future<bool> openLegalDocument(Uri url) async {
  if (url.scheme != 'https' || url.host.isEmpty || url.userInfo.isNotEmpty) {
    return false;
  }
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

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
      await widget.session.saveConsents(changes, {
        for (final consent in state.consents)
          consent.type: consent.requiredVersion,
      });
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
          FilledButton(
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
    return Scaffold(
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
                    .map((c) => '${c.type.name}:${c.requiredVersion}')
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
                    for (final consent in state.consents)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  strings.consentTitle(consent.type),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              TextButton(
                                onPressed: _busy ? null : () => _open(consent),
                                child: Text(
                                  strings.documentVersion(
                                    consent.requiredVersion,
                                  ),
                                ),
                              ),
                              if (consent.current) ...[
                                Text(strings.consentCurrent),
                              ] else
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  key: Key(consent.type.wireName),
                                  title: Text(
                                    strings.consentLabel(consent.type),
                                  ),
                                  value: _choices[consent.type] ?? false,
                                  onChanged: blocked
                                      ? null
                                      : (value) {
                                          // Declining an outdated sensitive/location grant also
                                          // withdraws it, so use the same explicit confirmation.
                                          if (value == false &&
                                              consent.granted &&
                                              consent.type.withdrawable) {
                                            _withdraw(consent, state);
                                            return;
                                          }
                                          setState(() {
                                            _choices[consent.type] =
                                                value ?? false;
                                          });
                                        },
                                ),
                              if (consent.granted && consent.type.withdrawable)
                                OutlinedButton(
                                  onPressed: blocked
                                      ? null
                                      : () => _withdraw(consent, state),
                                  child: Text(strings.withdraw),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (_message != null)
                      Semantics(liveRegion: true, child: Text(_message!)),
                    const SizedBox(height: 16),
                    FilledButton(
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
                    if (widget.onboarding)
                      OutlinedButton(
                        onPressed: blocked
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      PrivacyHubPage(session: widget.session),
                                ),
                              ),
                        child: const Text(
                          'Sessions, données et suppression du compte',
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
