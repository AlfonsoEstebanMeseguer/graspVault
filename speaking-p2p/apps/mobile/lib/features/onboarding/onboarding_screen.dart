// Onboarding in three screens, as in the sketches (the eight steps of
// CLAUDE.md §3 in order): 1 public profile (username, languages),
// 2 private data (birth date, phone, email), 3 target level + terms.
// Avatar is optional and comes later from the profile (needs the photo picker).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/profile/profile_repository.dart';
import '../../domain/account/account.dart';
import '../../domain/exam/models.dart';
import '../home/home_screen.dart' show levelName;

const _mainLanguages = ['es', 'en', 'ca', 'fr', 'it'];
const _moreLanguages = ['de', 'pt', 'eu', 'gl', 'zh', 'ar', 'ru', 'uk', 'ro'];
const _phonePrefixes = ['+34', '+44', '+33', '+39', '+49', '+351', '+1', '+52', '+54', '+57'];

String languageName(AppLocalizations l, String code) => switch (code) {
      'es' => l.langEs,
      'en' => l.langEn,
      'ca' => l.langCa,
      'fr' => l.langFr,
      'it' => l.langIt,
      'de' => l.langDe,
      'pt' => l.langPt,
      'eu' => l.langEu,
      'gl' => l.langGl,
      'zh' => l.langZh,
      'ar' => l.langAr,
      'ru' => l.langRu,
      'uk' => l.langUk,
      'ro' => l.langRo,
      _ => code,
    };

enum _UsernameState { empty, invalid, checking, available, taken }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.today});

  /// Injected in tests so the age rule is deterministic.
  final DateTime? today;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _busy = false;
  String? _error;

  // step 1
  final _username = TextEditingController();
  _UsernameState _usernameState = _UsernameState.empty;
  Timer? _debounce;
  final Set<String> _languages = {};
  bool _showMoreLanguages = false;

  // step 2
  final _day = TextEditingController();
  final _month = TextEditingController();
  final _year = TextEditingController();
  final _phone = TextEditingController();
  String _prefix = '+34';

  // step 3
  Level? _level;
  bool _terms = false;

  DateTime get _today => widget.today ?? DateTime.now();

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_username, _day, _month, _year, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onUsernameChanged(String raw) {
    final v = raw.trim().toLowerCase();
    _debounce?.cancel();
    if (v.isEmpty) return setState(() => _usernameState = _UsernameState.empty);
    if (!Validators.username.hasMatch(v)) return setState(() => _usernameState = _UsernameState.invalid);
    setState(() => _usernameState = _UsernameState.checking);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final repo = ref.read(profileRepositoryProvider);
      final free = repo == null ? true : await repo.isUsernameAvailable(v).catchError((_) => true);
      if (!mounted || _username.text.trim().toLowerCase() != v) return;
      setState(() => _usernameState = free ? _UsernameState.available : _UsernameState.taken);
    });
  }

  DateTime? get _birth => Validators.date(int.tryParse(_day.text), int.tryParse(_month.text), int.tryParse(_year.text));

  String? get _phoneE164 {
    final digits = _phone.text.replaceAll(RegExp(r'[\s-]'), '');
    if (digits.isEmpty) return null;
    return '$_prefix$digits';
  }

  bool get _phoneValid => _phoneE164 == null || Validators.phone.hasMatch(_phoneE164!);

  bool get _canContinue => switch (_step) {
        0 => _usernameState == _UsernameState.available && _languages.isNotEmpty,
        1 => _birth != null && Validators.isOldEnough(_birth!, _today) && _phoneValid,
        _ => _level != null && _terms,
      };

  Future<void> _next() async {
    if (_step < 2) return setState(() => _step++);
    final repo = ref.read(profileRepositoryProvider);
    if (repo == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.completeOnboarding(OnboardingData(
        username: _username.text.trim().toLowerCase(),
        languages: _languages.toList(),
        targetLevel: _level!,
        birthDate: _birth!,
        phone: _phoneE164,
        termsVersion: termsVersion,
      ));
      ref.invalidate(myProfileProvider); // the router moves on when the profile exists
    } catch (e) {
      if (!mounted) return;
      final code = e is AppFailure ? e.code : '';
      setState(() {
        _error = errorText(context.l10n, e);
        if (code == 'username_taken' || code == 'conflict') {
          _step = 0;
          _usernameState = _UsernameState.taken;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final caption = [l.visibleToOthers, l.privateOnlyYou, l.canChangeLater][_step];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              for (var i = 0; i < 3; i++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(color: i <= _step ? p.brand : p.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                if (i < 2) const SizedBox(width: 6),
              ],
            ]),
            const SizedBox(height: 14),
            Row(children: [
              if (_step == 1) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.lock_outline, size: 14, color: p.textSecondary)),
              Flexible(child: Text('${l.stepOf(_step + 1)} · $caption', style: TextStyle(fontSize: 13, color: p.textSecondary))),
            ]),
            const SizedBox(height: 6),
            Expanded(child: SingleChildScrollView(child: [_publicStep, _privateStep, _levelStep][_step]())),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, key: const Key('onboarding-error'), style: TextStyle(color: p.danger)),
              ),
            Row(children: [
              if (_step > 0) ...[
                OutlinedButton(onPressed: _busy ? null : () => setState(() => _step--), child: Text(l.backLabel)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  key: const Key('onboarding-next'),
                  onPressed: _canContinue && !_busy ? _next : null,
                  child: _busy
                      ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: p.onBrand))
                      : Text(_step == 2 ? l.startLabel : l.continueLabel),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(t, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: context.palette.textPrimary)),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w600, color: context.palette.textPrimary)),
      );

  Widget _publicStep() {
    final p = context.palette;
    final l = context.l10n;
    final (helper, color) = switch (_usernameState) {
      _UsernameState.available => (l.usernameAvailable, p.success),
      _UsernameState.taken => (l.errorUsernameTaken, p.danger),
      _UsernameState.invalid => (l.usernameRules, p.danger),
      _ => (l.usernameRules, p.textSecondary),
    };
    final languages = [..._mainLanguages, if (_showMoreLanguages) ..._moreLanguages];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title(l.publicProfileTitle),
      _label(l.usernameLabel),
      TextField(
        key: const Key('onboarding-username'),
        controller: _username,
        autocorrect: false,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        onChanged: _onUsernameChanged,
        decoration: InputDecoration(
          prefixText: '@ ',
          border: const OutlineInputBorder(),
          suffixIcon: switch (_usernameState) {
            _UsernameState.available => Icon(Icons.check, color: p.success),
            _UsernameState.checking => const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)),
            _ => null,
          },
        ),
      ),
      Padding(padding: const EdgeInsets.only(top: 6, bottom: 18), child: Text(helper, style: TextStyle(fontSize: 12, color: color))),
      _label(l.languagesYouSpeak),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final code in languages)
          FilterChip(
            label: Text(languageName(l, code)),
            selected: _languages.contains(code),
            onSelected: (on) => setState(() => on ? _languages.add(code) : _languages.remove(code)),
          ),
        if (!_showMoreLanguages)
          ActionChip(label: Text(l.otherLanguage), onPressed: () => setState(() => _showMoreLanguages = true)),
      ]),
    ]);
  }

  Widget _privateStep() {
    final p = context.palette;
    final l = context.l10n;
    final email = ref.watch(authUserProvider).value?.email ?? '';
    final birth = _birth;
    final anyDate = _day.text.isNotEmpty && _month.text.isNotEmpty && _year.text.length == 4;
    final dateError = anyDate && birth == null
        ? l.invalidDate
        : (birth != null && !Validators.isOldEnough(birth, _today) ? l.errorUnderage : null);
    Widget num(TextEditingController c, String label, int max, Key key) => Expanded(
          flex: max == 4 ? 4 : 3,
          child: TextField(
            key: key,
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(max)],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title(l.accountDataTitle),
      _label(l.birthDate),
      Row(children: [
        num(_day, l.dayLabel, 2, const Key('onboarding-day')),
        const SizedBox(width: 8),
        num(_month, l.monthLabel, 2, const Key('onboarding-month')),
        const SizedBox(width: 8),
        num(_year, l.yearLabel, 4, const Key('onboarding-year')),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 18),
        child: Text(dateError ?? l.minAgeHint, style: TextStyle(fontSize: 12, color: dateError == null ? p.textSecondary : p.danger)),
      ),
      _label(l.phoneOptional),
      Row(children: [
        DropdownButton<String>(
          value: _prefix,
          items: [for (final x in _phonePrefixes) DropdownMenuItem(value: x, child: Text(x))],
          onChanged: (v) => setState(() => _prefix = v ?? _prefix),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            key: const Key('onboarding-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 -]'))],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(border: const OutlineInputBorder(), errorText: _phoneValid ? null : l.invalidPhone),
          ),
        ),
      ]),
      const SizedBox(height: 18),
      _label(l.emailLabel),
      TextField(
        controller: TextEditingController(text: email),
        enabled: false,
        decoration: InputDecoration(border: const OutlineInputBorder(), filled: true, fillColor: p.surfaceMuted),
      ),
      Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.linkedToAccount, style: TextStyle(fontSize: 12, color: p.textSecondary))),
    ]);
  }

  Widget _levelStep() {
    final p = context.palette;
    final l = context.l10n;
    const minutes = {Level.b1: '12–17', Level.b2: '14', Level.c1: '15'};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title(l.whichExamTitle),
      RadioGroup<Level>(
        groupValue: _level,
        onChanged: (v) => setState(() => _level = v),
        child: Column(children: [
          for (final lv in Level.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                key: Key('onboarding-level-${lv.code}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _level = lv),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _level == lv ? p.brandSoft : p.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _level == lv ? p.brand : p.border, width: _level == lv ? 2 : 1),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _level == lv ? p.brand : p.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(lv.code, style: TextStyle(fontWeight: FontWeight.w700, color: _level == lv ? p.onBrand : p.textPrimary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(levelName(l, lv), style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                        Text(l.speakingMinutes(minutes[lv]!), style: TextStyle(fontSize: 12, color: p.textSecondary)),
                      ]),
                    ),
                    Radio<Level>(value: lv),
                  ]),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      CheckboxListTile(
        key: const Key('onboarding-terms'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _terms,
        onChanged: (v) => setState(() => _terms = v ?? false),
        title: Text(l.acceptTerms, style: TextStyle(fontSize: 13, color: p.textPrimary)),
      ),
    ]);
  }
}
