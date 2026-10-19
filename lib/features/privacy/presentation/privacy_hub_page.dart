import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../consents/presentation/consents_page.dart';
import '../../continuation/presentation/rewarded_video_scope.dart';
import '../../notifications/presentation/devices_page.dart';
import '../../notifications/presentation/push_scope.dart';
import '../application/privacy_controller.dart';
import '../data/privacy_repository.dart';
import '../data/private_export_store.dart';
import 'privacy_detail_page.dart';
import 'privacy_frame.dart';

export 'privacy_detail_page.dart' show PrivacyDetailPage;

class PrivacyHubPage extends StatefulWidget {
  const PrivacyHubPage({super.key, required this.session, this.exportStore});
  final AuthenticatedSession session;
  final PrivateExportStore? exportStore;
  @override
  State<PrivacyHubPage> createState() => _PrivacyHubPageState();
}

class _PrivacyHubPageState extends State<PrivacyHubPage>
    with WidgetsBindingObserver {
  late final c = PrivacyController(
    PrivacyRepository(widget.session),
    exportStore: widget.exportStore,
  );
  late final Future<void> _startup;
  bool _advertisingFormOpen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startup = c.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_advertisingFormOpen) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(c.resume());
    } else {
      c.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  Future<void> _open(PrivacySection section) async {
    await _startup;
    if (!mounted || !c.accessible) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrivacyDetailPage(controller: c, section: section),
      ),
    );
    if (mounted) {
      c.leave(section);
    }
  }

  Future<void> _advertisingChoices() async {
    if (_advertisingFormOpen) return;
    final gateway = RewardedVideoScope.maybeOf(context);
    if (gateway?.privacyOptionsRequired != true) return;
    setState(() => _advertisingFormOpen = true);
    try {
      await gateway!.showPrivacyOptions();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vos préférences publicitaires ne sont pas accessibles pour le moment.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _advertisingFormOpen = false);
        unawaited(c.resume());
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      if (!c.accessible) return const HistaeScaffold(body: SizedBox.shrink());
      return PrivacyFrame(
        title: 'Vie privée et sécurité',
        children: [
          const EditorialCard(
            eyebrow: 'VOTRE ESPACE, VOS CHOIX',
            title: 'En toute\nconfiance.',
            body: 'Retrouvez vos choix, vos accès et vos données. Ces démarches restent disponibles avant la fin de votre inscription.',
          ),
          const SizedBox(height: 24),
          _tile(
            Icons.tune,
            'Mes consentements',
            'Consulter ou modifier mes choix',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ConsentsPage(session: widget.session),
              ),
            ),
          ),
          _tile(
            Icons.devices,
            'Mes sessions',
            'Consulter et révoquer les accès',
            () => _open(PrivacySection.sessions),
          ),
          if (RewardedVideoScope.maybeOf(context)?.privacyOptionsRequired ==
              true)
            _tile(
              Icons.tune_rounded,
              'Mes choix publicitaires',
              'Revoir mes préférences pour les vidéos',
              _advertisingChoices,
            ),
          if (c.onboarded)
            _tile(
              Icons.notifications_none,
              'Appareils et notifications',
              'Choisir les alertes et gérer les appareils',
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DevicesPage(
                    session: widget.session,
                    push: PushScope.maybeOf(context),
                  ),
                ),
              ),
            ),
          if (c.onboarded)
            _tile(
              Icons.person_off_outlined,
              'Personnes bloquées',
              'Gérer les blocages',
              () => _open(PrivacySection.blocks),
            ),
          _tile(
            Icons.fact_check_outlined,
            'Mes demandes de données',
            'Exercer mes droits et suivre mes demandes',
            () => _open(PrivacySection.rights),
          ),
          _tile(
            Icons.download_outlined,
            'Exporter mes données',
            'Télécharger puis choisir un partage',
            () => _open(PrivacySection.export),
          ),
          _tile(
            Icons.delete_outline,
            'Supprimer mon compte',
            'Fermer mon compte et demander son nettoyage',
            () => _open(PrivacySection.deletion),
          ),
          TextButton(
            onPressed: widget.session.logout,
            child: const Text('Se déconnecter'),
          ),
        ],
      );
    },
  );
  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action,
  ) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: action,
    ),
  );
}
