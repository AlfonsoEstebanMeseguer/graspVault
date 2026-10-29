// "Reportar o bloquear a …" (D-044), reachable from the chat, the lobby, the
// exam, the feedback and the Agenda board. Plus the list of blocked users.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../core/ui/kit.dart';
import '../../data/safety/safety_repository.dart';
import '../../data/session/session_repository.dart';

/// Opens the sheet; returns true if the user blocked [name].
Future<bool> showSafetySheet(
  BuildContext context, {
  required String userId,
  required String name,
  required ReportContext where,
  String? sessionId,
  String? chatId,
}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SafetySheet(userId: userId, name: name, where: where, sessionId: sessionId, chatId: chatId),
  );
  return r ?? false;
}

class _SafetySheet extends ConsumerStatefulWidget {
  const _SafetySheet({required this.userId, required this.name, required this.where, this.sessionId, this.chatId});
  final String userId;
  final String name;
  final ReportContext where;
  final String? sessionId;
  final String? chatId;
  @override
  ConsumerState<_SafetySheet> createState() => _SafetySheetState();
}

class _SafetySheetState extends ConsumerState<_SafetySheet> {
  ReportReason? _reason;
  final _details = TextEditingController();
  bool _alsoBlock = true;
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(SafetyRepository r) action, String done, {bool blocked = false}) async {
    final repo = ref.read(safetyRepositoryProvider);
    if (repo == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      await action(repo);
      ref.invalidate(blockedUsersProvider);
      if (!mounted) return;
      Navigator.of(context).pop(blocked);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  Future<void> _blockOnly() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.blockTitle(widget.name)),
        content: Text(l.blockBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancelLabel)),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: context.palette.danger, foregroundColor: context.palette.onDanger),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.blockAction),
          ),
        ],
      ),
    );
    if (ok == true) await _run((r) => r.block(widget.userId), l.blockedDone(widget.name), blocked: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final reasons = {
      // Sabotage needs the session it happened in (D-051): first, when there is one.
      if (widget.sessionId != null) ...{
        ReportReason.silent: l.reasonSilent,
        ReportReason.mocking: l.reasonMocking,
        ReportReason.noise: l.reasonNoise,
        ReportReason.quit: l.reasonQuit,
        ReportReason.controlAbuse: l.reasonControlAbuse,
      },
      ReportReason.harassment: l.reasonHarassment,
      ReportReason.sexual: l.reasonSexual,
      ReportReason.hate: l.reasonHate,
      ReportReason.minorSafety: l.reasonMinor,
      ReportReason.spam: l.reasonSpam,
      ReportReason.noShow: l.reasonNoShow,
      ReportReason.other: l.reasonOther,
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(AppSpace.screen, 0, AppSpace.screen, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(l.reportTitle(widget.name), style: AppType.title2.copyWith(color: p.textPrimary)),
          const SizedBox(height: 6),
          Text(l.reportIntro(widget.name), style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400, fontSize: 14)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final MapEntry(key: r, value: label) in reasons.entries)
              ChoiceChip(key: Key('report-${r.wire}'), label: Text(label), selected: _reason == r, onSelected: (_) => setState(() => _reason = r)),
          ]),
          const SizedBox(height: 14),
          TextField(
            key: const Key('report-details'),
            controller: _details,
            maxLength: 1000,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(hintText: l.reportDetailsHint),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _alsoBlock,
            onChanged: (v) => setState(() => _alsoBlock = v),
            title: Text(l.alsoBlock(widget.name), style: AppType.body.copyWith(color: p.textPrimary)),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('report-send'),
            style: FilledButton.styleFrom(backgroundColor: p.danger, foregroundColor: p.onDanger),
            onPressed: _busy || _reason == null
                ? null
                : () => _run((r) async {
                      await r.report(widget.userId, _reason!,
                          details: _details.text, context: widget.where, sessionId: widget.sessionId, chatId: widget.chatId);
                      if (_alsoBlock) await r.block(widget.userId);
                    }, l.reportSent, blocked: _alsoBlock),
            child: Text(l.reportSend),
          ),
          const SizedBox(height: 6),
          TextButton(
            key: const Key('block-only'),
            style: TextButton.styleFrom(foregroundColor: p.textSecondary),
            onPressed: _busy ? null : _blockOnly,
            child: Text(l.blockOnly(widget.name)),
          ),
        ]),
      ),
    );
  }
}

/// Ajustes > Usuarios bloqueados.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final l = context.l10n;
    final list = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.blockedUsers)),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l.errorGeneric)),
        data: (ids) => ids.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(l.noBlockedUsers, textAlign: TextAlign.center, style: AppType.body.copyWith(color: p.textSecondary))))
            : ListView(padding: const EdgeInsets.all(AppSpace.screen), children: [
                for (final id in ids)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Tile(
                      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                      child: Row(children: [
                        Expanded(
                          child: FutureBuilder(
                            future: ref.read(sessionRepositoryProvider)?.publicProfile(id),
                            builder: (_, snap) => Text(snap.data?.username ?? l.aPartner, style: AppType.headline.copyWith(color: p.textPrimary)),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await ref.read(safetyRepositoryProvider)?.unblock(id);
                            ref.invalidate(blockedUsersProvider);
                          },
                          child: Text(l.unblockAction),
                        ),
                      ]),
                    ),
                  ),
              ]),
      ),
    );
  }
}
