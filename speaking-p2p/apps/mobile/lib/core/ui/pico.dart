// Pico, the clay parrot (spec §9): indigo plumage with a tangerine tail, the two
// candidate colours. Drawn in code (the user chose vector over Rive); the moods
// stand in for the Rive state machine: idle, wave, search, listen, celebrate,
// sleep. Lives outside the exam only (welcome, search, lobby, end, empty states).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/exam/models.dart' show Level;

enum PicoMood { idle, wave, search, listen, celebrate, sleep }

class Pico extends StatefulWidget {
  const Pico({super.key, this.size = 120, this.mood = PicoMood.idle, this.level});
  final double size;
  final PicoMood mood;

  /// B1 cap, B2 bow tie, C1 mortarboard.
  final Level? level;

  @override
  State<Pico> createState() => _PicoState();
}

class _PicoState extends State<Pico> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(
              size: Size.square(widget.size),
              painter: PicoPainter(t: _c.value, mood: widget.mood, level: widget.level),
            ),
          ),
        ),
      );
}

class PicoPainter extends CustomPainter {
  PicoPainter({required this.t, required this.mood, this.level});
  final double t;
  final PicoMood mood;
  final Level? level;

  static const _indigo = Color(0xFF7C8CFF);
  static const _indigoDeep = Color(0xFF4E5CD8);
  static const _indigoShade = Color(0xFF3A45B0);
  static const _belly = Color(0xFFDCE0FF);
  static const _tangerine = Color(0xFFFF9B5E);
  static const _tangerineDeep = Color(0xFFE0712F);
  static const _ink = Color(0xFF14161F);

  double get _phase => t * 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);

    // Motion per mood (all loop over the same 3.2 s cycle).
    final bob = switch (mood) {
      PicoMood.celebrate => -math.max(0.0, math.sin(_phase * 2)) * 9,
      PicoMood.sleep => math.sin(_phase) * 0.8,
      _ => math.sin(_phase) * 2,
    };
    final tilt = switch (mood) {
      PicoMood.search => math.sin(_phase) * 0.12,
      PicoMood.listen => 0.1,
      _ => 0.0,
    };

    // Ground shadow (does not move with the body).
    final shadowW = 34 - bob.abs() * 0.8;
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 93), width: shadowW, height: 6),
        Paint()..color = const Color(0x40000000));

    canvas.translate(0, bob);
    canvas.translate(50, 60);
    canvas.rotate(tilt);
    canvas.translate(-50, -60);

    _tail(canvas);
    _wings(canvas);
    _body(canvas);
    _face(canvas);
    _crest(canvas);
    _accessory(canvas);
    canvas.restore();

    if (mood == PicoMood.sleep) _zzz(canvas, s);
    if (mood == PicoMood.celebrate) _confetti(canvas, s);
  }

  void _tail(Canvas c) {
    final p = Paint()..color = _tangerine;
    final d = Paint()..color = _tangerineDeep;
    final wag = math.sin(_phase * 2) * 2;
    final left = Path()
      ..moveTo(44, 82)
      ..lineTo(36 + wag, 96)
      ..lineTo(48, 90)
      ..close();
    final right = Path()
      ..moveTo(54, 82)
      ..lineTo(64 + wag, 96)
      ..lineTo(51, 91)
      ..close();
    c.drawPath(left, d);
    c.drawPath(right, p);
  }

  void _wings(Canvas c) {
    final paint = Paint()..color = _indigoDeep;
    // Left wing: waves in "wave" and "celebrate".
    final lift = switch (mood) {
      PicoMood.wave => (0.5 + 0.5 * math.sin(_phase * 3)) * 0.9,
      PicoMood.celebrate => 0.9 + math.sin(_phase * 4) * 0.2,
      _ => 0.0,
    };
    c.save();
    c.translate(26, 58);
    c.rotate(lift);
    c.drawOval(Rect.fromCenter(center: const Offset(-2, 10), width: 14, height: 26), paint);
    c.restore();
    final liftR = mood == PicoMood.celebrate ? lift : 0.0;
    c.save();
    c.translate(74, 58);
    c.rotate(-liftR);
    c.drawOval(Rect.fromCenter(center: const Offset(2, 10), width: 14, height: 26), paint);
    c.restore();
  }

  void _body(Canvas c) {
    const body = Rect.fromLTWH(22, 30, 56, 56);
    c.drawOval(
      body,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.5),
          radius: 0.95,
          colors: [Color(0xFF9AA6FF), _indigo, _indigoShade],
          stops: [0, 0.55, 1],
        ).createShader(body),
    );
    // Clay highlight.
    c.drawOval(const Rect.fromLTWH(32, 35, 18, 8), Paint()..color = const Color(0x55FFFFFF));
    // Belly.
    c.drawOval(
      const Rect.fromLTWH(34, 56, 32, 26),
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_belly, Color(0xFFC5CBFF)])
            .createShader(const Rect.fromLTWH(34, 56, 32, 26)),
    );
  }

  void _face(Canvas c) {
    // Blink every cycle (eyes closed for a short slice), always closed asleep.
    final blink = mood == PicoMood.sleep || (t > 0.46 && t < 0.5);
    final look = switch (mood) {
      PicoMood.search => math.sin(_phase) * 2.2,
      PicoMood.listen => 1.5,
      _ => 0.0,
    };
    for (final x in [40.0, 60.0]) {
      if (blink) {
        c.drawArc(Rect.fromCenter(center: Offset(x, 50), width: 10, height: 6), 0.2, math.pi - 0.4, false,
            Paint()
              ..color = _ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round);
      } else {
        c.drawCircle(Offset(x, 49), 7, Paint()..color = Colors.white);
        c.drawCircle(Offset(x + look, 50), 3.6, Paint()..color = _ink);
        c.drawCircle(Offset(x + look + 1.2, 48.6), 1.1, Paint()..color = Colors.white);
      }
    }
    if (mood == PicoMood.celebrate || mood == PicoMood.wave) {
      // Rosy cheeks.
      for (final x in [33.0, 67.0]) {
        c.drawOval(Rect.fromCenter(center: Offset(x, 58), width: 7, height: 4), Paint()..color = const Color(0x55FF7A9A));
      }
    }
    // Beak: tangerine, pointing down.
    final open = mood == PicoMood.celebrate ? 2.0 : (mood == PicoMood.listen ? 0.0 : 0.0);
    final beak = Path()
      ..moveTo(44, 56)
      ..quadraticBezierTo(50, 53, 56, 56)
      ..quadraticBezierTo(53, 64 + open, 50, 67 + open)
      ..quadraticBezierTo(47, 64 + open, 44, 56)
      ..close();
    c.drawPath(beak, Paint()..color = _tangerine);
    c.drawPath(
        beak,
        Paint()
          ..color = _tangerineDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  void _crest(Canvas c) {
    if (level == Level.b1 || level == Level.c1) return; // the hat sits there
    final sway = math.sin(_phase * 2) * 1.5;
    final crest = Path()
      ..moveTo(47, 32)
      ..cubicTo(44 + sway, 20, 52 + sway, 14, 56 + sway, 20)
      ..cubicTo(58 + sway, 24, 54 + sway, 26, 52 + sway, 23);
    c.drawPath(
        crest,
        Paint()
          ..color = _tangerine
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
  }

  void _accessory(Canvas c) {
    switch (level) {
      case Level.b1: // cap
        c.drawArc(const Rect.fromLTWH(34, 24, 32, 20), math.pi, math.pi, true, Paint()..color = const Color(0xFF3CC8A4));
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(48, 32, 24, 4), const Radius.circular(2)), Paint()..color = const Color(0xFF2A9A7E));
        c.drawCircle(const Offset(50, 24), 2, Paint()..color = const Color(0xFF2A9A7E));
      case Level.b2: // bow tie
        final tie = Paint()..color = const Color(0xFF5BB8FF);
        c.drawPath(Path()..moveTo(50, 84)..lineTo(42, 79)..lineTo(42, 89)..close(), tie);
        c.drawPath(Path()..moveTo(50, 84)..lineTo(58, 79)..lineTo(58, 89)..close(), tie);
        c.drawCircle(const Offset(50, 84), 2.4, Paint()..color = const Color(0xFF2F8FDB));
      case Level.c1: // mortarboard
        final board = Paint()..color = const Color(0xFF2A2140);
        c.drawRect(const Rect.fromLTWH(40, 26, 20, 7), board);
        c.drawPath(Path()..moveTo(50, 18)..lineTo(68, 25)..lineTo(50, 31)..lineTo(32, 25)..close(), Paint()..color = const Color(0xFF3A2D58));
        c.drawLine(const Offset(50, 25), const Offset(64, 30), Paint()..color = const Color(0xFFE07BC0)..strokeWidth = 1.2);
        c.drawCircle(const Offset(64, 31), 1.8, Paint()..color = const Color(0xFFE07BC0));
      case null:
        break;
    }
  }

  void _zzz(Canvas c, double s) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 3; i++) {
      final v = (t + i / 3) % 1.0;
      tp.text = TextSpan(text: 'z', style: TextStyle(fontSize: (8 + v * 6) * s, fontWeight: FontWeight.w700, color: Color.fromRGBO(157, 176, 255, 1 - v)));
      tp.layout();
      tp.paint(c, Offset((70 + v * 14) * s, (34 - v * 24) * s));
    }
  }

  void _confetti(Canvas c, double s) {
    const colors = [_indigo, _tangerine, Color(0xFF3DDC97), Color(0xFFFFC24B)];
    final rnd = math.Random(7);
    for (var i = 0; i < 14; i++) {
      final x0 = rnd.nextDouble() * 100;
      final speed = 0.6 + rnd.nextDouble() * 0.6;
      final y = ((t * speed + rnd.nextDouble()) % 1.0) * 100;
      c.save();
      c.translate(x0 * s, y * s);
      c.rotate(t * 6 + i);
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: 4 * s, height: 2 * s), Paint()..color = colors[i % colors.length]);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(PicoPainter old) => old.t != t || old.mood != mood || old.level != level;
}
