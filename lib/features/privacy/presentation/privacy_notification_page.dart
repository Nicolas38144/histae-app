import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../auth/domain/authenticated_session.dart';
import '../application/privacy_controller.dart';
import '../data/privacy_repository.dart';
import '../data/private_export_store.dart';
import 'privacy_detail_page.dart';

/// Owns the private controller and cleanup for a notification destination.
class PrivacyNotificationPage extends StatefulWidget {
  const PrivacyNotificationPage({
    super.key,
    required this.session,
    required this.section,
    this.repository,
    this.requestId,
    this.exportStore,
  });

  final AuthenticatedSession session;
  final PrivacySection section;
  final PrivacyRepository? repository;
  final String? requestId;
  final PrivateExportStore? exportStore;

  @override
  State<PrivacyNotificationPage> createState() =>
      _PrivacyNotificationPageState();
}

class _PrivacyNotificationPageState extends State<PrivacyNotificationPage>
    with WidgetsBindingObserver {
  late final _controller = PrivacyController(
    widget.repository ?? PrivacyRepository(widget.session),
    exportStore: widget.exportStore,
  );
  late final Future<void> _startup;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startup = _controller.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.resume());
    } else {
      _controller.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _startup,
    builder: (context, state) => state.connectionState == ConnectionState.done
        ? PrivacyDetailPage(
            controller: _controller,
            section: widget.section,
            notificationFlow: true,
            initialRequestId: widget.requestId,
          )
        : HistaeScaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: AppStrings.of(context)
                    .messages
                    .privacyDetailPageOperationInProgress,
              ),
            ),
          ),
  );
}
