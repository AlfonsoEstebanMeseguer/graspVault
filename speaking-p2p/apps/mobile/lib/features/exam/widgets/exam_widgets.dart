import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theming/palette.dart';
import '../../../domain/exam/models.dart';

String formatMs(int ms) {
  final s = (ms / 1000).ceil().clamp(0, 99 * 60);
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Part progress bars + "PARTE n DE 4" + title + timer pill with hide/show.
class ExamHeader extends StatelessWidget {
  const ExamHeader({
    super.key,
    required this.partIndex,
    required this.title,
    required this.remainingMs,
    required this.timerVisible,
    required this.onToggleTimer,
  });

  final int partIndex;
  final String title;
  final int remainingMs;
  final bool timerVisible;
  final VoidCallback onToggleTimer;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        for (var i = 1; i <= 4; i++) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i <= partIndex ? p.brand : p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < 4) const SizedBox(width: 6),
        ],
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.partOf(partIndex), style: TextStyle(fontSize: 12, color: p.textSecondary, letterSpacing: 0.4)),
            Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary)),
          ]),
        ),
        if (timerVisible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: p.timerFill, borderRadius: BorderRadius.circular(20)),
            child: Text(formatMs(remainingMs),
                style: TextStyle(
                    color: p.onTimerFill, fontSize: 18, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        IconButton(
          tooltip: timerVisible ? l.hideTimer : l.showTimer,
          onPressed: onToggleTimer,
          icon: Icon(timerVisible ? Icons.timer_outlined : Icons.timer_off_outlined, color: p.textSecondary),
        ),
      ]),
    ]);
  }
}

class ParticipantInfo {
  const ParticipantInfo({required this.name, required this.role, required this.isMe});
  final String name;
  final Role role;
  final bool isMe;
}

/// Big candidate card (Parts 1, 2 and 4). Both devices show the same highlight.
class ParticipantCard extends StatelessWidget {
  const ParticipantCard({super.key, required this.info, required this.active, required this.micOn, this.compact = false});

  final ParticipantInfo info;
  final bool active;
  final bool micOn;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final name = info.isMe ? l.you : info.name;
    final status = micOn ? (active ? l.statusSpeaking : l.statusMicOpen) : l.statusMuted;
    final avatar = CircleAvatar(
      radius: compact ? 14 : 30,
      backgroundColor: active || info.isMe ? p.brand : p.surfaceMuted,
      child: Text(info.name.characters.first.toUpperCase(),
          style: TextStyle(color: active || info.isMe ? p.onBrand : p.textSecondary, fontWeight: FontWeight.w700, fontSize: compact ? 13 : 22)),
    );
    final label = Text(l.roleLabel(name, info.role.code),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w600, color: active ? p.textPrimary : p.textSecondary));
    final statusRow = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(micOn ? Icons.mic : Icons.mic_off, size: 14, color: micOn ? p.onBrandSoft : p.textSecondary),
      const SizedBox(width: 4),
      Flexible(
        child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: micOn ? p.onBrandSoft : p.textSecondary)),
      ),
    ]);
    return Semantics(
      label: '${l.roleLabel(name, info.role.code)}, $status',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(compact ? 10 : 16),
        decoration: BoxDecoration(
          color: active ? p.brandSoft : p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? p.brand : p.border, width: active ? 2 : 1),
        ),
        child: compact
            ? Row(children: [avatar, const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [label, statusRow]))])
            : Opacity(
                opacity: active || micOn ? 1 : 0.6,
                child: Column(children: [avatar, const SizedBox(height: 10), label, const SizedBox(height: 4), statusRow]),
              ),
      ),
    );
  }
}

/// What the reader says in the current step; the text can be hidden.
class ExaminerCard extends StatelessWidget {
  const ExaminerCard({super.key, required this.text, required this.visible, required this.onToggle, this.addressee, this.title});

  final String text;
  final bool visible;
  final VoidCallback onToggle;
  final String? addressee;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (addressee != null)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: p.brandSoft, borderRadius: BorderRadius.circular(8)),
                    child: Text(addressee!,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.onBrandSoft, fontWeight: FontWeight.w600)),
                  ),
                ),
              )
            else ...[
              Icon(Icons.volume_up_outlined, size: 18, color: p.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title ?? l.examiner,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
              ),
            ],
            const SizedBox(width: 8),
            // Natural width, capped: the label wins space only up to 45 % of the row.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.45),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 40)),
                onPressed: onToggle,
                child: Text(visible ? l.hideText : l.showText, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
          if (visible) ...[
            const SizedBox(height: 12),
            Text(text, style: TextStyle(fontSize: 18, height: 1.35, color: p.textPrimary)),
          ],
        ]),
      ),
    );
  }
}

/// Photos are not bundled; until R2 assets exist this shows a labelled tile.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.assets, this.imageUrlFor});
  final List<String> assets;
  final String? Function(String assetId)? imageUrlFor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget tile(String id) {
      final url = imageUrlFor?.call(id);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: p.surfaceMuted,
          alignment: Alignment.center,
          child: url == null
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.image_outlined, color: p.textSecondary),
                  const SizedBox(height: 4),
                  Text(context.l10n.photoPlaceholder(id), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                ])
              : Image.network(url, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: assets.length == 1 ? 4 / 3 : 1.6,
      child: switch (assets.length) {
        1 => tile(assets[0]),
        2 => Row(children: [Expanded(child: tile(assets[0])), const SizedBox(width: 8), Expanded(child: tile(assets[1]))]),
        _ => Column(children: [
            Expanded(child: Row(children: [Expanded(child: tile(assets[0])), const SizedBox(width: 8), Expanded(child: tile(assets[1]))])),
            const SizedBox(height: 8),
            Expanded(child: tile(assets[2])),
          ]),
      },
    );
  }
}

/// "¿Seguro que quieres salir?" with the confirm button locked for 5 s.
Future<bool> showAbandonSheet(BuildContext context, {required String partnerName}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AbandonSheet(partnerName: partnerName),
  );
  return r ?? false;
}

class _AbandonSheet extends StatefulWidget {
  const _AbandonSheet({required this.partnerName});
  final String partnerName;
  @override
  State<_AbandonSheet> createState() => _AbandonSheetState();
}

class _AbandonSheetState extends State<_AbandonSheet> {
  static const lockSeconds = 5;
  int _left = lockSeconds;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    while (_left > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _left--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.logout, color: p.danger),
          const SizedBox(height: 12),
          Text(l.abandonTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.textPrimary)),
          const SizedBox(height: 8),
          Text(l.abandonBody(widget.partnerName), style: TextStyle(color: p.textSecondary)),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.timerFill, foregroundColor: p.onTimerFill),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.keepGoing),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('abandon-confirm'),
            style: FilledButton.styleFrom(backgroundColor: p.danger, foregroundColor: p.onDanger),
            onPressed: _left > 0 ? null : () => Navigator.pop(context, true),
            child: Text(_left > 0 ? l.leaveExamIn(_left) : l.leaveExam),
          ),
        ]),
      ),
    );
  }
}
