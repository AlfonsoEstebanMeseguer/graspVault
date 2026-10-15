import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/preferences.dart';
import '../../core/l10n/errors.dart';
import '../../data/account/account_repository.dart';
import '../../data/auth/auth_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final l = context.l10n;
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider) ?? Localizations.localeOf(context);
    Widget section(String t) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(t, style: TextStyle(fontSize: 12, color: p.textSecondary, letterSpacing: 0.4)),
        );
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(l.settingsTitle, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: p.textPrimary)),
          section(l.appearance),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)),
              ButtonSegment(value: ThemeMode.system, label: Text(l.themeSystem)),
            ],
            selected: {mode},
            onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
          ),
          section(l.appLanguage),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'es', label: Text(l.languageSpanish)),
              ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
            ],
            selected: {locale.languageCode},
            onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(Locale(s.first)),
          ),
          section(l.subscription),
          const _SubscriptionCard(),
          section(l.account),
          if (ref.watch(authUserProvider).value == null)
            Text(l.needsBackend, style: TextStyle(color: p.textSecondary))
          else
            Card(
              child: Column(children: [
                ListTile(
                  title: Text(l.signOut),
                  onTap: () => ref.read(authRepositoryProvider).signOut(),
                ),
                if (ref.watch(accountRepositoryProvider) != null)
                  ListTile(
                    title: Text(l.deleteAccount, style: TextStyle(color: p.danger)),
                    onTap: () => showDialog<void>(context: context, builder: (_) => const DeleteAccountDialog()),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}

final entitlementProvider = FutureProvider.autoDispose<Entitlement?>((ref) async => ref.watch(accountRepositoryProvider)?.entitlement());

/// Status only until RevenueCat lands (D-020): no button that pretends to manage the store.
class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    if (ref.watch(accountRepositoryProvider) == null) return Text(l.needsBackend, style: TextStyle(color: p.textSecondary));
    final e = ref.watch(entitlementProvider).value;
    final active = e?.active(DateTime.now()) ?? false;
    final trialLeft = e != null && !active && e.trialUsedAt == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(l.planMonthly, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(active ? l.subActive : (trialLeft ? l.trialAvailable : l.subInactive),
                style: TextStyle(fontWeight: FontWeight.w700, color: active ? p.success : p.textSecondary)),
          ]),
          // A far-future period end is the "everyone has paid" dev switch: no fake date.
          if (active && e!.periodEnd != null && e.periodEnd!.year < 2100) ...[
            const SizedBox(height: 6),
            Text('${l.nextPayment} · ${MaterialLocalizations.of(context).formatMediumDate(e.periodEnd!.toLocal())} · 8,00 €',
                style: TextStyle(color: p.textSecondary)),
          ],
          const SizedBox(height: 6),
          Text(l.storeLater, style: TextStyle(fontSize: 12, color: p.textSecondary)),
        ]),
      ),
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
            decoration: InputDecoration(labelText: l.yourPassword, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phrase,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: l.deletePhraseHint(l.deletePhrase), border: const OutlineInputBorder()),
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
