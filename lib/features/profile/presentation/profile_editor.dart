import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../application/profile_controller.dart';
import 'profile_strings.dart';

abstract class ProfileEditorState<T extends StatefulWidget> extends State<T> {
  ProfileController get controller;
  bool dirty = false, busy = false, leaving = false;
  String? message;
  late final String _resourceKey = controller.session.resourceKey;
  void changed() {
    dirty = true;
  }

  Future<void> submit(Future<void> Function() action) async {
    if (busy || !controller.canWrite) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() {
          dirty = false;
          leaving = true;
        });
        Navigator.pop(context);
      }
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          message = ProfileStrings.failure(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Widget page(
    String title,
    List<Widget> children, {
    VoidCallback? save,
    String saveLabel = 'Enregistrer',
  }) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.accessible ||
          controller.session.resourceKey != _resourceKey) {
        return const HistaeScaffold(body: SizedBox.shrink());
      }
      return PopScope(
        canPop: leaving || (!dirty && !busy),
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || busy) return;
          if (await confirmAction(
                context,
                'Quitter sans enregistrer ?',
                'Votre brouillon sera abandonné.',
                action: 'Quitter',
              ) &&
              mounted &&
              context.mounted) {
            setState(() {
              leaving = true;
            });
            Navigator.pop(context);
          }
        },
        child: HistaeScaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ...children,
                if (busy || controller.loading)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Enregistrement ou relecture en cours',
                  ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(liveRegion: true, child: Text(message!)),
                  ),
                if (controller.uncertain)
                  const Text(
                    'Le résultat reste incertain. Relisez les données : aucune modification ne sera renvoyée automatiquement. Votre brouillon est conservé.',
                  ),
                if (message != null || controller.uncertain)
                  OutlinedButton(
                    onPressed:
                        busy ||
                            controller.loading ||
                            controller.retrySeconds > 0
                        ? null
                        : controller.load,
                    child: const Text('Relire les données serveur'),
                  ),
                const SizedBox(height: 24),
                if (save != null)
                  HistaeButton(
                    onPressed: busy || !controller.canWrite ? null : save,
                    child: Text(
                      controller.retrySeconds > 0
                          ? 'Réessayez dans ${controller.retrySeconds} s'
                          : saveLabel,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget field(
    TextEditingController text,
    String label, {
    int lines = 1,
    TextInputType? keyboard,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextField(
      controller: text,
      onChanged: (_) => setState(changed),
      enabled: !busy && !controller.saving,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperMaxLines: 4,
      ),
      maxLines: lines,
      keyboardType: keyboard,
    ),
  );
}
