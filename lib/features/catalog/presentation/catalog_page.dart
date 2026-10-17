import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/editorial_card.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../../../core/widgets/status_view.dart';
import '../application/catalog_controller.dart';
import '../data/catalog_repository.dart';
import 'plan_card.dart';

export 'plan_card.dart' show PlanCard;

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.repository});
  final CatalogRepository? repository;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> with WidgetsBindingObserver {
  CatalogController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.repository case final repository?) {
      _controller = CatalogController(repository);
      unawaited(_controller!.load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _controller?.suspend();
    } else if (state == AppLifecycleState.resumed &&
        _controller?.status == CatalogStatus.idle) {
      unawaited(_controller!.load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return HistaeScaffold(
      appBar: AppBar(title: Text(strings.catalogTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _controller == null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      StatusView(
                        title: strings.configurationTitle,
                        message: strings.configurationBody,
                      ),
                    ],
                  )
                : ListenableBuilder(
                    listenable: _controller!,
                    builder: (context, _) => _content(context, _controller!),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, CatalogController controller) {
    final strings = AppStrings.of(context);
    final Widget body = switch (controller.status) {
      CatalogStatus.idle || CatalogStatus.loading => Column(
        children: [
          CircularProgressIndicator(semanticsLabel: strings.loading),
          const SizedBox(height: 20),
          Text(strings.loading),
        ],
      ),
      CatalogStatus.empty => StatusView(
        title: strings.emptyTitle,
        message: strings.emptyBody,
        action: OutlinedButton(
          onPressed: controller.load,
          child: Text(strings.refresh),
        ),
      ),
      CatalogStatus.failure => _failure(context, controller),
      CatalogStatus.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialCard(
            eyebrow: 'DES FORMULES SIMPLES',
            title: 'À votre rythme. Au prix juste.',
            body: strings.catalogIntro,
          ),
          const SizedBox(height: 16),
          for (final plan in controller.plans) PlanCard(plan: plan),
          const SizedBox(height: 16),
          Text(strings.catalogReadOnly),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: controller.load,
            child: Text(strings.refresh),
          ),
        ],
      ),
    };
    return ListView(padding: const EdgeInsets.all(24), children: [body]);
  }

  Widget _failure(BuildContext context, CatalogController controller) {
    final strings = AppStrings.of(context);
    final failure = controller.failure!;
    final network = failure.kind == ApiFailureKind.network;
    final seconds = controller.retrySeconds;
    return StatusView(
      title: network ? strings.offlineTitle : strings.errorTitle,
      message: strings.failureMessage(failure.kind),
      icon: network ? Icons.wifi_off_outlined : Icons.error_outline,
      reference: failure.requestId == null
          ? null
          : strings.requestReference(failure.requestId!),
      action: OutlinedButton(
        onPressed: seconds > 0 ? null : controller.load,
        child: Text(seconds > 0 ? strings.retryIn(seconds) : strings.retry),
      ),
    );
  }
}
