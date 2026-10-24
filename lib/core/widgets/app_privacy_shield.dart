import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/histae_tokens.dart';
import 'histae_brand_symbol.dart';

/// Keeps navigation and form state mounted while hiding inactive app content.
/// Native protections additionally cover OS snapshots and Android screenshots.
class AppPrivacyShield extends StatefulWidget {
  const AppPrivacyShield({super.key, required this.child});

  final Widget child;

  @override
  State<AppPrivacyShield> createState() => _AppPrivacyShieldState();
}

class _AppPrivacyShieldState extends State<AppPrivacyShield>
    with WidgetsBindingObserver {
  bool _hidden = _isHidden(WidgetsBinding.instance.lifecycleState);

  static bool _isHidden(AppLifecycleState? state) =>
      state != null && state != AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hidden = _isHidden(state);
    if (hidden == _hidden) return;
    if (hidden) FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _hidden = hidden);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeFocus(
        excluding: _hidden,
        child: ExcludeSemantics(
          excluding: _hidden,
          child: IgnorePointer(ignoring: _hidden, child: widget.child),
        ),
      ),
      if (_hidden)
        Positioned.fill(
          key: const Key('app-privacy-shield'),
          child: Semantics(
            label: AppStrings.of(context).messages.screenPrivacyLabel,
            excludeSemantics: true,
            child: const ColoredBox(
              color: HistaeTokens.night,
              child: Center(child: HistaeBrandSymbol(size: 64)),
            ),
          ),
        ),
    ],
  );
}
