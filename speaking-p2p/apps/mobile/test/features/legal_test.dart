// Terms and Privacy Policy (D-045): the review notes never reach the user, the
// version the user signs is the one written in both documents, and both can be
// read without an account.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/router/router.dart';
import 'package:speaking_p2p/domain/account/account.dart';
import 'package:speaking_p2p/features/legal/legal_screen.dart';

void main() {
  for (final doc in LegalDoc.values) {
    final md = File(doc.asset).readAsStringSync();

    test('${doc.name}: las notas [REVISAR] no se muestran', () {
      expect(md, contains('[REVISAR]'), reason: 'el borrador lleva notas para Alfonso');
      final text = parseLegal(md).map((b) => switch (b) {
            LegalTitle(:final text) || LegalHeading(:final text) || LegalParagraph(:final text) || LegalBullet(:final text) => text,
          });
      expect(text.where((t) => t.contains('[REVISAR]')), isEmpty);
    });

    test('${doc.name}: la versión que se firma es la del documento', () {
      expect(md, contains('Versión $termsVersion'));
      expect(legalVersion, termsVersion);
    });
  }

  test('parser: título, apartados, párrafos y viñetas', () {
    final blocks = parseLegal('# T\n\nVersión x\n\n## 1. A\n\nuna\nlínea\n\n- uno\n- dos\n\n> nota\n');
    expect(blocks.map((b) => b.runtimeType.toString()).toList(),
        ['LegalTitle', 'LegalParagraph', 'LegalHeading', 'LegalParagraph', 'LegalBullet', 'LegalBullet']);
    expect((blocks[3] as LegalParagraph).text, 'una línea');
  });

  test('los documentos se leen sin sesión', () {
    for (final path in ['/legal/terms', '/legal/privacy']) {
      expect(gateRedirect(hasBackend: true, user: const AsyncData(null), profile: const AsyncData(null), location: path), isNull);
    }
  });
}
