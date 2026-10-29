// Ajustes (Design 2.0): grouped list; appearance and language as segmented
// controls; the subscription with a Standard / Pro comparison.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/preferences.dart';
import '../../core/theming/tokens.dart';
import '../../core/ui/kit.dart';
import '../../core/l10n/errors.dart';
import '../../data/account/account_repository.dart';
import '../../data/auth/auth_repository.dart';
import '../legal/legal_screen.dart' show LegalDoc, LegalDocAsset;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final l = context.l10n;
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider) ?? Localizations.localeOf(context);
    Widget section(String t) => Padding(padding: const EdgeInsets.only(top: 26, bottom: 10, left: 4), child: Overline(t));
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.screen, 16, AppSpace.screen, 120), children: [
          ScreenTitle(l.settingsTitle),
          section(l.appearance),
          AppSegmented<ThemeMode>(
            items: [
              SegmentItem(ThemeMode.light, l.themeLight),
              SegmentItem(ThemeMode.dark, l.themeDark),
              SegmentItem(ThemeMode.system, l.themeSystem),
            ],
            selected: mode,
            onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
          ),
          section(l.appLanguage),
          AppSegmented<String>(
            items: [SegmentItem('es', l.languageSpanish), SegmentItem('en', l.languageEnglish)],
            selected: locale.languageCode,
            onChanged: (c) => ref.read(localeProvider.notifier).set(Locale(c)),
          ),
          section(l.subscription),
          const _SubscriptionCard(),
          section(l.account),
          if (ref.watch(authUserProvider).value == null)
            Text(l.needsBackend, style: AppType.body.copyWith(color: p.textSecondary))
          else
            Tile(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(
                  leading: Icon(AppIcons.leave, color: p.textSecondary),
                  title: Text(l.signOut),
                  onTap: () => ref.read(authRepositoryProvider).signOut(),
                ),
                if (ref.watch(accountRepositoryProvider) != null) ...[
                  Divider(height: 1, indent: 56, color: p.border),
                  ListTile(
                    leading: Icon(AppIcons.trash, color: p.danger),
                    title: Text(l.deleteAccount, style: AppType.body.copyWith(color: p.danger)),
                    onTap: () => showDialog<void>(context: context, builder: (_) => const DeleteAccountDialog()),
                  ),
                ],
              ]),
            ),
          section(l.legalSection),
          Tile(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                key: const Key('settings-terms'),
                leading: Icon(AppIcons.books, color: p.textSecondary),
                title: Text(l.termsOfUse),
                trailing: Icon(AppIcons.caretRight, size: 16, color: p.textTertiary),
                onTap: () => context.push(LegalDoc.terms.path),
              ),
              Divider(height: 1, indent: 56, color: p.border),
              ListTile(
                key: const Key('settings-privacy'),
                leading: Icon(AppIcons.lock, color: p.textSecondary),
                title: Text(l.privacyPolicy),
                trailing: Icon(AppIcons.caretRight, size: 16, color: p.textTertiary),
                onTap: () => context.push(LegalDoc.privacy.path),
              ),
              if (ref.watch(authUserProvider).value != null) ...[
                Divider(height: 1, indent: 56, color: p.border),
                ListTile(
                  key: const Key('settings-blocked'),
                  leading: Icon(AppIcons.close, color: p.textSecondary),
                  title: Text(l.blockedUsers),
                  trailing: Icon(AppIcons.caretRight, size: 16, color: p.textTertiary),
                  onTap: () => context.push('/blocked'),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 18),
          Text(l.notAffiliated, textAlign: TextAlign.center, style: AppType.footnote.copyWith(color: p.textTertiary, fontWeight: FontWeight.w400)),
        ]),
      ),
    );
  }
}

final entitlementProvider = FutureProvider.autoDispose<Entitlement?>((ref) async => ref.watch(accountRepositoryProvider)?.entitlement());

// Store prices arrive with RevenueCat (D-020); until then, the plan prices.
const _standardPrice = '8,00 €';
const _proPrice = '10,00 €';

/// What Pro adds (D-037). The purchase button waits for the store.
class _ProSheet extends StatelessWidget {
  const _ProSheet();
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpace.screen, 0, AppSpace.screen, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: p.pro.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: Icon(AppIcons.crown, color: p.pro),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(l.proTitle, style: AppType.title2.copyWith(color: p.textPrimary))),
          ]),
          const SizedBox(height: 6),
          Text(l.proPrice, style: AppType.body.copyWith(color: p.textSecondary)),
          const SizedBox(height: 14),
          for (final f in [l.proFeature1, l.proFeature2, l.proFeature3, l.proFeature4])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(AppIcons.checkCircle, size: 20, color: p.success),
                const SizedBox(width: 12),
                Expanded(child: Text(f, style: AppType.body.copyWith(color: p.textPrimary))),
              ]),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: null, child: Text(l.proStoreSoon)),
        ]),
      ),
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    if (ref.watch(accountRepositoryProvider) == null) return Text(l.needsBackend, style: AppType.body.copyWith(color: p.textSecondary));
    final e = ref.watch(entitlementProvider).value;
    final active = e?.active(DateTime.now()) ?? false;
    final pro = e?.isPro(DateTime.now()) ?? false;
    final trialLeft = e != null && !active && e.trialUsedAt == null;
    Widget plan(String name, String price, List<String> features, {required bool current, required bool isPro}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.input + 2),
              border: Border.all(color: current ? (isPro ? p.pro : p.brand) : Colors.transparent, width: 2),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (isPro) ...[Icon(AppIcons.crown, size: 14, color: p.pro), const SizedBox(width: 6)],
                Flexible(child: Text(name, style: AppType.headline.copyWith(fontSize: 15, color: p.textPrimary))),
              ]),
              Text(l.perMonth(price), style: AppType.footnote.copyWith(color: p.textSecondary)),
              const SizedBox(height: 8),
              for (final f in features)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('· $f', style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400)),
                ),
            ]),
          ),
        );
    return Tile(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(active ? (pro ? l.planPro : l.planStandard) : l.planMonthly,
                style: AppType.headline.copyWith(color: p.textPrimary)),
          ),
          StatusDot(
            text: active ? l.subActive : (trialLeft ? l.trialAvailable : l.subInactive),
            color: active ? p.success : p.textSecondary,
            style: AppType.footnote.copyWith(fontWeight: FontWeight.w700),
          ),
        ]),
        // A far-future period end is the "everyone has paid" dev switch: no fake date.
        if (active && e!.periodEnd != null && e.periodEnd!.year < 2100) ...[
          const SizedBox(height: 6),
          Text('${l.nextPayment} · ${MaterialLocalizations.of(context).formatMediumDate(e.periodEnd!.toLocal())} · ${pro ? _proPrice : _standardPrice}',
              style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400)),
        ],
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            plan(l.planStandardShort, _standardPrice, [l.planStdFeature1, l.planStdFeature2], current: active && !pro, isPro: false),
            const SizedBox(width: 10),
            plan(l.planProShort, _proPrice, [l.planProFeature1, l.planProFeature2], current: pro, isPro: true),
          ]),
        ),
        if (!pro) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('upgrade-pro'),
            style: FilledButton.styleFrom(backgroundColor: p.pro, foregroundColor: p.onRole),
            onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => const _ProSheet()),
            icon: const Icon(AppIcons.crown, size: 18),
            label: Text(l.upgradePro),
          ),
        ],
      ]),
    );
  }
}

/// Irreversible: password again (fresh session, the server checks < 5 min)
/// plus the phrase ELIMINAR / DELETE, which the server checks as well.
class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});
  @override
  ConsumerState<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _password = TextEditingController();
  final _phrase = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _phrase.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider)!.deleteAccount(password: _password.text, phrase: _phrase.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(context.l10n, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final phraseOk = _phrase.text.trim().toUpperCase() == l.deletePhrase;
    return AlertDialog(
      title: Text(l.deleteAccount),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.deleteAccountBody),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l.yourPassword),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phrase,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: l.deletePhraseHint(l.deletePhrase)),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: p.danger))),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l.cancelLabel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: p.danger, foregroundColor: p.onDanger, minimumSize: const Size(0, 40)),
          onPressed: _busy || !phraseOk || _password.text.isEmpty ? null : _delete,
          child: Text(l.deleteForever),
        ),
      ],
    );
  }
}
