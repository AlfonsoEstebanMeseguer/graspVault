// Design 2.0 theme (spec §5): filled surfaces without borders (a border only
// for focus or selection), capsule primary buttons, 20 px cards, 28 px sheets.
import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.dart';

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.light ? Palette.light : Palette.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.brand,
    onPrimary: p.onBrand,
    secondary: p.brandSoft,
    onSecondary: p.onBrandSoft,
    error: p.danger,
    onError: p.onDanger,
    surface: p.surface,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    surfaceContainerHighest: p.surfaceMuted,
    surfaceContainerHigh: p.surfaceMuted,
    surfaceContainer: p.surface,
    surfaceContainerLow: p.surface,
    outline: p.overlay,
    outlineVariant: p.border,
  );
  final base = ThemeData(useMaterial3: true, brightness: brightness, fontFamily: AppFonts.sans);
  // Roboto as fallback for the few symbols Instrument Sans lacks (✓ ○).
  final text = base.textTheme
      .apply(fontFamily: AppFonts.sans, fontFamilyFallback: const ['Roboto'], bodyColor: p.textPrimary, displayColor: p.textPrimary);
  const capsule = StadiumBorder();
  final input = BorderRadius.circular(AppRadii.input);
  final label = AppType.headline;
  return base.copyWith(
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    extensions: [p],
    dividerColor: p.border,
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppType.headline.copyWith(color: p.textPrimary),
    ),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    splashFactory: InkSparkle.splashFactory,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: capsule,
        textStyle: label,
        backgroundColor: p.brand,
        foregroundColor: p.onBrand,
        disabledBackgroundColor: p.surfaceMuted,
        disabledForegroundColor: p.textTertiary,
      ),
    ),
    // "Secondary" buttons are a raised fill, not an outline.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: p.textPrimary,
        backgroundColor: p.surfaceMuted,
        side: BorderSide.none,
        shape: capsule,
        textStyle: label.copyWith(fontSize: 15),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.link, textStyle: label.copyWith(fontSize: 15), shape: capsule),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: p.textPrimary)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: AppType.body.copyWith(color: p.textTertiary),
      labelStyle: AppType.body.copyWith(color: p.textSecondary),
      floatingLabelStyle: AppType.footnote.copyWith(color: p.link),
      border: OutlineInputBorder(borderRadius: input, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: input, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: input, borderSide: BorderSide(color: p.brand, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: input, borderSide: BorderSide(color: p.danger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: input, borderSide: BorderSide(color: p.danger, width: 1.5)),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceMuted,
      selectedColor: p.brandSoft,
      disabledColor: p.surface,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.chip)),
      labelStyle: AppType.footnote.copyWith(color: p.textPrimary, fontWeight: FontWeight.w600),
      secondaryLabelStyle: AppType.footnote.copyWith(color: p.onBrandSoft, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.all(BorderSide.none),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.input))),
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.overlay : p.surfaceMuted),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.textPrimary : p.textSecondary),
        textStyle: WidgetStateProperty.all(AppType.footnote.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
        minimumSize: WidgetStateProperty.all(const Size(0, 44)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.link,
      textColor: p.textPrimary,
      titleTextStyle: AppType.body.copyWith(color: p.textPrimary),
      subtitleTextStyle: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 12,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.success : p.overlay),
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : p.textSecondary),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      modalBackgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: p.overlay,
      modalBarrierColor: Colors.black.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: AppType.title2.copyWith(color: p.textPrimary),
      contentTextStyle: AppType.body.copyWith(color: p.textSecondary),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.overlay,
      contentTextStyle: AppType.footnote.copyWith(color: p.textPrimary, fontSize: 15),
      actionTextColor: p.link,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.input)),
      elevation: 0,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surfaceMuted,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.input)),
      textStyle: AppType.body.copyWith(color: p.textPrimary),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.link, linearTrackColor: p.overlay, circularTrackColor: Colors.transparent),
    tabBarTheme: TabBarThemeData(
      labelColor: p.textPrimary,
      unselectedLabelColor: p.textSecondary,
      dividerColor: Colors.transparent,
      indicatorColor: p.link,
    ),
    datePickerTheme: DatePickerThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent),
    timePickerTheme: TimePickerThemeData(backgroundColor: p.surface),
  );
}
