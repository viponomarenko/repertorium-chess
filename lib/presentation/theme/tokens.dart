/// Design tokens of Repertorium chess (D-075): the only place where
/// spacing, radii, sizes, opacities and motion are given as numbers.
/// Screens use these names (and the shared widgets built on them), never a
/// literal, so the same thing looks and moves the same everywhere. Colours
/// live in `app_theme.dart`, text in `typography.dart`, icons in
/// `app_icons.dart`.
library;

import 'package:flutter/material.dart';

/// Spacing scale, in logical pixels.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Side margin of a screen and of everything aligned with it.
  static const double page = lg;

  /// Padding inside a card.
  static const double card = lg;

  /// Between two cards of one group.
  static const double cardGap = md;

  /// Between two groups (above a section caption).
  static const double sectionGap = xl;

  /// Under the last item of a scrolling screen.
  static const double listBottom = xl;
}

/// Ready paddings for the recurring places.
abstract final class AppInsets {
  /// A scrolling screen: side margins, a little air on top, room below.
  static const page = EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.listBottom);

  /// Side margins only.
  static const pageH = EdgeInsets.symmetric(horizontal: AppSpacing.page);

  static const card = EdgeInsets.all(AppSpacing.card);

  /// A tonal strip with a message (denser than a card).
  static const strip = EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md);

  /// Content of a bottom sheet under its handle.
  static const sheet = EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg);

  /// Title of a bottom sheet.
  static const sheetTitle = EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md);

  /// A line of text under the board, aligned with the screen margin.
  static const row = EdgeInsets.symmetric(horizontal: AppSpacing.page);

  /// A section caption above a group; aligned with the text in cards.
  static const sectionHeader = EdgeInsets.fromLTRB(
    AppSpacing.page + AppSpacing.card,
    AppSpacing.xl,
    AppSpacing.page,
    AppSpacing.sm,
  );

  /// Around a move in the notation: moves stand close, like text (D-042).
  static const moveChip = EdgeInsets.symmetric(horizontal: 5, vertical: 2);

  /// Inside a chip, around its label.
  static const chip = EdgeInsets.all(6);

  /// A pinned bar with the main action.
  static const actionBar = EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md);
}

/// Ready gaps between siblings in a column (`v*`) or a row (`h*`).
abstract final class AppGap {
  static const v2 = SizedBox(height: AppSpacing.xxs);
  static const v4 = SizedBox(height: AppSpacing.xs);
  static const v8 = SizedBox(height: AppSpacing.sm);
  static const v12 = SizedBox(height: AppSpacing.md);
  static const v16 = SizedBox(height: AppSpacing.lg);
  static const v24 = SizedBox(height: AppSpacing.xl);
  static const v32 = SizedBox(height: AppSpacing.xxl);

  static const h2 = SizedBox(width: AppSpacing.xxs);
  static const h4 = SizedBox(width: AppSpacing.xs);
  static const h8 = SizedBox(width: AppSpacing.sm);
  static const h12 = SizedBox(width: AppSpacing.md);
  static const h16 = SizedBox(width: AppSpacing.lg);
}

/// Corner radii: five steps and the pill.
abstract final class AppRadius {
  /// Move chips, the board, small marks.
  static const double xs = 6;

  /// Swatches, tooltips, small boxes.
  static const double sm = 8;

  /// Strips, text fields, menus, snack bars, bar buttons.
  static const double md = 12;

  /// Cards.
  static const double lg = 20;

  /// Sheets and dialogs.
  static const double xl = 28;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius sheetTop = BorderRadius.vertical(top: Radius.circular(xl));

  /// Bars, pills, dots: fully rounded ends.
  static const BorderRadius full = BorderRadius.all(Radius.circular(999));

  static const OutlinedBorder pill = StadiumBorder();
  static const OutlinedBorder xsShape = RoundedRectangleBorder(borderRadius: xsAll);
  static const OutlinedBorder smShape = RoundedRectangleBorder(borderRadius: smAll);
  static const OutlinedBorder mdShape = RoundedRectangleBorder(borderRadius: mdAll);
  static const OutlinedBorder lgShape = RoundedRectangleBorder(borderRadius: lgAll);
  static const OutlinedBorder xlShape = RoundedRectangleBorder(borderRadius: xlAll);
}

/// Sizes of icons, controls and rows.
abstract final class AppSizes {
  /// An icon inside a line of small text.
  static const double iconSm = 16;

  /// An icon next to a word (buttons, status lines, tool rows).
  static const double iconMd = 20;

  /// A stand-alone icon (app bar, list tile); the framework default.
  static const double iconLg = 24;

  /// The picture of an empty state or a summary.
  static const double iconHero = 64;

  /// A control that sits inside a bar or a dense row (tap area stays 48).
  static const double controlSm = 40;

  /// A regular button or field.
  static const double controlMd = 48;

  /// The main action of a screen.
  static const double controlLg = 56;

  /// The smallest area a finger has to hit (D-035).
  static const double tapTarget = 48;

  /// A row of moves under the board (D-046, D-074).
  static const double moveRow = 36;

  /// A labelled button of a bottom bar (D-035).
  static const double barButton = 56;

  /// A round badge or avatar in a list row.
  static const double avatar = 40;

  /// The fold arrow at the start of a variation.
  static const double foldToggle = 28;

  /// The handle under the board and on sheets.
  static const double gripWidth = 40;
  static const double gripHeight = 4;

  /// A thin bar: progress, results.

  static const double bar = 6;

  /// Thickness of a hairline.
  static const double hairline = 1;

  /// Widest readable column on tablets.
  static const double maxContentWidth = 720;
}

/// Opacities for states.
abstract final class AppOpacity {
  /// Guide lines and the grip: there, but out of the way.
  static const double guide = 0.35;

  /// A disabled control (Material 3).
  static const double disabled = 0.38;

  /// Something present but in the background (guides, the grip).
  static const double muted = 0.5;

  /// A faint tint of a colour (tracks, washes).
  static const double faint = 0.14;
}

/// Waits that are not motion: how long to hold before reacting.
abstract final class AppTiming {
  /// After the last keystroke or option change, before recomputing.
  static const Duration inputDebounce = Duration(milliseconds: 250);

  /// After the last move, before the engine starts (D-034).
  static const Duration engineDebounce = Duration(milliseconds: 300);

  /// After the last edit, before a game is saved.
  static const Duration autosave = Duration(milliseconds: 700);

  /// Bringing the current move into view.
  static const Duration scrollToMove = Duration(milliseconds: 150);
}

/// The pace of a lesson: how long each step is held. Not UI motion, so
/// these do not shorten with "Reduce motion".
abstract final class TrainingPace {
  /// Before a move that is replayed quickly on the way to the position.
  static const Duration fastMove = Duration(milliseconds: 120);

  /// For that move to land before the next one.
  static const Duration fastSettle = Duration(milliseconds: 60);

  /// The "recall the line" message stays before the board is reset.
  static const Duration recallIntro = Duration(milliseconds: 1200);

  /// After a correct answer without a comment, before the reply.
  static const Duration afterAnswer = Duration(milliseconds: 150);

  /// After a correct answer with a comment: time to notice it.
  static const Duration afterComment = Duration(milliseconds: 900);

  /// How long the ✓ / ✗ mark stays on the square.
  static const Duration mark = Duration(milliseconds: 900);
}

/// Size variants of the theme's buttons, to pass as `style:`. The colours
/// and the shape come from the theme.
abstract final class AppButtonSize {
  /// In an app bar or a dense row: 40 high, the tap area is still 48.
  static const ButtonStyle compact = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, AppSizes.controlSm)),
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpacing.lg)),
    tapTargetSize: MaterialTapTargetSize.padded,
  );

  /// The main action of a screen or a sheet: full width, 56 high.
  static const ButtonStyle large = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size.fromHeight(AppSizes.controlLg)),
  );

  /// A full-width button of the regular height (secondary actions under
  /// the main one).
  static const ButtonStyle wide = ButtonStyle(minimumSize: WidgetStatePropertyAll(Size.fromHeight(AppSizes.controlMd)));
}

/// Motion (D-077): four durations and the Material 3 easing set. Widgets
/// ask [AppMotion.of], which turns everything off when the system asks to
/// reduce motion.
@immutable
class AppMotion {
  const AppMotion._(this.enabled);

  /// Whether things may move (false with "Reduce motion").
  final bool enabled;

  static const _on = AppMotion._(true);
  static const _off = AppMotion._(false);

  static AppMotion of(BuildContext context) => MediaQuery.disableAnimationsOf(context) ? _off : _on;

  /// Raw values, for places without a context (theme, constants).
  static const Duration fastMs = Duration(milliseconds: 100);
  static const Duration baseMs = Duration(milliseconds: 200);
  static const Duration enterMs = Duration(milliseconds: 300);
  static const Duration emphasisMs = Duration(milliseconds: 500);

  /// State of a small control: a highlight, a pressed pill, a colour.
  Duration get fast => enabled ? fastMs : Duration.zero;

  /// Something leaving, a cross-fade, a size change.
  Duration get base => enabled ? baseMs : Duration.zero;

  /// Something entering the screen.
  Duration get enter => enabled ? enterMs : Duration.zero;

  /// A moment worth noticing: progress filling, a result.
  Duration get emphasis => enabled ? emphasisMs : Duration.zero;

  /// Changes that stay on screen (size, colour, position).
  static const Curve standard = Easing.standard;

  /// Entering: fast start, long soft landing.
  static const Curve enterCurve = Easing.emphasizedDecelerate;

  /// Leaving: gathers speed and goes.
  static const Curve exitCurve = Easing.emphasizedAccelerate;

  /// A small overshoot for accents (a check mark popping in).
  static const Curve accent = Cubic(0.34, 1.4, 0.64, 1);
}
