// "Reportar o bloquear" (D-044) with the sabotage reasons of D-051: they only
// appear when there is a session to attach the report to.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/theming/app_theme.dart';
import 'package:speaking_p2p/data/safety/safety_repository.dart';
import 'package:speaking_p2p/features/safety/safety_sheet.dart';
import 'package:speaking_p2p/l10n/app_localizations.dart';

class _Fake implements SafetyRepository {
  final reports = <String>[];
  final blocks = <String>[];
  @override
  Future<void> report(String userId, ReportReason reason, {String? details, required ReportContext context, String? sessionId, String? chatId}) async =>
      reports.add('$userId ${reason.wire} ${context.name} $sessionId');
  @override
  Future<void> block(String userId) async => blocks.add(userId);
  @override
  Future<void> unblock(String userId) async {}
  @override
  Future<List<String>> blocked() async => const [];
}

Future<void> _open(WidgetTester tester, _Fake repo, {String? sessionId, ReportContext where = ReportContext.exam}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [safetyRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: buildTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSafetySheet(context, userId: 'u2', name: 'marta', where: where, sessionId: sessionId),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('en una sesión: motivos de sabotaje y el reporte lleva la sesión', (tester) async {
    final repo = _Fake();
    await _open(tester, repo, sessionId: 's1');
    for (final r in ['silent', 'mocking', 'noise', 'quit', 'control_abuse', 'harassment']) {
      expect(find.byKey(Key('report-$r')), findsOneWidget, reason: r);
    }
    await tester.tap(find.byKey(const Key('report-silent')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('report-send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-send')));
    await tester.pumpAndSettle();
    expect(repo.reports, ['u2 silent exam s1']);
    expect(repo.blocks, ['u2'], reason: 'bloquear sigue marcado por defecto');
  });

  testWidgets('fuera de una sesión (chat, oferta): solo los motivos de siempre', (tester) async {
    await _open(tester, _Fake(), where: ReportContext.chat);
    expect(find.byKey(const Key('report-harassment')), findsOneWidget);
    for (final r in ['silent', 'mocking', 'noise', 'quit', 'control_abuse']) {
      expect(find.byKey(Key('report-$r')), findsNothing, reason: r);
    }
  });
}
