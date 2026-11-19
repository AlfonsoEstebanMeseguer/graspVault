// Re-acceptance of the Terms and Privacy Policy (docs/legal/ASPECTOS_A_COMPLETAR.md
// §11, D-066). The router sends here every signed-in user whose accepted version
// is older than [termsVersion]; nothing else opens until they accept or sign out.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/profile/profile_repository.dart';
import '../../domain/account/account.dart';
import 'legal_screen.dart' show LegalDoc, LegalDocAsset;

class TermsUpdateScreen extends ConsumerStatefulWidget {
  const TermsUpdateScreen({super.key});

  @override
  ConsumerState<TermsUpdateScreen> createState() => _TermsUpdateScreenState();
}

class _TermsUpdateScreenState extends ConsumerState<TermsUpdateScreen> {
  bool _accepted = false;
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    final repo = ref.read(profileRepositoryProvider);
    if (repo == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.acceptTerms(termsVersion);
      ref.invalidate(myProfileProvider); // the router lets the user in once the new version is stored
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context.l10n, e));
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.screen, 24, AppSpace.screen, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.termsUpdateTitle, style: AppType.title1.copyWith(color: p.textPrimary)),
            const SizedBox(height: 12),
            Text(l.termsUpdateBody, style: AppType.body.copyWith(color: p.textSecondary)),
            const SizedBox(height: 16),
            Wrap(spacing: 4, children: [
              TextButton(key: const Key('terms-update-read-terms'), onPressed: () => context.push(LegalDoc.terms.path), child: Text(l.readTerms)),
              TextButton(key: const Key('terms-update-read-privacy'), onPressed: () => context.push(LegalDoc.privacy.path), child: Text(l.readPrivacy)),
            ]),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('terms-update-check'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
              title: Text(l.acceptTerms, style: AppType.footnote.copyWith(fontSize: 14, color: p.textPrimary, fontWeight: FontWeight.w400)),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: AppType.footnote.copyWith(color: p.danger)),
              ),
            const Spacer(),
            FilledButton(
              key: const Key('terms-update-accept'),
              onPressed: _accepted && !_busy ? _accept : null,
              child: _busy
                  ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: p.onBrand))
                  : Text(l.termsUpdateAccept),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('terms-update-sign-out'),
              onPressed: _busy ? null : () => ref.read(authRepositoryProvider).signOut(),
              child: Text(l.signOut),
            ),
          ]),
        ),
      ),
    );
  }
}
