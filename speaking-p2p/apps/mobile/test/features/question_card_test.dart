import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/theming/app_theme.dart';
import 'package:speaking_p2p/features/exam/widgets/exam_widgets.dart';
import 'package:speaking_p2p/l10n/app_localizations.dart';

const _c1 = 'Candidate A, your pictures show different attitudes to clothes. Choose two of the pictures and say '
    'what these attitudes reveal about the people, and what the consequences of their behaviour might be.';

Future<void> _pump(WidgetTester tester, {required bool booklet}) => tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: QuestionCard(text: _c1, visible: true, onToggle: () {}, speaking: false, booklet: booklet),
        ),
      ),
    ));

void main() {
  testWidgets('Parte 2: las preguntas aparte, como en el cuadernillo (D-052)', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, booklet: true);
    expect(find.text('Candidate A, your pictures show different attitudes to clothes. Choose two of the pictures and say:'), findsOneWidget);
    expect(find.text('what these attitudes reveal about the people'), findsOneWidget);
    expect(find.text('what the consequences of their behaviour might be'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
    expect(find.bySemanticsLabel(_c1), findsOneWidget, reason: 'el lector de pantalla oye la frase original');
    semantics.dispose();
  });

  testWidgets('fuera de la Parte 2 el texto sigue siendo una frase', (tester) async {
    await _pump(tester, booklet: false);
    expect(find.text(_c1), findsOneWidget);
    expect(find.byKey(const Key('exam-text-booklet')), findsNothing);
  });
}
