// Perfil (Design 2.0, bento): public profile, target level, exams done, the
// feedback partners gave me (rubric averages, D-042), and the recordings with
// an explicit expiry ("se borra en 28 días"). Plus the edit sheet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../core/ui/kit.dart';
import '../../core/ui/pico.dart';
import '../../core/ui/placeholder_screen.dart';
import '../../data/account/account_repository.dart';
import '../../data/profile/profile_repository.dart';
import '../../data/session/session_repository.dart';
import '../../domain/account/account.dart';
import '../../domain/exam/models.dart';
import '../../domain/feedback/peer_rating.dart';
import '../agenda/agenda_common.dart' show Pill, agendaClockProvider, showError;
import '../home/home_screen.dart' show levelName, targetLevelProvider;
import '../onboarding/onboarding_screen.dart' show languageName;
import 'avatar/avatar_sheet.dart';
import 'avatar/user_avatar.dart';

final examsDoneProvider = FutureProvider.autoDispose<int>((ref) async => await ref.watch(accountRepositoryProvider)?.examsDone() ?? 0);
final recordingsProvider =
    FutureProvider.autoDispose<List<RecordingItem>>((ref) async => await ref.watch(accountRepositoryProvider)?.recordings() ?? const []);
final feedbackReceivedProvider = FutureProvider.autoDispose<FeedbackSummary>(
    (ref) async => await ref.watch(accountRepositoryProvider)?.feedbackReceived() ?? const FeedbackSummary());
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
    final feedback = ref.watch(feedbackReceivedProvider).value;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(examsDoneProvider);
            ref.invalidate(recordingsProvider);
            ref.invalidate(feedbackReceivedProvider);
          },
          child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.screen, 16, AppSpace.screen, 120), children: [
            Row(children: [
              Semantics(
                button: true,
                label: l.avatarTitle,
                child: InkWell(
                  key: const Key('profile-avatar'),
                  customBorder: const CircleBorder(),
                  onTap: () => AvatarSheet.show(context, hasPhoto: profile.avatarKey != null),
                  child: Stack(clipBehavior: Clip.none, children: [
                    UserAvatar(name: profile.username, userId: profile.id, avatarKey: profile.avatarKey, size: 84, background: p.roleA, foreground: p.onRole),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: p.brand, shape: BoxShape.circle, border: Border.all(color: p.background, width: 3)),
                        child: Icon(AppIcons.camera, size: 14, color: p.onBrand),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(profile.username, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.title1.copyWith(color: p.textPrimary)),
                  const SizedBox(height: 4),
                  Text(profile.languages.map((c) => languageName(l, c)).join(' · '),
                      style: AppType.body.copyWith(fontSize: 15, color: p.textSecondary)),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => EditProfileSheet(profile: profile),
                    ),
                    child: Text(l.editProfile),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 22),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: Tile(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.preparing, style: AppType.footnote.copyWith(color: p.textSecondary)),
                      const SizedBox(height: 10),
                      LevelBadge(profile.targetLevel, size: 18),
                      const SizedBox(height: 8),
                      Text(levelName(l, profile.targetLevel), style: AppType.headline.copyWith(color: p.textPrimary)),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Tile(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.examsDone, style: AppType.footnote.copyWith(color: p.textSecondary)),
                      const Spacer(),
                      Text(done?.toString() ?? '–', style: AppType.largeTitle.copyWith(fontSize: 44, height: 1, color: p.textPrimary)),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            _FeedbackTile(summary: feedback),
            const SizedBox(height: 24),
            Overline(l.recordingsTitle),
            const SizedBox(height: 10),
            ...recs.when(
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (_, _) => [Text(l.errorGeneric)],
              data: (list) => list.isEmpty
                  ? [
                      Tile(
                        padding: const EdgeInsets.all(18),
                        child: Row(children: [
                          const Pico(size: 64, mood: PicoMood.sleep),
                          const SizedBox(width: 14),
                          Expanded(child: Text(l.noRecordings, style: AppType.body.copyWith(fontSize: 15, color: p.textSecondary))),
                        ]),
                      ),
                    ]
                  : [
                      for (final r in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Tile(
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(color: p.roleBSoft, shape: BoxShape.circle),
                                child: Icon(AppIcons.practice, color: p.roleB),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(
                                    l.recordingWith(
                                      r.level.code,
                                      r.partnerId == null ? l.aPartner : (ref.watch(_partnerNameProvider(r.partnerId!)).value ?? '…'),
                                    ),
                                    style: AppType.headline.copyWith(color: p.textPrimary),
                                  ),
                                  Text(
                                    l.recordingMeta(DateFormat('EEE d MMM', locale).format(r.startedAt.toLocal()), r.duration.inMinutes),
                                    style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400),
                                  ),
                                ]),
                              ),
                              Text(l.deletesIn(r.daysLeft(now)),
                                  style: AppType.footnote.copyWith(color: r.daysLeft(now) <= 5 ? p.danger : p.textTertiary)),
                            ]),
                          ),
                        ),
                      Text(l.playbackSoon, style: AppType.footnote.copyWith(color: p.textTertiary, fontWeight: FontWeight.w400)),
                    ],
            ),
            const SizedBox(height: 4),
            Text(l.recordingsDeleted, style: AppType.footnote.copyWith(color: p.textTertiary, fontWeight: FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}

/// "Lo que dicen de ti": the rubric averages, as four bars.
class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.summary});
  final FeedbackSummary? summary;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final s = summary;
    final names = {
      Criterion.grammar: l.criterionGrammar,
      Criterion.discourse: l.criterionDiscourse,
      Criterion.pronunciation: l.criterionPronunciation,
      Criterion.interaction: l.criterionInteraction,
    };
    return Tile(
      key: const Key('profile-feedback'),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(l.feedbackReceived, style: AppType.headline.copyWith(color: p.textPrimary))),
          if (s != null && s.count > 0) Text(l.ratingsCount(s.count), style: AppType.footnote.copyWith(color: p.textTertiary)),
        ]),
        const SizedBox(height: 4),
        if (s == null || s.count == 0)
          Text(l.feedbackReceivedEmpty, style: AppType.body.copyWith(fontSize: 15, color: p.textSecondary))
        else
          for (final c in Criterion.values)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Expanded(flex: 5, child: Text(names[c]!, style: AppType.footnote.copyWith(fontSize: 14, color: p.textPrimary))),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (s.averages[c] ?? 0) / PeerRating.max,
                      minHeight: 8,
                      color: p.roleA,
                      backgroundColor: p.overlay,
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(s.averages[c] == null ? '–' : s.averages[c]!.toStringAsFixed(1),
                      textAlign: TextAlign.end, style: AppType.timer.copyWith(fontSize: 14, color: p.textSecondary)),
                ),
              ]),
            ),
      ]),
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
          Text(l.editProfile, style: AppType.title2.copyWith(color: p.textPrimary)),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.usernameLabel,
              prefixText: '@',
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
