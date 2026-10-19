import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../../core/widgets/histae_wordmark.dart';
import '../../consents/presentation/consents_page.dart';
import '../../notifications/presentation/push_scope.dart';
import '../../privacy/presentation/report_page.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/presentation/profile_editors.dart';
import '../application/discovery_controller.dart';
import '../data/device_location.dart';
import '../data/discovery_models.dart';
import 'discovery_strings.dart';
import 'encounter_page.dart';
import 'feed_profile_card.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({
    super.key,
    required this.controller,
    required this.profile,
    this.openMatches,
  });
  final DiscoveryController controller;
  final ProfileController profile;
  final Future<void> Function([String? id])? openMatches;
  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage>
    with WidgetsBindingObserver {
  DiscoveryController get c => widget.controller;
  late final _key = c.session.resourceKey;
  String? _message;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(c.activate());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      c.deactivate();
    } else if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(_resume());
    }
  }

  Future<void> _resume() async {
    if (PushScope.maybeOf(context)?.coversMainFlow == true) return;
    await c.session.synchronize();
    if (mounted && c.session.resourceKey == _key) {
      if (c.active) {
        await c.refresh();
      } else {
        await c.activate();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.deactivate(notify: false);
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    c.deactivate();
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _resume();
  }

  Future<void> _repair(DiscoveryAction action) async {
    if (_opening || c.busy) return;
    if (action == DiscoveryAction.freshPresence) {
      await _locate();
      return;
    }
    _opening = true;
    try {
      if (action == DiscoveryAction.locationConsent ||
          action == DiscoveryAction.sensitiveConsent ||
          ((action == DiscoveryAction.sex ||
                  action == DiscoveryAction.preferences) &&
              !widget.profile.sensitiveAllowed)) {
        await _open(ConsentsPage(session: c.session));
        return;
      }
      final profile = widget.profile;
      await profile.load();
      if (!mounted || !c.accessible || c.session.resourceKey != _key) return;
      final section = action == DiscoveryAction.preferences
          ? 'preferences'
          : 'profile';
      if (profile.loading ||
          profile.errors.containsKey(section) ||
          profile.uncertain) {
        setState(() {
          _message = 'Votre profil n’a pas pu être relu. Revenez à votre espace personnel pour le reprendre.';
        });
        return;
      }
      await _open(
        action == DiscoveryAction.preferences
            ? PreferencesEditor(controller: profile)
            : IdentityEditor(controller: profile),
      );
    } finally {
      _opening = false;
    }
  }

  Future<void> _locate() async {
    if (!c.locationConsent) {
      await _open(ConsentsPage(session: c.session));
      return;
    }
    if (!await confirmAction(
          context,
          'Utiliser votre position ?',
          'Histae utilisera une mesure ponctuelle pour les rencontres à proximité. Aucun suivi en arrière-plan. Votre position exacte ne sera pas montrée aux autres personnes.',
          action: 'Localiser cet appareil',
        ) ||
        !mounted) {
      return;
    }
    await c.publishLocation();
  }

  Future<void> _showEncounter(EncounterReceipt receipt) async {
    if (!mounted || !c.accessible || c.session.resourceKey != _key) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EncounterPage(
          controller: c,
          receipt: receipt,
          openMatch: widget.openMatches == null
              ? null
              : () => widget.openMatches!(receipt.match.id),
        ),
      ),
    );
    if (mounted) await _resume();
  }

  Future<void> _choose(SwipeDecision decision) async {
    final receipt = await c.decide(decision);
    if (receipt != null) await _showEncounter(receipt);
  }

  Future<void> _retry() async {
    final receipt = await c.resumeChoice();
    if (receipt != null) await _showEncounter(receipt);
  }

  Future<void> _block() async {
    final profile = c.current;
    if (profile == null || c.busy) return;
    if (!await confirmAction(
          context,
          'Bloquer ce profil ?',
          'Vous ne pourrez plus vous découvrir ni échanger. Toute rencontre déjà créée avec cette personne sera terminée.',
          action: 'Bloquer',
        ) ||
        !mounted) {
      return;
    }
    await c.blockProfile(profile);
  }

  Future<void> _report() async {
    final profile = c.current;
    if (profile == null || c.busy) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportPage(
          session: c.session,
          target: profile.id,
          onBlock: () async {
            if (!c.active) await c.activate();
            await c.blockProfile(profile);
          },
        ),
      ),
    );
    if (mounted) await _resume();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      if (!c.accessible || c.session.resourceKey != _key) {
        return const HistaeScaffold(body: SizedBox.shrink());
      }
      final profile = c.current;
      final required = c.status?.requiredActions ?? const <DiscoveryAction>[];
      final showFeed =
          c.ready &&
          !c.locating &&
          c.locationIssue == null &&
          profile != null &&
          c.pending == null &&
          c.failure == null;
      final enabled = !c.busy && c.retrySeconds == 0;
      final statusBody = <Widget>[
        if (!c.ready && c.status != null) ...[
          const EditorialCard(
            eyebrow: 'AVANT LA RENCONTRE',
            title: 'Un peu de vous.\nPuis les autres.',
            body: 'Complétez ces étapes à votre rythme. Vos choix de vie privée restent accessibles.',
          ),
          for (final action in required)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      DiscoveryStrings.actionTitle(action),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(DiscoveryStrings.actionBody(action)),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: enabled && !_opening
                          ? () => _repair(action)
                          : null,
                      child: Text(
                        action == DiscoveryAction.freshPresence
                            ? 'Actualiser ma position'
                            : 'Compléter cette étape',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (c.ready && profile == null && !c.loading && c.failure == null)
          EditorialCard(
            eyebrow: 'PRENDRE LE TEMPS',
            title: c.exhausted
                ? 'Le calme,\npour le moment.'
                : 'Encore un instant.',
            body: c.exhausted
                ? 'Vous avez découvert les profils disponibles selon vos préférences. Revenez plus tard ou ajustez vos envies de rencontre.'
                : 'La recherche peut se poursuivre. Chargez la suite lorsque vous le souhaitez.',
          ),
        if (c.pending case final intent?)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Votre choix pour ${intent.profile.firstname}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    c.uncertain
                        ? 'La réponse n’est pas confirmée. Votre choix reste en mémoire ; seul le même choix sera renvoyé.'
                        : 'Votre demande attend sa confirmation. Aucun autre choix ne sera envoyé pour ce profil.',
                  ),
                  const SizedBox(height: 20),
                  HistaeButton(
                    onPressed: c.canResume ? _retry : null,
                    child: Text(DiscoveryStrings.pending(intent.action)),
                  ),
                ],
              ),
            ),
          ),
        if (c.loading || c.locating || c.sending) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(
            semanticsLabel: 'Chargement de la découverte',
          ),
          const SizedBox(height: 12),
          Text(
            c.locating
                ? 'Recherche d’une position récente…'
                : c.sending
                ? 'Enregistrement de votre choix…'
                : 'Préparation des rencontres…',
          ),
        ],
        if (c.notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(DiscoveryStrings.notice(c.notice)),
            ),
          ),
        if (c.failure case final failure?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(DiscoveryStrings.failure(failure)),
            ),
          ),
        if (c.locationIssue case final issue?) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(DiscoveryStrings.location(issue)),
          ),
          if (issue == LocationIssue.deniedForever ||
              issue == LocationIssue.disabled)
            OutlinedButton(
              onPressed: enabled
                  ? () async {
                      final opened = await c.location.openSettings(
                        services: issue == LocationIssue.disabled,
                      );
                      if (!opened && mounted) {
                        setState(() {
                          _message = 'Ouvrez les réglages de localisation de votre appareil, puis revenez dans Histae.';
                        });
                      }
                    }
                  : null,
              child: const Text('Ouvrir les réglages'),
            ),
        ],
        if (_message != null) Text(_message!),
        if (c.retrySeconds > 0)
          Text('Nouvel essai possible dans ${c.retrySeconds} s'),
        if (!showFeed)
          OutlinedButton(
            onPressed: enabled
                ? (c.ready &&
                          !c.exhausted &&
                          c.pending == null &&
                          c.failure == null
                      ? c.loadMore
                      : c.refresh)
                : null,
            child: const Text('Actualiser les rencontres'),
          ),
        if (c.ready && !showFeed)
          TextButton(
            onPressed: enabled ? _locate : null,
            child: const Text('Actualiser ma position'),
          ),
        if (c.encounter case final encounter?)
          TextButton.icon(
            onPressed: !c.busy ? () => _showEncounter(encounter) : null,
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text('Votre rencontre avec ${encounter.profile.firstname}'),
          ),
        TextButton(
          onPressed: () => _open(ConsentsPage(session: c.session)),
          child: const Text('Vos choix et votre vie privée'),
        ),
        TextButton(
          onPressed: c.session.logout,
          child: const Text('Se déconnecter'),
        ),
      ];
      return HistaeScaffold(
        appBar: AppBar(
          title: const HistaeWordmark(),
          actions: [
            IconButton(
              tooltip: 'Vos préférences',
              onPressed: enabled
                  ? () => _repair(DiscoveryAction.preferences)
                  : null,
              icon: const Icon(Icons.tune),
            ),
            PopupMenuButton<String>(
              tooltip: 'Options de découverte',
              onSelected: (value) {
                if (value == 'refresh') unawaited(c.refresh());
                if (value == 'location') unawaited(_locate());
                if (value == 'block') unawaited(_block());
                if (value == 'report') unawaited(_report());
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'refresh',
                  enabled: enabled,
                  child: const Text('Actualiser les profils'),
                ),
                PopupMenuItem(
                  value: 'location',
                  enabled: enabled,
                  child: const Text('Actualiser ma position'),
                ),
                if (profile != null)
                  PopupMenuItem(
                    value: 'report',
                    enabled: enabled,
                    child: const Text('Signaler ce profil'),
                  ),
                if (profile != null)
                  PopupMenuItem(
                    value: 'block',
                    enabled: enabled,
                    child: const Text('Bloquer ce profil'),
                  ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: showFeed
              ? Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: FeedProfileCard(
                          key: ValueKey(profile.id),
                          profile: profile,
                          enabled: c.canChoose,
                          onLike: () => _choose(SwipeDecision.like),
                          onPass: () => _choose(SwipeDecision.pass),
                        ),
                      ),
                    ),
                    if (c.notice != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            DiscoveryStrings.notice(c.notice),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_message!),
                        ),
                      ),
                    if (c.encounter case final encounter?)
                      TextButton(
                        onPressed: () => _showEncounter(encounter),
                        child: Text(
                          'Votre rencontre avec ${encounter.profile.firstname}',
                        ),
                      ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: statusBody,
                ),
        ),
      );
    },
  );
}
