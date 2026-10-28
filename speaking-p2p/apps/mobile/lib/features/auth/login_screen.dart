// Welcome / login (Design 2.0 "Bienvenida"): brand, A–B hero with Pico, the
// promise, the level as a segmented control, then the ways in. Email +
// password is what works today (DECISIONS D-022); Apple and Google are drawn
// but not wired yet, so they say so instead of failing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/kit.dart';
import '../../core/ui/pico.dart';
import '../../data/auth/auth_repository.dart';
import '../../domain/exam/models.dart';
import '../home/home_screen.dart' show targetLevelProvider;
import '../legal/legal_screen.dart' show LegalDoc, LegalDocAsset;

enum _Mode { welcome, signIn, signUp }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Mode _mode = _Mode.welcome;
  bool _busy = false;
  bool _showPassword = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _go(_Mode m) => setState(() {
        _mode = m;
        _message = null;
      });

  /// Apple and Google: the buttons exist, the providers are not connected yet.
  void _soon(String provider) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.providerSoon(provider))));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final l = context.l10n;
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_mode == _Mode.signUp) {
        final outcome = await repo.signUp(_email.text, _password.text);
        if (outcome == SignUpOutcome.confirmEmail) setState(() => _message = l.checkYourEmail);
      } else {
        await repo.signIn(_email.text, _password.text);
      }
      // Navigation happens in the router redirect when the session changes.
    } catch (e) {
      setState(() => _message = errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _mode == _Mode.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_Mode.welcome);
      },
      child: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: AppMotion.smooth,
            switchInCurve: AppMotion.curve,
            child: _mode == _Mode.welcome ? _welcome() : _emailForm(),
          ),
        ),
      ),
    );
  }

  Widget _providers() {
    final l = context.l10n;
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FilledButton.icon(
        key: const Key('login-apple'),
        style: FilledButton.styleFrom(backgroundColor: p.inverse, foregroundColor: p.onInverse),
        onPressed: () => _soon('Apple'),
        icon: const Icon(AppIcons.apple, size: 22),
        label: Text(l.continueWithApple),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        key: const Key('login-google'),
        style: FilledButton.styleFrom(backgroundColor: p.surfaceMuted, foregroundColor: p.textPrimary),
        onPressed: () => _soon('Google'),
        icon: const Icon(AppIcons.google, size: 20),
        label: Text(l.continueWithGoogle),
      ),
    ]);
  }

  Widget _welcome() {
    final l = context.l10n;
    final p = context.palette;
    final level = ref.watch(targetLevelProvider);
    return ListView(key: const ValueKey('welcome'), padding: const EdgeInsets.fromLTRB(AppSpace.screen, 16, AppSpace.screen, 24), children: [
      const BrandRow(),
      const SizedBox(height: 28),
      const AbHero(height: 150, mood: PicoMood.wave),
      const SizedBox(height: 28),
      Text(l.loginHeadline, style: AppType.largeTitle.copyWith(fontSize: 34, height: 1.12, color: p.textPrimary)),
      const SizedBox(height: 10),
      Text(l.loginSubtitle, style: AppType.body.copyWith(fontSize: 17, color: p.textSecondary)),
      const SizedBox(height: 22),
      AppSegmented<Level>(
        items: [for (final lv in Level.values) SegmentItem(lv, lv.code, dot: p.level(lv), key: Key('login-level-${lv.code}'))],
        selected: level,
        onChanged: (v) => ref.read(targetLevelProvider.notifier).set(v),
      ),
      const SizedBox(height: 14),
      _providers(),
      const SizedBox(height: 10),
      FilledButton.icon(
        key: const Key('login-email-signup'),
        onPressed: () => _go(_Mode.signUp),
        icon: const Icon(AppIcons.mail, size: 20),
        label: Text(l.signUpWithEmail),
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          key: const Key('login-go-signin'),
          onPressed: () => _go(_Mode.signIn),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '${l.haveAccountQuestion} ', style: AppType.body.copyWith(color: p.textSecondary)),
            TextSpan(text: l.signIn, style: AppType.headline.copyWith(color: p.link)),
          ])),
        ),
      ),
      const SizedBox(height: 8),
      Text(l.notAffiliated, textAlign: TextAlign.center, style: AppType.footnote.copyWith(color: p.textTertiary, fontWeight: FontWeight.w400)),
      const _LegalLinks(),
    ]);
  }

  Widget _emailForm() {
    final l = context.l10n;
    final p = context.palette;
    final signUp = _mode == _Mode.signUp;
    return Form(
      key: _form,
      child: ListView(key: ValueKey(_mode), padding: const EdgeInsets.fromLTRB(AppSpace.screen, 8, AppSpace.screen, 24), children: [
        Row(children: [
          RoundIconButton(icon: AppIcons.back, tooltip: l.backLabel, onPressed: () => _go(_Mode.welcome), size: 44),
          const Spacer(),
          const AppLogo(size: 26),
        ]),
        const SizedBox(height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: ScreenTitle(signUp ? l.createAccountTitle : l.welcomeBack)),
          Pico(size: 72, mood: signUp ? PicoMood.wave : PicoMood.idle, level: ref.watch(targetLevelProvider)),
        ]),
        const SizedBox(height: 6),
        Text(signUp ? l.createAccountSubtitle : l.welcomeBackSubtitle, style: AppType.body.copyWith(color: p.textSecondary)),
        const SizedBox(height: 24),
        TextFormField(
          key: const Key('login-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: l.emailLabel, prefixIcon: const Icon(AppIcons.mail)),
          validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '') ? null : l.invalidEmail,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('login-password'),
          controller: _password,
          obscureText: !_showPassword,
          autofillHints: [signUp ? AutofillHints.newPassword : AutofillHints.password],
          decoration: InputDecoration(
            labelText: l.passwordLabel,
            helperText: signUp ? l.passwordTooShort : null,
            prefixIcon: const Icon(AppIcons.lock),
            suffixIcon: IconButton(
              tooltip: _showPassword ? l.hidePassword : l.showPassword,
              icon: Icon(_showPassword ? AppIcons.eyeOff : AppIcons.eye),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          validator: (v) => (v ?? '').length >= 8 ? null : l.passwordTooShort,
          onFieldSubmitted: (_) => _submit(),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Tile(
              color: p.surfaceMuted,
              padding: const EdgeInsets.all(14),
              child: Text(_message!, key: const Key('login-message'), style: AppType.body.copyWith(color: p.textPrimary)),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('login-submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: p.onBrand))
              : Text(signUp ? l.createAccount : l.signIn),
        ),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: Divider(color: p.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(l.orContinueWith, style: AppType.footnote.copyWith(color: p.textTertiary)),
          ),
          Expanded(child: Divider(color: p.border)),
        ]),
        const SizedBox(height: 16),
        _providers(),
        const SizedBox(height: 12),
        if (signUp)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(l.signUpLegalNote, textAlign: TextAlign.center, style: AppType.footnote.copyWith(color: p.textTertiary, fontWeight: FontWeight.w400)),
          ),
        const _LegalLinks(),
        Center(
          child: TextButton(
            key: const Key('login-switch'),
            onPressed: _busy ? null : () => _go(signUp ? _Mode.signIn : _Mode.signUp),
            child: Text(signUp ? l.haveAccount : l.noAccountYet),
          ),
        ),
      ]),
    );
  }
}

/// "Términos de uso · Política de privacidad", readable before signing up.
class _LegalLinks extends StatelessWidget {
  const _LegalLinks();
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final style = TextButton.styleFrom(foregroundColor: p.textSecondary, textStyle: AppType.footnote.copyWith(fontWeight: FontWeight.w600));
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      TextButton(style: style, onPressed: () => context.push(LegalDoc.terms.path), child: Text(l.termsOfUse)),
      Text('·', style: AppType.footnote.copyWith(color: p.textTertiary)),
      TextButton(style: style, onPressed: () => context.push(LegalDoc.privacy.path), child: Text(l.privacyPolicy)),
    ]);
  }
}
