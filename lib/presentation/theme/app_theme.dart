import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'tokens.dart';
import 'typography.dart';

export 'tokens.dart';
export 'typography.dart';

/// Material 3 themes (9.4), monochrome in the spirit of Stoic: a light grey
/// canvas with white cards (black canvas with graphite cards in dark mode),
/// near-black text, and emphasis by inversion (black pill buttons, black
/// selected items) instead of a brand colour. Colour is reserved for
/// meaning: right/wrong, NAGs, arrows on the board (D-032).
class AppTheme {
  static const ink = Color(0xFF111111);
  static const paper = Color(0xFFF2F2F7);

  static const _light = ColorScheme(
    brightness: Brightness.light,
    primary: ink,
    onPrimary: Colors.white,
    primaryContainer: ink,
    onPrimaryContainer: Colors.white,
    secondary: Color(0xFF3A3A3C),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE5E5EA),
    onSecondaryContainer: ink,
    tertiary: Color(0xFF3F4FC4),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFE3E6FA),
    onTertiaryContainer: Color(0xFF1A237E),
    error: Color(0xFFC92A2A),
    onError: Colors.white,
    errorContainer: Color(0xFFFDE4E2),
    onErrorContainer: Color(0xFF5A0F0C),
    surface: paper,
    onSurface: ink,
    onSurfaceVariant: Color(0xFF5E5E63),
    surfaceDim: Color(0xFFE5E5EA),
    surfaceBright: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Colors.white,
    surfaceContainer: Colors.white,
    surfaceContainerHigh: Color(0xFFE9E9EE),
    surfaceContainerHighest: Color(0xFFDEDEE3),
    outline: Color(0xFFC7C7CC),
    outlineVariant: Color(0xFFE0E0E5),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF1C1C1E),
    onInverseSurface: paper,
    inversePrimary: Colors.white,
    surfaceTint: Colors.transparent,
  );

  static const _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFF5F5F7),
    onPrimary: Colors.black,
    primaryContainer: Color(0xFFF5F5F7),
    onPrimaryContainer: Colors.black,
    secondary: Color(0xFFD1D1D6),
    onSecondary: Colors.black,
    secondaryContainer: Color(0xFF2C2C2E),
    onSecondaryContainer: Color(0xFFF5F5F7),
    tertiary: Color(0xFFA8B0FF),
    onTertiary: Color(0xFF0F1450),
    tertiaryContainer: Color(0xFF2A2F5A),
    onTertiaryContainer: Color(0xFFE0E3FF),
    error: Color(0xFFFF6B63),
    onError: Colors.black,
    errorContainer: Color(0xFF3F1715),
    onErrorContainer: Color(0xFFFFD9D6),
    surface: Colors.black,
    onSurface: Color(0xFFF5F5F7),
    onSurfaceVariant: Color(0xFFA1A1A6),
    surfaceDim: Colors.black,
    surfaceBright: Color(0xFF2C2C2E),
    surfaceContainerLowest: Color(0xFF0A0A0A),
    surfaceContainerLow: Color(0xFF1C1C1E),
    surfaceContainer: Color(0xFF1C1C1E),
    surfaceContainerHigh: Color(0xFF2C2C2E),
    surfaceContainerHighest: Color(0xFF3A3A3C),
    outline: Color(0xFF545458),
    outlineVariant: Color(0xFF2C2C2E),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFF2F2F7),
    onInverseSurface: ink,
    inversePrimary: ink,
    surfaceTint: Colors.transparent,
  );

  static ThemeData light({NotationSize notation = NotationSize.normal}) => _build(_light, notation);

  static ThemeData dark({NotationSize notation = NotationSize.normal}) => _build(_dark, notation);

  static ThemeData _build(ColorScheme cs, NotationSize notation) {
    final t = buildTextTheme().apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);
    final base = ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      fontFamily: AppFonts.sans,
      fontFamilyFallback: AppFonts.fallback,
      textTheme: t,
      scaffoldBackgroundColor: cs.surface,
      splashFactory: InkSparkle.splashFactory,
    );
    const pill = AppRadius.pill;
    WidgetStateProperty<Color?> selectedOr(Color on, Color off) =>
        WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? on : off);
    // Colourless, so every button takes its colour from foregroundColor.
    final button = buildTextTheme().labelLarge!.copyWith(fontWeight: FontWeight.w600);
    return base.copyWith(
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [TabiyaText.build(cs, t, notation)],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: t.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: AppRadius.lgShape,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          disabledBackgroundColor: cs.surfaceContainerHighest,
          minimumSize: const Size(64, AppSizes.controlMd),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: pill,
          textStyle: button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          backgroundColor: cs.surfaceContainerLow,
          side: BorderSide(color: cs.outlineVariant),
          minimumSize: const Size(64, AppSizes.controlMd),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: pill,
          textStyle: button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: cs.onSurface, shape: pill, textStyle: button),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: cs.onSurface)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: pill,
        extendedTextStyle: button,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: selectedOr(cs.primary, cs.surfaceContainerLow),
          foregroundColor: selectedOr(cs.onPrimary, cs.onSurface),
          iconColor: selectedOr(cs.onPrimary, cs.onSurface),
          side: WidgetStatePropertyAll(BorderSide(color: cs.outlineVariant)),
          textStyle: WidgetStatePropertyAll(button),
        ),
      ),
      chipTheme: ChipThemeData(
        color: selectedOr(cs.primary, cs.surfaceContainerLow),
        // Words on controls: 14 SemiBold, as buttons (D-053).
        labelStyle: button.copyWith(
          color: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? cs.onPrimary : cs.onSurface),
        ),
        checkmarkColor: cs.onPrimary,
        iconTheme: IconThemeData(color: cs.onSurface, size: AppSizes.iconMd),
        side: BorderSide(color: cs.outlineVariant),
        shape: pill,
        showCheckmark: false,
        padding: AppInsets.chip,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(cs.brightness == Brightness.light ? Colors.white : Colors.black),
        // An "off" switch must still be seen on a white card.
        trackColor: selectedOr(cs.primary, cs.outline),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      radioTheme: RadioThemeData(fillColor: selectedOr(cs.primary, cs.onSurfaceVariant)),
      checkboxTheme: CheckboxThemeData(
        fillColor: selectedOr(cs.primary, Colors.transparent),
        checkColor: WidgetStatePropertyAll(cs.onPrimary),
        shape: AppRadius.xsShape,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.surfaceContainerHighest,
        thumbColor: cs.primary,
        activeTickMarkColor: cs.onPrimary.withValues(alpha: 0.5),
        inactiveTickMarkColor: cs.onSurfaceVariant.withValues(alpha: 0.4),
        valueIndicatorColor: cs.inverseSurface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHighest,
        circularTrackColor: cs.surfaceContainerHighest,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: cs.surfaceContainerHigh,
        // Selected tab: a rounded square, like the analysis tool bar.
        indicatorShape: AppRadius.mdShape,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? cs.onSurface : cs.onSurfaceVariant),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => t.labelMedium!.copyWith(
            color: s.contains(WidgetState.selected) ? cs.onSurface : cs.onSurfaceVariant,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cs.surfaceContainerLow,
        indicatorColor: cs.surfaceContainerHigh,
        selectedIconTheme: IconThemeData(color: cs.onSurface),
        unselectedIconTheme: IconThemeData(color: cs.onSurfaceVariant),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: t.titleSmall,
        unselectedLabelStyle: t.titleSmall,
        labelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.onSurface,
        dividerColor: cs.outlineVariant,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 10,
        iconColor: cs.onSurface,
        selectedColor: cs.onSurface,
        selectedTileColor: cs.surfaceContainerHigh,
        titleTextStyle: t.bodyLarge,
        subtitleTextStyle: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
      // Back/close buttons use the app's icon set too.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(AppIcons.chevronLeft),
        closeButtonIconBuilder: (_) => const Icon(AppIcons.close),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: cs.onSurface,
        collapsedIconColor: cs.onSurfaceVariant,
        textColor: cs.onSurface,
        collapsedTextColor: cs.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLow,
        border: const OutlineInputBorder(borderRadius: AppRadius.mdAll, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: cs.onSurface, width: 1.5),
        ),
        // Without these a field with an error fell back to `border` and
        // lost its outline altogether.
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        floatingLabelStyle: TextStyle(color: cs.onSurface),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: AppRadius.xlShape,
        titleTextStyle: t.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: cs.outline,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      ),
      // Menus (D-081): a floating card with the corners of a card, a soft
      // shadow and a hairline edge so it reads on both themes.
      popupMenuTheme: PopupMenuThemeData(
        color: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: cs.shadow.withValues(alpha: AppOpacity.guide),
        menuPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: cs.outlineVariant),
        ),
        textStyle: t.bodyLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: t.bodyMedium?.copyWith(color: cs.onInverseSurface),
        actionTextColor: cs.onInverseSurface,
        // The action stays on the message's line ("Undo" on a row of its
        // own made the bar two lines tall and covered the last list item).
        actionOverflowThreshold: 1,
        shape: AppRadius.mdShape,
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1, space: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: cs.inverseSurface, borderRadius: AppRadius.smAll),
        textStyle: t.bodySmall?.copyWith(color: cs.onInverseSurface),
      ),
    );
  }
}

/// Semantic colors used for training feedback, readable in both themes
/// (checked for WCAG AA against their containers).
extension TabiyaColors on ColorScheme {
  Color get success => brightness == Brightness.light ? const Color(0xFF1B6E2A) : const Color(0xFF81C784);
  Color get warning => brightness == Brightness.light ? const Color(0xFF8A5A00) : const Color(0xFFFFB74D);
  Color get successContainer => brightness == Brightness.light ? const Color(0xFFDDF1E0) : const Color(0xFF16301B);
  Color get onSuccessContainer => brightness == Brightness.light ? const Color(0xFF0B3D16) : const Color(0xFFC8EFCB);
  Color get warningContainer => brightness == Brightness.light ? const Color(0xFFFFEBC2) : const Color(0xFF3D2C00);
  Color get onWarningContainer => brightness == Brightness.light ? const Color(0xFF3D2800) : const Color(0xFFFFDEA0);
  Color get errorSoft => errorContainer;

  /// The daily goal and the streak flame: the one warm colour of the
  /// otherwise monochrome home screen (progress, not an alarm).
  Color get flame => brightness == Brightness.light ? const Color(0xFFF26B1D) : const Color(0xFFFF8A3D);

  // Chess meanings (D-075). The two sides look the same in both themes:
  // they stand for the pieces, not for the interface.

  /// The white side: badges, the eval bar, white wins in a result bar.
  Color get sideWhite => const Color(0xFFF2F2F2);
  Color get onSideWhite => const Color(0xFF111111);

  /// The black side.
  Color get sideBlack => const Color(0xFF333333);
  Color get onSideBlack => Colors.white;

  /// Draws between the two sides in a result bar.
  Color get sideDraw => const Color(0xFFA0A0A0);

  /// The user's own results: won, drawn, lost.
  Color get win => success;
  Color get draw => outlineVariant;
  Color get loss => error;

  /// The mark on the board after an answer in training.
  Color get markCorrect => const Color(0xFF2E7D32);
  Color get markWrong => const Color(0xFFC62828);
}

/// Colours of arrows and circles on the board. Translucent, so the pieces
/// and squares show through; the same in both themes, as the board is.
abstract final class BoardColors {
  static const green = Color(0xAA15781B);
  static const red = Color(0xAA882020);
  static const blue = Color(0xAA003088);
  static const yellow = Color(0xAAE68F00);

  /// The move of the repertoire, the answer shown in training.
  static const mainMove = green;

  /// Another move the repertoire accepts; a second-level hint.
  static const alternativeMove = Color(0x99003088);

  /// What the opponent may play.
  static const opponentMove = Color(0x99882020);

  /// The engine's best move, under everything else.
  static const engineMove = Color(0x66003088);

  static const shadow = Color(0x33000000);

  /// Solid board themes of our own (light square, dark square).
  static const greyBoard = (Color(0xffc8c8c8), Color(0xff8a8a8a));
  static const purpleBoard = (Color(0xffe3dcee), Color(0xff8f78b0));

  /// Neutral stone, matching the monochrome interface.
  static const stoneBoard = (Color(0xffecebe7), Color(0xff9b9892));

  /// The soft shadow under the board.
  static const boardShadow = [BoxShadow(color: shadow, blurRadius: 6, offset: Offset(0, 2))];
}
