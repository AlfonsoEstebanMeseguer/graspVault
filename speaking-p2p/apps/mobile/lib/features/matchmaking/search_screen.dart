// "Buscando pareja" (Design 2.0) + the 15 s prompt: concentric rings that
// search, you (A) next to a dashed "?" for whoever comes, the waiting clock, an
// exam tip on the obsidian card, and the quiet ways out.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../core/ui/kit.dart';
import '../../data/profile/profile_repository.dart';
import '../../domain/account/account.dart';
import '../../domain/exam/models.dart';
import '../exam/widgets/exam_widgets.dart' show formatMs;
import '../home/home_screen.dart' show levelName;
import 'matchmaking_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final m = ref.watch(matchmakingProvider);
    final ctrl = ref.read(matchmakingProvider.notifier);
    final name = ref.watch(myProfileProvider).value?.username ?? '?';
    final elapsed = m.startedAt == null ? 0 : DateTime.now().difference(m.startedAt!).inMilliseconds;
    // (part, tip): the part is shown above the tip; 0 = any part.
    final tips = [(2, l.tip1), (3, l.tip2), (0, l.tip3), (1, l.tip4)];
    final (tipPart, tip) = tips[(elapsed ~/ 12000) % tips.length];

    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.screen, 16, AppSpace.screen, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (m.level != null)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
                          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(30)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            LevelBadge(m.level!, size: 13),
                            const SizedBox(width: 10),
                            Text(l.fullExamOf(levelName(l, m.level!).split(' ').last),
                                style: AppType.headline.copyWith(fontSize: 15, color: p.textPrimary)),
                          ]),
                        ),
                      ),
                    SizedBox(height: 300, child: _Searching(initial: name.characters.first.toUpperCase())),
                    Text(l.searchingPartner, textAlign: TextAlign.center, style: AppType.title1.copyWith(fontSize: 28, color: p.textPrimary)),
                    const SizedBox(height: 4),
                    Text(formatMs(elapsed), textAlign: TextAlign.center, style: AppType.timer.copyWith(fontSize: 22, color: p.textSecondary)),
                    const SizedBox(height: 2),
                    Text(l.searchKeepsGoing, textAlign: TextAlign.center,
                        style: AppType.footnote.copyWith(color: p.textTertiary, fontWeight: FontWeight.w400, fontSize: 14)),
                    if (m.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(errorText(l, AppFailure(m.error!)), textAlign: TextAlign.center, style: AppType.body.copyWith(color: p.danger)),
                      ),
                    const SizedBox(height: 20),
                    PaperCard(
                      label: tipPart == 0 ? l.tipLabel : l.tipForPart(tipPart),
                      child: Text(tip, style: AppType.question.copyWith(fontSize: 20, height: 1.35, color: p.onPaper)),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      key: const Key('search-practice'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      onPressed: () async {
                        final level = m.level ?? Level.b2;
                        await ctrl.cancel();
                        if (context.mounted) context.go('/practice/${level.code}');
                      },
                      child: Text(l.practiceSimulated),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      key: const Key('search-cancel'),
                      style: TextButton.styleFrom(foregroundColor: p.textSecondary),
                      onPressed: () async {
                        await ctrl.cancel();
                        if (context.mounted) context.go('/');
                      },
                      child: Text(l.cancelSearch),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          if (m.showPrompt)
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: Glass(
                radius: AppRadii.card,
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(AppIcons.agenda, color: p.roleB),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.nobodySearchingTitle, style: AppType.headline.copyWith(color: p.textPrimary)),
                        const SizedBox(height: 2),
                        Text(l.nobodySearchingBody, style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400, fontSize: 14)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('prompt-no'),
                        style: OutlinedButton.styleFrom(backgroundColor: p.overlay),
                        onPressed: ctrl.dismissPrompt,
                        child: Text(l.noLabel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        key: const Key('prompt-yes'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                        onPressed: () {
                          ctrl.dismissPrompt();
                          context.go('/agenda?create=1');
                        },
                        child: Text(l.yesSchedule),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Rings that expand every 2 s around you (A) and the dashed "?" (B to come).
class _Searching extends StatefulWidget {
  const _Searching({required this.initial});
  final String initial;
  @override
  State<_Searching> createState() => _SearchingState();
}

class _SearchingState extends State<_Searching> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduce = MediaQuery.of(context).disableAnimations;
    const d = 96.0;
    return ExcludeSemantics(
      child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(painter: _Rings(reduce ? 0.5 : _c.value, p.brand, p.overlay)),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(d * 0.36, 0),
          child: CustomPaint(
            foregroundPainter: _DashedCircle(p.roleB),
            child: Container(
              width: d,
              height: d,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.roleBSoft),
              child: Text('?', style: AppType.largeTitle.copyWith(fontSize: 40, color: p.roleB)),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(-d * 0.36, 0),
          child: Container(
            width: d,
            height: d,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.roleA.withValues(alpha: 0.92)),
            child: Text(widget.initial, style: AppType.largeTitle.copyWith(fontSize: 40, color: p.onRole)),
          ),
        ),
      ]),
    );
  }
}

class _Rings extends CustomPainter {
  _Rings(this.t, this.color, this.rest);
  final double t;
  final Color color, rest;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.height * 0.36;
    for (final r in [base, base * 1.38]) {
      canvas.drawCircle(c, r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = rest);
    }
    final r = base * (0.6 + t * 0.95);
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.55 * (1 - t)));
  }

  @override
  bool shouldRepaint(_Rings old) => old.t != t || old.color != color;
}

class _DashedCircle extends CustomPainter {
  _DashedCircle(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    const n = 22;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * 3.141592653589793 / n;
      canvas.drawArc(rect.deflate(1.25), a, 0.16, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color;
}
