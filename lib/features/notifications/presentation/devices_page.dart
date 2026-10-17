import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../auth/domain/authenticated_session.dart';
import '../../privacy/presentation/privacy_strings.dart' show privacyDate;
import '../application/devices_controller.dart';
import '../application/push_controller.dart';
import '../data/device_repository.dart';
import '../data/push_gateway.dart';

String notificationFailure(ApiFailure e) => switch (e.kind) {
  ApiFailureKind.secureStorage => 'Les réglages sécurisés ne sont pas accessibles. L’activation reste en attente.',
  ApiFailureKind.rateLimited =>
    'Trop de demandes. Patientez avant de réessayer.',
  _ => 'La réponse n’a pas été confirmée. Actualisez la liste avant de reprendre la même action.',
};

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.session, this.push});
  final AuthenticatedSession session;
  final PushController? push;
  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> with WidgetsBindingObserver {
  late final c = DevicesController(DeviceRepository(widget.session));
  PushController? get p => widget.push;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(c.load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(c.resume());
    } else if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      c.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, ?p]),
    builder: (context, _) {
      if (!c.accessible) return const Scaffold(body: SizedBox.shrink());
      final enabled =
          c.active &&
          !c.loading &&
          !c.removing &&
          c.retrySeconds == 0 &&
          p?.busy != true;
      return Scaffold(
        appBar: AppBar(title: const Text('Appareils et notifications')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const EditorialCard(
                    eyebrow: 'GARDER LE LIEN, À VOTRE RYTHME',
                    title: 'Un signe,\nsi vous le souhaitez.',
                    body: 'Choisissez de recevoir des notifications sur cet appareil. Les alertes Histae ne contiennent pas le texte privé de vos messages.',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sur cet appareil',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (p?.configured != true)
                    const Text(
                      'Les notifications push sont désactivées dans cette version, en attendant leur configuration. Vous pouvez gérer les appareils déjà enregistrés ci-dessous.',
                    )
                  else ...[
                    Text(
                      p!.stopping
                          ? 'L’arrêt des notifications reste à confirmer.'
                          : p!.pending != null ||
                                (p!.enabled && p!.deviceId == null)
                          ? 'L’enregistrement de cet appareil reste à confirmer.'
                          : p!.enabled
                          ? 'Cet appareil est enregistré pour les notifications. Leur réception dépend du système et du service.'
                          : 'Notifications non activées pour cet appareil.',
                    ),
                    if (p!.permission == PushPermission.provisional)
                      const Text(
                        'Les notifications sont autorisées discrètement par le système.',
                      ),
                    if (p!.notice == 'permission_denied')
                      const Text(
                        'Le système n’a pas autorisé les notifications. Vous pourrez modifier cette permission dans les réglages de l’appareil.',
                      ),
                    if (p!.notice == 'removed_elsewhere')
                      const Text(
                        'Cet appareil a été retiré de votre compte. Il ne sera pas réenregistré automatiquement.',
                      ),
                    if (p!.failure != null)
                      Text(notificationFailure(p!.failure!)),
                    if (p!.retrySeconds > 0)
                      Text('Nouvel essai possible dans ${p!.retrySeconds} s'),
                    if ((!p!.enabled ||
                            p!.pending != null ||
                            p!.deviceId == null ||
                            p!.failure != null) &&
                        !p!.stopping)
                      FilledButton(
                        onPressed: enabled && p!.retrySeconds == 0
                            ? () async {
                                if (!await confirmAction(
                                      context,
                                      'Recevoir des notifications ?',
                                      'Histae demandera l’autorisation du système puis enregistrera cet appareil auprès du service de notification. Vous pourrez le retirer ici.',
                                      action: p!.pending == null
                                          ? 'Continuer'
                                          : 'Reprendre cet enregistrement',
                                    ) ||
                                    !mounted) {
                                  return;
                                }
                                await p!.enable();
                                if (mounted) await c.load();
                              }
                            : null,
                        child: Text(
                          p!.pending == null
                              ? 'Activer les notifications'
                              : 'Reprendre cet enregistrement',
                        ),
                      ),
                    if (p!.enabled || p!.deviceId != null || p!.stopping)
                      OutlinedButton(
                        onPressed: enabled
                            ? () async {
                                if (await confirmAction(
                                      context,
                                      'Arrêter les notifications ici ?',
                                      'Cet appareil sera retiré du service de notification. Votre session de connexion reste ouverte.',
                                      action: 'Arrêter',
                                    ) &&
                                    mounted) {
                                  await p!.disable();
                                  if (mounted) await c.load();
                                }
                              }
                            : null,
                        child: const Text(
                          'Arrêter les notifications sur cet appareil',
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Vos appareils enregistrés',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text(
                    'Cette liste concerne les notifications. Retirer un appareil ne ferme pas sa session de connexion ; les sessions se gèrent séparément.',
                  ),
                  if (c.loading || c.removing || p?.busy == true)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: LinearProgressIndicator(
                        semanticsLabel: 'Actualisation des appareils',
                      ),
                    ),
                  if (c.failure != null) Text(notificationFailure(c.failure!)),
                  if (c.retrySeconds > 0)
                    Text('Nouvel essai possible dans ${c.retrySeconds} s'),
                  if (c.notice == 'device_removed')
                    const Text(
                      'Cet enregistrement a été retiré de votre compte.',
                    ),
                  if (c.pendingRemoval != null)
                    const Text(
                      'Un retrait reste à confirmer. Actualisez la liste, puis reprenez le même appareil s’il est encore présent.',
                    ),
                  if (!c.loading && c.failure == null && c.devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Aucun appareil enregistré pour les notifications.',
                      ),
                    ),
                  for (final device in c.devices)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${device.platform == 'ios' ? 'iOS' : 'Android'}${p?.deviceId == device.id ? ' · cet appareil' : ''}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (device.version != null)
                              Text('Version ${device.version}'),
                            Text(
                              'Enregistré le ${privacyDate(device.createdAt)}',
                            ),
                            if (device.lastUsedAt != null)
                              Text(
                                'Dernière actualisation le ${privacyDate(device.lastUsedAt!)}',
                              ),
                            OutlinedButton(
                              onPressed:
                                  enabled &&
                                      (c.pendingRemoval == null ||
                                          c.pendingRemoval == device.id)
                                  ? () async {
                                      if (!await confirmAction(
                                            context,
                                            'Retirer cet appareil ?',
                                            'Les futures notifications ne seront plus envoyées à cet enregistrement. Sa session de connexion restera ouverte.',
                                            action: 'Retirer',
                                          ) ||
                                          !mounted) {
                                        return;
                                      }
                                      final removed = await c.remove(device.id);
                                      if (removed && mounted) {
                                        await p?.removed(device.id);
                                      }
                                    }
                                  : null,
                              child: Text(
                                c.pendingRemoval == device.id
                                    ? 'Reprendre ce retrait'
                                    : 'Retirer cet appareil',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  OutlinedButton(
                    onPressed: enabled ? c.load : null,
                    child: const Text('Actualiser les appareils'),
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
