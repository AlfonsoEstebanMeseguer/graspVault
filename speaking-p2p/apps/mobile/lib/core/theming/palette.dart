// Colour tokens named by ROLE, never by tone (vault ADR 0031). A feature reads
// `context.palette.<role>`; it never uses Color(0x...) or a tone name directly.
// `onBrand` does not mean "white": it means "on top of the brand fill".
// Contrast ratios are COMPUTED in test/core/palette_contrast_test.dart.
import 'package:flutter/material.dart';

@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.brand,
    required this.onBrand,
    required this.brandSoft,
    required this.onBrandSoft,
    required this.danger,
    required this.onDanger,
    required this.success,
    required this.examinerSoft,
    required this.onExaminerSoft,
    required this.timerFill,
    required this.onTimerFill,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color brand;
  final Color onBrand;
  final Color brandSoft;
  final Color onBrandSoft;
  final Color danger;
  final Color onDanger;
  final Color success;
  final Color examinerSoft;
  final Color onExaminerSoft;
  final Color timerFill;
  final Color onTimerFill;

  static const light = Palette(
    background: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFECEEF2),
    border: Color(0xFFDFE2E8),
    textPrimary: Color(0xFF111318),
    textSecondary: Color(0xFF5C616B),
    brand: Color(0xFF2E4BD9),
    onBrand: Color(0xFFFFFFFF),
    brandSoft: Color(0xFFE6EAFB),
    onBrandSoft: Color(0xFF1E36A8),
    danger: Color(0xFFB42318),
    onDanger: Color(0xFFFFFFFF),
    success: Color(0xFF15703A),
    examinerSoft: Color(0xFFFFF1E6),
    onExaminerSoft: Color(0xFF9A3A06),
    timerFill: Color(0xFF111318),
    onTimerFill: Color(0xFFFFFFFF),
  );

  static const dark = Palette(
    background: Color(0xFF111216),
    surface: Color(0xFF1C1E24),
    surfaceMuted: Color(0xFF262932),
    border: Color(0xFF33363F),
    textPrimary: Color(0xFFF2F3F5),
    textSecondary: Color(0xFFA6AAB4),
    brand: Color(0xFF8EA2FF),
    onBrand: Color(0xFF0E1640),
    brandSoft: Color(0xFF242C55),
    onBrandSoft: Color(0xFFC9D2FF),
    danger: Color(0xFFFF8A80),
    onDanger: Color(0xFF3B0A06),
    success: Color(0xFF6FD69A),
    examinerSoft: Color(0xFF3A2414),
    onExaminerSoft: Color(0xFFFFC59E),
    timerFill: Color(0xFFF2F3F5),
    onTimerFill: Color(0xFF111318),
  );

  /// Foreground/background pairs that carry text. The contrast test walks this list.
  List<(String, Color, Color)> get textPairs => [
        ('textPrimary/background', textPrimary, background),
        ('textPrimary/surface', textPrimary, surface),
        ('textSecondary/surface', textSecondary, surface),
        ('textSecondary/background', textSecondary, background),
        ('onBrand/brand', onBrand, brand),
        ('onBrandSoft/brandSoft', onBrandSoft, brandSoft),
        ('danger/surface', danger, surface),
        ('onDanger/danger', onDanger, danger),
        ('success/surface', success, surface),
        ('onExaminerSoft/examinerSoft', onExaminerSoft, examinerSoft),
        ('onTimerFill/timerFill', onTimerFill, timerFill),
      ];

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => t < 0.5 ? this : (other as Palette? ?? this);
}

extension PaletteContext on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}
