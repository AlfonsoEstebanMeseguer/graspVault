// Términos de uso / Política de privacidad, read from assets/legal/*.md and
// drawn with a small renderer (titles, headings, paragraphs, bullets). Lines
// starting with "> " are internal review notes and are never shown.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../domain/account/account.dart' show termsVersion;

/// Must match the "Versión" line of both documents; stored when the user accepts.
const legalVersion = termsVersion;

enum LegalDoc { terms, privacy }

extension LegalDocAsset on LegalDoc {
  String get asset => switch (this) {
        LegalDoc.terms => 'assets/legal/terminos.md',
        LegalDoc.privacy => 'assets/legal/privacidad.md',
      };
  String get path => switch (this) {
        LegalDoc.terms => '/legal/terms',
        LegalDoc.privacy => '/legal/privacy',
      };
}

sealed class LegalBlock {}

class LegalTitle extends LegalBlock {
  LegalTitle(this.text);
  final String text;
}

class LegalHeading extends LegalBlock {
  LegalHeading(this.text);
  final String text;
}

class LegalParagraph extends LegalBlock {
  LegalParagraph(this.text);
  final String text;
}

class LegalBullet extends LegalBlock {
  LegalBullet(this.text);
  final String text;
}

/// Pure: tested without widgets. Review notes ("> …") are dropped.
List<LegalBlock> parseLegal(String md) {
  final out = <LegalBlock>[];
  final para = <String>[];
  void flush() {
    if (para.isNotEmpty) out.add(LegalParagraph(para.join(' ')));
    para.clear();
  }

  for (final raw in md.split('\n')) {
    final line = raw.trimRight();
    if (line.startsWith('>')) {
      flush();
      continue;
    }
    if (line.trim().isEmpty) {
      flush();
    } else if (line.startsWith('## ')) {
      flush();
      out.add(LegalHeading(line.substring(3).trim()));
    } else if (line.startsWith('# ')) {
      flush();
      out.add(LegalTitle(line.substring(2).trim()));
    } else if (line.startsWith('- ')) {
      flush();
      out.add(LegalBullet(line.substring(2).trim()));
    } else {
      para.add(line.trim());
    }
  }
  flush();
  return out;
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(doc == LegalDoc.terms ? l.termsOfUse : l.privacyPolicy)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(doc.asset),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final blocks = parseLegal(snap.data!);
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpace.screen, 4, AppSpace.screen, 40),
              children: [
                if (Localizations.localeOf(context).languageCode != 'es')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(l.legalSpanishOnly, style: AppType.footnote.copyWith(color: p.textSecondary)),
                  ),
                for (final b in blocks)
                  switch (b) {
                    LegalTitle(:final text) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(text, style: AppType.title1.copyWith(color: p.textPrimary)),
                      ),
                    LegalHeading(:final text) => Padding(
                        padding: const EdgeInsets.only(top: 22, bottom: 8),
                        child: Text(text, style: AppType.headline.copyWith(color: p.textPrimary)),
                      ),
                    LegalParagraph(:final text) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(text, style: AppType.body.copyWith(fontSize: 15, height: 1.5, color: p.textSecondary)),
                      ),
                    LegalBullet(:final text) => Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 9, right: 10),
                            child: Container(width: 4, height: 4, decoration: BoxDecoration(color: p.textTertiary, shape: BoxShape.circle)),
                          ),
                          Expanded(child: Text(text, style: AppType.body.copyWith(fontSize: 15, height: 1.5, color: p.textSecondary))),
                        ]),
                      ),
                  },
              ],
            ),
          );
        },
      ),
    );
  }
}
