// D-052: the Part 2 questions are shown apart, but the text of the 153 exams
// stays exactly as it is (the audio and audioMs are generated from it).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/domain/exam/prompt.dart';

List<Exam> _bank() => [
      for (final f in Directory('assets/content/exams').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.json')) Exam.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, Object?>),
    ];

void main() {
  test('C1: introducción y dos preguntas', () {
    const t = 'Candidate A, your pictures show people focusing on different things. Choose two of the pictures and say '
        'what might be distracting these people, and how easy it might be for them to concentrate.';
    final p = PromptParts.parse(t)!;
    expect(p.lead, endsWith('Choose two of the pictures and say'));
    expect(p.questions, ['what might be distracting these people', 'how easy it might be for them to concentrate']);
    expect(p.text, t);
  });

  test('B2: una pregunta; «and» dentro de la pregunta no la parte', () {
    const t = 'Candidate A, your photographs show people working in different places. Compare the photographs, and say '
        'what the advantages and disadvantages of working in these places might be.';
    final p = PromptParts.parse(t)!;
    expect(p.lead, 'Candidate A, your photographs show people working in different places. Compare the photographs, and say');
    expect(p.questions, ['what the advantages and disadvantages of working in these places might be']);
  });

  test('sin esa forma se muestra tal cual', () {
    expect(PromptParts.parse('Candidate A, here is your photograph. Please tell us what you can see.'), isNull);
    expect(PromptParts.parse('Candidate B, which of these activities would you prefer to do? Why?'), isNull);
    expect(PromptParts.parse('Compare them and say'), isNull);
  });

  test('los 153 exámenes: el texto reconstruido es idéntico y cada nivel tiene su forma', () {
    final bank = _bank();
    expect(bank.length, 153);
    var shown = 0;
    for (final e in bank) {
      for (final part in e.parts) {
        for (final s in part.steps) {
          final p = PromptParts.parse(s.text);
          if (p == null) continue;
          // Identical text everywhere, although the exam only formats Part 2
          // (B1's Part 3 also says "… and say which …": that stays a sentence).
          expect(p.text, s.text, reason: '${e.id}/${s.id}');
        }
        if (part.index != 2) continue;
        for (final s in part.steps.where((s) => s.assets.isNotEmpty)) {
          final p = PromptParts.parse(s.text);
          switch (e.level) {
            case Level.b1:
              expect(p, isNull, reason: '${e.id}: B1 describe una foto, sin preguntas');
            case Level.b2:
              expect(p?.questions.length, 1, reason: '${e.id}/${s.id}');
            case Level.c1:
              expect(p?.questions.length, 2, reason: '${e.id}/${s.id}');
          }
          if (p != null) shown++;
        }
      }
    }
    expect(shown, 204, reason: '102 de B2 + 102 de C1');
  });
}
