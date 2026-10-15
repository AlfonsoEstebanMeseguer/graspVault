// Login by email (DECISIONS D-022). Layout follows the "Login" sketch: brand,
// A/B illustration, headline, level chips, then the form where the Google
// button will go back.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../data/auth/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
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
      if (_signUp) {
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
    final p = context.palette;
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: p.brand, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.graphic_eq, color: p.onBrand, size: 20),
              ),
              const SizedBox(width: 10),
              Text(l.appName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: p.textPrimary)),
            ]),
            const SizedBox(height: 28),
            const _AbIllustration(),
            const SizedBox(height: 28),
            Text(l.loginHeadline, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, color: p.textPrimary)),
            const SizedBox(height: 8),
            Text(l.loginSubtitle, style: TextStyle(color: p.textSecondary, fontSize: 15)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, children: [
              for (final t in [l.levelB1, l.levelB2, l.levelC1])
                Chip(label: Text(t, style: const TextStyle(fontSize: 12)), visualDensity: VisualDensity.compact),
            ]),
            const SizedBox(height: 24),
            TextFormField(
              key: const Key('login-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: l.emailLabel, border: const OutlineInputBorder()),
              validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '') ? null : l.invalidEmail,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('login-password'),
              controller: _password,
              obscureText: true,
              autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
              decoration: InputDecoration(labelText: l.passwordLabel, border: const OutlineInputBorder()),
              validator: (v) => (v ?? '').length >= 8 ? null : l.passwordTooShort,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_message!, key: const Key('login-message'), style: TextStyle(color: p.textSecondary)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('login-submit'),
              style: FilledButton.styleFrom(backgroundColor: p.timerFill, foregroundColor: p.onTimerFill),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: p.onTimerFill))
                  : Text(_signUp ? l.createAccount : l.signIn),
            ),
            TextButton(
              onPressed: _busy ? null : () => setState(() {
                _signUp = !_signUp;
                _message = null;
              }),
              child: Text(_signUp ? l.haveAccount : l.noAccountYet),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AbIllustration extends StatelessWidget {
  const _AbIllustration();
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget circle(String t, bool filled) => Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? p.brand : p.surface,
            border: Border.all(color: filled ? p.brand : p.border),
          ),
          child: Text(t, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: filled ? p.onBrand : p.textPrimary)),
        );
    return ExcludeSemantics(
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        circle('A', true),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.graphic_eq, color: p.brand)),
        circle('B', false),
      ]),
    );
  }
}
