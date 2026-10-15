// Perfil (sketch 22): public profile, target level, exams done, recordings with
// days left (30-day retention), and the edit sheet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/ui/placeholder_screen.dart';
import '../../data/account/account_repository.dart';
import '../../data/profile/profile_repository.dart';
import '../../data/session/session_repository.dart';
import '../../domain/account/account.dart';
import '../../domain/exam/models.dart';
import '../agenda/agenda_common.dart' show InitialAvatar, Pill, agendaClockProvider, showError;
import '../home/home_screen.dart' show levelName, targetLevelProvider;
import '../onboarding/onboarding_screen.dart' show languageName;

final examsDoneProvider = FutureProvider.autoDispose<int>((ref) async => await ref.watch(accountRepositoryProvider)?.examsDone() ?? 0);
final recordingsProvider =
    FutureProvider.autoDispose<List<RecordingItem>>((ref) async => await ref.watch(accountRepositoryProvider)?.recordings() ?? const []);
final _partnerNameProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, id) async => (await ref.watch(sessionRepositoryProvider)?.publicProfile(id))?.username,
);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final profile = ref.watch(myProfileProvider).value;
    if (ref.watch(accountRepositoryProvider) == null || profile == null) return PlaceholderScreen(title: l.profileTitle);
    final now = ref.watch(agendaClockProvider)();
    final done = ref.watch(examsDoneProvider).value;
    final recs = ref.watch(recordingsProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    Widget stat(String label, String value) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary)),
              ]),
            ),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(examsDoneProvider);
            ref.invalidate(recordingsProvider);
          },
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Center(child: InitialAvatar(name: profile.username, size: 88)),
            const SizedBox(height: 10),
            Text(profile.username, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary)),
            const SizedBox(height: 8),
            Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
              for (final c in profile.languages) Chip(label: Text(languageName(l, c)), visualDensity: VisualDensity.compact),
            ]),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton(
                style: ButtonStyle(minimumSize: WidgetStateProperty.all(const Size(0, 40))),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => EditProfileSheet(profile: profile),
                ),
                child: Text(l.editProfile),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              stat(l.preparing, levelName(l, profile.targetLevel)),
              const SizedBox(width: 10),
              stat(l.examsDone, done?.toString() ?? '–'),
            ]),
            const SizedBox(height: 20),
            Text(l.recordingsTitle, style: TextStyle(fontSize: 12, color: p.textSecondary, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            ...recs.when(
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (_, _) => [Text(l.errorGeneric)],
              data: (list) => list.isEmpty
                  ? [Text(l.noRecordings, style: TextStyle(color: p.textSecondary))]
                  : [
                      for (final r in list)
                        Card(
                          child: ListTile(
                            leading: Icon(Icons.graphic_eq, color: p.brand),
                            title: Text(l.recordingWith(
                              r.level.code,
                              r.partnerId == null ? l.deletedUser : (ref.watch(_partnerNameProvider(r.partnerId!)).value ?? '…'),
                            )),
                            subtitle: Text(l.recordingMeta(
                              DateFormat('EEE d MMM', locale).format(r.startedAt.toLocal()),
                              r.duration.inMinutes,
                            )),
                            trailing: Text(l.daysLeft(r.daysLeft(now)),
                                style: TextStyle(fontWeight: FontWeight.w700, color: r.daysLeft(now) <= 5 ? p.danger : p.textSecondary)),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(l.playbackSoon, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                    ],
            ),
            const SizedBox(height: 6),
            Text(l.recordingsDeleted, style: TextStyle(fontSize: 12, color: p.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key, required this.profile});
  final MyProfile profile;
  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  static const _choices = ['es', 'en', 'ca', 'fr', 'it', 'de', 'pt'];
  late final _username = TextEditingController(text: widget.profile.username);
  late final Set<String> _langs = {...widget.profile.languages};
  late Level _level = widget.profile.targetLevel;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(accountRepositoryProvider)!.updateProfile(username: _username.text.trim(), languages: _langs.toList(), targetLevel: _level);
      await ref.read(targetLevelProvider.notifier).set(_level);
      ref.invalidate(myProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.profileSaved)));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final validName = Validators.username.hasMatch(_username.text.trim());
    final langs = {..._choices, ...widget.profile.languages}.toList();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(l.editProfile, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.textPrimary)),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.usernameLabel,
              prefixText: '@',
              border: const OutlineInputBorder(),
              errorText: validName ? null : l.usernameRules,
            ),
          ),
          const SizedBox(height: 12),
          Text(l.languagesYouSpeak, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final c in langs)
              Pill(
                label: languageName(l, c),
                selected: _langs.contains(c),
                onTap: () => setState(() => _langs.contains(c) ? _langs.remove(c) : _langs.add(c)),
              ),
          ]),
          const SizedBox(height: 12),
          Text(l.targetLevelField, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final lv in Level.values) Pill(label: lv.code, selected: _level == lv, onTap: () => setState(() => _level = lv)),
          ]),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy || !validName || _langs.isEmpty ? null : _save, child: Text(l.saveLabel)),
        ]),
      ),
    );
  }
}
