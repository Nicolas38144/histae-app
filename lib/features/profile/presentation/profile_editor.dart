import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/histae_button.dart';
import '../../../core/widgets/histae_scaffold.dart';
import '../application/profile_controller.dart';
import 'profile_strings.dart';

abstract class ProfileEditorState<T extends StatefulWidget> extends State<T> {
  ProfileController get controller;
  bool dirty = false, busy = false, leaving = false;
  ClientMessage? message;
  ApiFailure? messageFailure;
  late final String _resourceKey = controller.session.resourceKey;

  @override
  void initState() {
    super.initState();
    controller.addListener(_dataChanged);
  }

  void _dataChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_dataChanged);
    super.dispose();
  }

  void changed() {
    dirty = true;
  }

  Future<void> submit(Future<void> Function() action) async {
    if (busy || !controller.canWrite) return;
    setState(() {
      busy = true;
      message = null;
      messageFailure = null;
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
          messageFailure = e;
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
    String? saveLabel,
    bool saveInFooter = false,
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
                AppStrings.of(context).messages.profileEditorLeaveWithoutSaving,
                AppStrings.of(context)
                    .messages
                    .profileEditorYourDraftWillBeDiscarded,
                action: AppStrings.of(context).messages.profileEditorLeave,
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
          bottomNavigationBar: saveInFooter && save != null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: _saveButton(
                        save,
                        saveLabel ??
                            AppStrings.of(context).messages.answersEditorSave,
                      ),
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ...children,
                if (busy || controller.loading)
                  LinearProgressIndicator(
                    semanticsLabel: AppStrings.of(context)
                        .messages
                        .profileEditorSavingOrRefreshing,
                  ),
                if (message != null || messageFailure != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        message != null
                            ? AppStrings.of(context).clientMessage(message!)
                            : ProfileStrings(AppStrings.of(context))
                                  .failure(messageFailure!),
                      ),
                    ),
                  ),
                if (controller.uncertain)
                  Text(
                    AppStrings.of(context)
                        .messages
                        .profileEditorTheResultIsUncertainRefreshThe,
                  ),
                if (message != null ||
                    messageFailure != null ||
                    controller.uncertain)
                  HistaeButton.outlined(
                    onPressed:
                        busy ||
                            controller.loading ||
                            controller.retrySeconds > 0
                        ? null
                        : controller.load,
                    child: Text(
                      AppStrings.of(context)
                          .messages
                          .profileEditorRefreshServerData,
                    ),
                  ),
                const SizedBox(height: 24),
                if (save != null && !saveInFooter)
                  _saveButton(
                    save,
                    saveLabel ??
                        AppStrings.of(context).messages.answersEditorSave,
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _saveButton(VoidCallback save, String label) => HistaeButton(
    onPressed: busy || !controller.canWrite ? null : save,
    child: Text(
      controller.retrySeconds > 0
          ? AppStrings.of(context).messages
                .discoveryPauseCardTryAgainInS(controller.retrySeconds)
          : label,
    ),
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
