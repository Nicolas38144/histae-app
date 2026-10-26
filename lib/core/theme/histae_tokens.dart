import 'package:flutter/material.dart';

/// Brand values shared with histae-site/app/globals.css.
abstract final class HistaeTokens {
  static const night = Color(0xff0d1421);
  static const nightSoft = Color(0xff141d2d);
  static const panel = Color(0xff1a2231);
  static const ink = Color(0xfff9f7f2);
  static const muted = Color(0xffc6c1d3);
  static const lavender = Color(0xffb69cff);
  static const coral = Color(0xfff09a82);
  static const plum = Color(0xff392243);
  static const line = Color(0xff303644);
  static const focus = Color(0xfff6be73);
  static const serif = 'SourceSerif4';
  static const sans = 'Inter';
  static const panelRadius = 20.0;
  static const actionSpacing = 16.0;
  static const actionGradient = LinearGradient(
    colors: [Color(0xfff2a48c), Color(0xffd8b3f7)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static LinearGradient panelGradient(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? [const Color(0xff24243d), const Color(0xff171f30)]
          : [const Color(0xffeee7fc), const Color(0xfffaf7f4)],
    );
  }
}
