/// Typography of Repertorium chess (ТЗ «Типографіка», T-01…T-22).
///
/// The only place where font families, sizes, weights and line heights are
/// defined (T-06). Widgets use `Theme.of(context).textTheme` and the
/// [TabiyaText] extension (`context.tt`), adjusting with `copyWith` only for
/// color or font features.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bundled font families (T-01, T-03).
abstract final class AppFonts {
  /// Google Sans (variable, wght 400…700) — every text in the app.
  static const sans = 'GoogleSans';

  /// Google Sans Code (variable) — raw FEN / PGN only. It has no Cyrillic,
  /// so comments in raw PGN fall back to Google Sans.
  static const mono = 'GoogleSansCode';

  /// Subset of Noto Sans Math with NAG symbols missing in Google Sans (T-04).
  static const fallback = <String>['TabiyaSymbols'];

  static const monoFallback = <String>[sans, ...fallback];
}

/// Notation size setting (T-08). Normal is the app's text size (14), so
/// moves read like every other text under the board (D-054).
enum NotationSize {
  small(13),
  normal(14),
  large(16);

  const NotationSize(this.main);

  /// Size of every move; variations differ by tone and weight, not size.
  final double main;
  double get variation => main;

  static NotationSize fromName(String? n) =>
      NotationSize.values.firstWhere((s) => s.name == n, orElse: () => NotationSize.normal);
}

/// Piece letters in the displayed notation (T-13). Export is always SAN.
enum NotationLanguage {
  english,
  ukrainian,
  figurine;

  static NotationLanguage fromName(String? n) =>
      NotationLanguage.values.firstWhere((s) => s.name == n, orElse: () => NotationLanguage.english);
}

const _tabular = [FontFeature.tabularFigures()];

TextStyle _s(String family, double size, double lineHeight, FontWeight weight, {double letterSpacing = 0}) => TextStyle(
  fontFamily: family,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: lineHeight / size,
  fontWeight: weight,
  letterSpacing: letterSpacing,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The whole app uses four sizes and two weights (D-054): 24 for screen
/// headings, 18 for titles of screens and sheets (and the engine score),
/// 14 for everything else, 12 for secondary facts and captions; Regular
/// for text, SemiBold for names, titles, moves and controls. The Material
/// roles map onto that set, so any widget ends up on the same scale.
TextTheme buildTextTheme() {
  final heading = _s(AppFonts.sans, 24, 30, FontWeight.w600, letterSpacing: -0.3);
  final title = _s(AppFonts.sans, 14, 20, FontWeight.w600);
  final body = _s(AppFonts.sans, 14, 20, FontWeight.w400);
  final small = _s(AppFonts.sans, 12, 16, FontWeight.w400);
  final label = _s(AppFonts.sans, 12, 16, FontWeight.w600);
  return TextTheme(
    displayLarge: heading,
    displayMedium: heading,
    displaySmall: heading,
    headlineLarge: heading,
    headlineMedium: heading,
    headlineSmall: heading,
    titleLarge: _s(AppFonts.sans, 18, 24, FontWeight.w600, letterSpacing: -0.1),
    titleMedium: title,
    titleSmall: title,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: small,
    labelLarge: title,
    labelMedium: label,
    labelSmall: label,
  );
}

// ------------------------------------------------------------------ colors

double _luminance(Color c) => c.computeLuminance();

/// WCAG contrast ratio of two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Moves [fg] toward [strong] until the contrast against [bg] reaches
/// [min] (T-22).
Color ensureContrast(Color fg, Color bg, {double min = 4.5, required Color strong}) {
  var c = fg;
  for (var i = 1; i <= 10 && contrastRatio(c, bg) < min; i++) {
    c = Color.lerp(fg, strong, i / 10)!;
  }
  return c;
}

/// NAG colors in the spirit of Lichess (T-10): good — green, mistake —
/// red, inaccuracy — yellow, interesting — blue. Tuned for AA contrast.
class NagColors {
  const NagColors({required this.good, required this.mistake, required this.inaccuracy, required this.interesting});

  final Color good;
  final Color mistake;
  final Color inaccuracy;
  final Color interesting;

  factory NagColors.of(ColorScheme cs) {
    final light = cs.brightness == Brightness.light;
    Color fit(Color c) => ensureContrast(c, cs.surface, strong: cs.onSurface);
    return NagColors(
      good: fit(light ? const Color(0xFF1B7F2A) : const Color(0xFF7BD88F)),
      mistake: fit(light ? const Color(0xFFC62828) : const Color(0xFFFF8A80)),
      inaccuracy: fit(light ? const Color(0xFF8A6A00) : const Color(0xFFFFD54F)),
      interesting: fit(light ? const Color(0xFF1565C0) : const Color(0xFF90CAF9)),
    );
  }

  /// Color for a move-quality NAG (1…6), null otherwise.
  Color? forNag(int nag) => switch (nag) {
    1 || 3 => good,
    2 || 4 => mistake,
    6 => inaccuracy,
    5 => interesting,
    _ => null,
  };
}

// ------------------------------------------------------------------ extension

/// App-specific text styles derived from the scale (notation, numbers,
/// monospace). Registered as a [ThemeExtension]; read with `context.tt`.
@immutable
class TabiyaText extends ThemeExtension<TabiyaText> {
  const TabiyaText({
    required this.notationSize,
    required this.moveMain,
    required this.moveNumber,
    required this.comment,
    required this.variationBase,
    required this.variationColors,
    required this.mono,
    required this.monoSmall,
    required this.nag,
    required this.currentMoveBackground,
    required this.currentMoveForeground,
    required this.overline,
    required this.title,
    required this.body,
    required this.meta,
    required this.value,
    required this.control,
  });

  final NotationSize notationSize;

  /// Main-line move: Google Sans 600, onSurface, tabular figures (T-10).
  final TextStyle moveMain;

  /// Move number `12.` / `12...`: Google Sans 400, onSurfaceVariant.
  final TextStyle moveNumber;

  /// Comment to a move: Google Sans 400, onSurfaceVariant, no italics (T-12).
  final TextStyle comment;

  /// Variation move (Google Sans 400); color per depth from [variationColors].
  final TextStyle variationBase;

  /// Text color per variation depth 1…4, each a tone lighter (T-11) but
  /// keeping AA contrast (T-22).
  final List<Color> variationColors;

  /// Google Sans Code for raw FEN / PGN (bodyMedium metrics).
  final TextStyle mono;
  final TextStyle monoSmall;
  final NagColors nag;
  final Color currentMoveBackground;
  final Color currentMoveForeground;

  /// Section label: small capitals-like caption above a group
  /// ("ЗАГАЛЬНІ", "ВАШІ ХОДИ"); the text is upper-cased by the widget.
  final TextStyle overline;

  // Text roles under and beside the board (D-053, D-054). Every screen
  // with a board uses only these, the move styles above and the theme's
  // buttons: no other sizes or weights there.

  /// A name or heading in a panel (engine source, "Add to repertoire",
  /// a training verdict): 14, SemiBold.
  final TextStyle title;

  /// Running text (explanations, hints): 14. Comments use [comment]:
  /// the same size in grey, as in the notation.
  final TextStyle body;

  /// Secondary facts in grey (opening name, depth, status, counts,
  /// weights, notes): 12.
  final TextStyle meta;

  /// Words on controls (buttons, tool tiles, switches, chips): 14,
  /// SemiBold — the theme's button text.
  final TextStyle control;

  /// The one number that matters (engine score): 18, SemiBold, tabular.
  final TextStyle value;

  static const maxIndentDepth = 4;
  static const indentPerLevel = 12.0;

  TextStyle variation(int depth) =>
      variationBase.copyWith(color: variationColors[(depth.clamp(1, maxIndentDepth)) - 1]);

  factory TabiyaText.build(ColorScheme cs, TextTheme t, NotationSize size) {
    final main = size.main;
    final varSize = size.variation;
    TextStyle sized(TextStyle base, double s) => base.copyWith(fontSize: s, height: (s + 8) / s);
    final variationColors = <Color>[];
    for (var d = 1; d <= maxIndentDepth; d++) {
      final lighter = Color.lerp(cs.onSurfaceVariant, cs.surface, 0.12 * (d - 1))!;
      var c = ensureContrast(lighter, cs.surface, strong: cs.onSurface);
      // Never darker than the previous level (the AA clamp may overshoot).
      if (variationColors.isNotEmpty &&
          contrastRatio(c, cs.surface) > contrastRatio(variationColors.last, cs.surface)) {
        c = variationColors.last;
      }
      variationColors.add(c);
    }
    return TabiyaText(
      notationSize: size,
      moveMain: sized(
        t.bodyLarge!,
        main,
      ).copyWith(fontWeight: FontWeight.w600, color: cs.onSurface, fontFeatures: _tabular),
      moveNumber: sized(t.bodyLarge!, main).copyWith(color: cs.onSurfaceVariant, fontFeatures: _tabular),
      // A size smaller than the moves, prose line height: long lecture
      // comments read like text and do not drown the moves.
      comment: t.bodyLarge!.copyWith(fontSize: main, height: 1.35, color: cs.onSurfaceVariant),
      variationBase: sized(t.bodyMedium!, varSize).copyWith(fontFeatures: _tabular),
      variationColors: variationColors,
      mono: t.bodyMedium!.copyWith(fontFamily: AppFonts.mono, fontFamilyFallback: AppFonts.monoFallback),
      monoSmall: t.bodySmall!.copyWith(fontFamily: AppFonts.mono, fontFamilyFallback: AppFonts.monoFallback),
      nag: NagColors.of(cs),
      currentMoveBackground: cs.primaryContainer,
      currentMoveForeground: cs.onPrimaryContainer,
      overline: t.labelMedium!.copyWith(letterSpacing: 0.6, color: cs.onSurfaceVariant),
      title: t.titleMedium!.copyWith(color: cs.onSurface),
      body: t.bodyLarge!.copyWith(color: cs.onSurface),
      meta: t.bodySmall!.copyWith(color: cs.onSurfaceVariant),
      value: t.titleLarge!.copyWith(color: cs.onSurface, fontFeatures: _tabular),
      control: t.labelLarge!,
    );
  }

  @override
  TabiyaText copyWith({NotationSize? notationSize}) => this;

  @override
  TabiyaText lerp(TabiyaText? other, double t) => t < 0.5 || other == null ? this : other;
}

extension TypographyContext on BuildContext {
  /// App text extension (notation, mono, NAG colors).
  TabiyaText get tt => Theme.of(this).extension<TabiyaText>()!;

  TextTheme get text => Theme.of(this).textTheme;
}

extension TabularFigures on TextStyle {
  /// Tabular figures for numbers that change or align (T-09).
  TextStyle get tabular => copyWith(fontFeatures: _tabular);
}

/// Text scale limit for the board and its coordinates (T-21).
const kBoardTextScaleMax = 1.0;
