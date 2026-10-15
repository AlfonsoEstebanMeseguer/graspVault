// An honest placeholder is honest in its FORM too: a title and one sentence,
// no buttons that look like they do something (vault: UI-Flutter-y-producto).
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theming/palette.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: p.textPrimary)),
            const SizedBox(height: 12),
            Text(context.l10n.needsBackend, style: TextStyle(color: p.textSecondary)),
          ]),
        ),
      ),
    );
  }
}
