// Colour tokens named by ROLE, never by tone (vault ADR 0031). A feature reads
// `context.palette.<role>`; it never uses Color(0x...) or a tone name directly.
// `onBrand` does not mean "white": it means "on top of the brand fill".
// Contrast ratios are COMPUTED in test/core/palette_contrast_test.dart.
//
// Design 2.0 "Turno y Reloj" (docs/img/img_remaked, §4): ink-blue base, cobalt
// primary, one fixed colour per candidate (A indigo, B tangerine) and the
// question card in obsidian (the user's change to the spec's cream `paper`).
import 'package:flutter/material.dart';

import '../../domain/exam/models.dart' show Level, Role;

@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.overlay,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.brand,
    required this.onBrand,
    required this.brandSoft,
    required this.onBrandSoft,
    required this.link,
    required this.danger,
    required this.onDanger,
    required this.success,
    required this.warn,
    required this.pro,
    required this.roleA,
    required this.roleASoft,
    required this.roleB,
    required this.roleBSoft,
    required this.onRole,
    required this.paper,
    required this.onPaper,
    required this.paperLabel,
    required this.paperEdge,
    required this.glass,
    required this.glassEdge,
    required this.inverse,
    required this.onInverse,
    required this.levelB1,
    required this.levelB2,
    required this.levelC1,
    required this.levelB1Soft,
    required this.levelB2Soft,
    required this.levelC1Soft,
    required this.shadow,
  });

  /// Part 3 sticky notes (hand-drawn diagram) and the ink written on them.
  static const stickyNotes = [Color(0xFFFCE38A), Color(0xFFBDE6FF), Color(0xFFC9F2D8), Color(0xFFFFD3BE), Color(0xFFE3D7FF)];
  static const onSticky = Color(0xFF1C1F27);

  /// bg.base / bg.elevated / bg.raised / bg.overlay.
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color overlay;

  /// Hairline separators only: surfaces are filled, not outlined (§1).
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// cobalt.500: primary button, focus.
  final Color brand;
  final Color onBrand;

  /// Selected tab / segment fill and the cobalt.300 text on it.
  final Color brandSoft;
  final Color onBrandSoft;

  /// Links and active icons (cobalt.300 on dark).
  final Color link;

  /// state.over: time over, leave, delete account.
  final Color danger;
  final Color onDanger;

  /// state.live: mic open, connected, ready.
  final Color success;

  /// state.warn: last 10 s, unstable connection.
  final Color warn;

  /// tier.pro (muted gold): Pro badge, leader crown.
  final Color pro;

  /// Candidate colours: border, voice ring, label (never the only signal).
  final Color roleA;
  final Color roleASoft;
  final Color roleB;
  final Color roleBSoft;

  /// Text on a role fill (the "A"/"B" circles).
  final Color onRole;

  /// The question card ("paper", obsidian) and what is written on it.
  final Color paper;
  final Color onPaper;
  final Color paperLabel;
  final Color paperEdge;

  /// Dock, tab bar and toasts float on this (with a blur behind).
  final Color glass;
  final Color glassEdge;

  /// Light-on-dark emphasis (the dock's big pause, "Continuar con Apple").
  final Color inverse;
  final Color onInverse;

  final Color levelB1;
  final Color levelB2;
  final Color levelC1;
  final Color levelB1Soft;
  final Color levelB2Soft;
  final Color levelC1Soft;
  final Color shadow;

  Color role(Role r) => r == Role.a ? roleA : roleB;
  Color roleSoft(Role r) => r == Role.a ? roleASoft : roleBSoft;
  Color level(Level l) => switch (l) {
        Level.b1 => levelB1,
        Level.b2 => levelB2,
        Level.c1 => levelC1,
      };
  Color levelSoft(Level l) => switch (l) {
        Level.b1 => levelB1Soft,
        Level.b2 => levelB2Soft,
        Level.c1 => levelC1Soft,
      };

  static const dark = Palette(
    background: Color(0xFF0B0E14),
    surface: Color(0xFF131722),
    surfaceMuted: Color(0xFF1B2030),
    overlay: Color(0xFF252B3D),
    border: Color(0xFF252B3D),
    textPrimary: Color(0xFFF2F4F8),
    textSecondary: Color(0xFFA9B1C3),
    textTertiary: Color(0xFF7D8598),
    brand: Color(0xFF3F62F5),
    onBrand: Color(0xFFFFFFFF),
    brandSoft: Color(0xFF232D52),
    onBrandSoft: Color(0xFF9DB0FF),
    link: Color(0xFF9DB0FF),
    danger: Color(0xFFFF6E6E),
    onDanger: Color(0xFF2A0606),
    success: Color(0xFF3DDC97),
    warn: Color(0xFFFFC24B),
    pro: Color(0xFFE2B65C),
    roleA: Color(0xFF7C8CFF),
    roleASoft: Color(0xFF1A2040),
    roleB: Color(0xFFFF9B5E),
    roleBSoft: Color(0xFF2E2019),
    onRole: Color(0xFF0B0E14),
    paper: Color(0xFF1F2026),
    onPaper: Color(0xFFF1EFEA),
    paperLabel: Color(0xFFB3AC9F),
    paperEdge: Color(0xFF34353D),
    glass: Color(0xCC1B2030),
    glassEdge: Color(0x33FFFFFF),
    inverse: Color(0xFFF2F4F8),
    onInverse: Color(0xFF0B0E14),
    levelB1: Color(0xFF3CC8A4),
    levelB2: Color(0xFF5BB8FF),
    levelC1: Color(0xFFE07BC0),
    levelB1Soft: Color(0xFF12302A),
    levelB2Soft: Color(0xFF142A40),
    levelC1Soft: Color(0xFF33203A),
    shadow: Color(0x73000000),
  );

  // §4.4: role colours darkened to pass AA on white; the question card stays obsidian.
  static const light = Palette(
    background: Color(0xFFF6F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFECEEF3),
    overlay: Color(0xFFDFE3EB),
    border: Color(0xFFE3E6ED),
    textPrimary: Color(0xFF121521),
    textSecondary: Color(0xFF515868),
    textTertiary: Color(0xFF6A7182),
    brand: Color(0xFF3657F0),
    onBrand: Color(0xFFFFFFFF),
    brandSoft: Color(0xFFE3E9FF),
    onBrandSoft: Color(0xFF2840B8),
    link: Color(0xFF2E4DE0),
    danger: Color(0xFFC42B2B),
    onDanger: Color(0xFFFFFFFF),
    success: Color(0xFF127A4E),
    warn: Color(0xFF9A6200),
    pro: Color(0xFF8C6415),
    roleA: Color(0xFF4553D6),
    roleASoft: Color(0xFFE6E9FF),
    roleB: Color(0xFFA84A15),
    roleBSoft: Color(0xFFFDEBDF),
    onRole: Color(0xFFFFFFFF),
    paper: Color(0xFF1F2026),
    onPaper: Color(0xFFF1EFEA),
    paperLabel: Color(0xFFB3AC9F),
    paperEdge: Color(0xFF34353D),
    glass: Color(0xD9FFFFFF),
    glassEdge: Color(0x1A121521),
    inverse: Color(0xFF121521),
    onInverse: Color(0xFFFFFFFF),
    levelB1: Color(0xFF0C7259),
    levelB2: Color(0xFF1767AD),
    levelC1: Color(0xFFA43A83),
    levelB1Soft: Color(0xFFDDF4EC),
    levelB2Soft: Color(0xFFDDEDFC),
    levelC1Soft: Color(0xFFF7E2F1),
    shadow: Color(0x26121521),
  );

  /// Foreground/background pairs that carry text. The contrast test walks this list.
  List<(String, Color, Color)> get textPairs => [
        ('textPrimary/background', textPrimary, background),
        ('textPrimary/surface', textPrimary, surface),
        ('textSecondary/surface', textSecondary, surface),
        ('textSecondary/background', textSecondary, background),
        ('textSecondary/surfaceMuted', textSecondary, surfaceMuted),
        ('textTertiary/background', textTertiary, background),
        ('onBrand/brand', onBrand, brand),
        ('onBrandSoft/brandSoft', onBrandSoft, brandSoft),
        ('link/surface', link, surface),
        ('danger/surface', danger, surface),
        ('onDanger/danger', onDanger, danger),
        ('success/surface', success, surface),
        ('warn/surface', warn, surface),
        ('pro/surface', pro, surface),
        ('roleA/surface', roleA, surface),
        ('roleB/surface', roleB, surface),
        ('roleA/roleASoft', roleA, roleASoft),
        ('roleB/roleBSoft', roleB, roleBSoft),
        ('onRole/roleA', onRole, roleA),
        ('onPaper/paper', onPaper, paper),
        ('paperLabel/paper', paperLabel, paper),
        ('onInverse/inverse', onInverse, inverse),
        ('levelB1/levelB1Soft', levelB1, levelB1Soft),
        ('levelB2/levelB2Soft', levelB2, levelB2Soft),
        ('levelC1/levelC1Soft', levelC1, levelC1Soft),
        for (final n in stickyNotes) ('onSticky/note', onSticky, n),
      ];

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => t < 0.5 ? this : (other as Palette? ?? this);
}

extension PaletteContext on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}
