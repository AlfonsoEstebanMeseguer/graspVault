// Exam content model. Mirrors the Zod schema in
// apps/backend/supabase/functions/_shared/exam/schema.ts. The content is
// validated in CI there; here parsing is strict and fails loudly.

enum Level { b1, b2, c1 }

extension LevelCode on Level {
  String get code => name.toUpperCase();
  static Level parse(String v) => Level.values.firstWhere((l) => l.code == v,
      orElse: () => throw FormatException('unknown level $v'));
}

enum Role { a, b }

extension RoleCode on Role {
  String get code => name.toUpperCase();
  Role get other => this == Role.a ? Role.b : Role.a;
}

enum StepKind { narration, turn, open }

/// Who the reader addresses. `both` only exists in open steps.
enum Target { a, b, both }

Target _target(Object? v) => switch (v) {
      'A' => Target.a,
      'B' => Target.b,
      'both' => Target.both,
      _ => throw FormatException('bad target $v'),
    };

class ExamStep {
  const ExamStep({
    required this.id,
    required this.kind,
    required this.text,
    required this.audio,
    required this.audioMs,
    this.target,
    this.durationSec = 0,
    this.assets = const [],
    this.diagram,
  });

  final String id;
  final StepKind kind;
  final String text;
  final String audio;
  final int audioMs;
  final Target? target;
  final int durationSec;
  final List<String> assets;
  final String? diagram;

  factory ExamStep.fromJson(Map<String, Object?> j) {
    final kind = StepKind.values.byName(j['kind']! as String);
    return ExamStep(
      id: j['id']! as String,
      kind: kind,
      text: j['text']! as String,
      audio: j['audio']! as String,
      audioMs: j['audioMs']! as int,
      target: kind == StepKind.narration ? null : _target(j['target']),
      durationSec: (j['durationSec'] as int?) ?? 0,
      assets: ((j['assets'] as List<Object?>?) ?? const []).cast<String>(),
      diagram: j['diagram'] as String?,
    );
  }
}

class Part {
  const Part({required this.index, required this.title, required this.steps});
  final int index;
  final String title;
  final List<ExamStep> steps;

  factory Part.fromJson(Map<String, Object?> j) => Part(
        index: j['index']! as int,
        title: j['title']! as String,
        steps: (j['steps']! as List<Object?>)
            .map((s) => ExamStep.fromJson(s! as Map<String, Object?>))
            .toList(growable: false),
      );
}

class Exam {
  const Exam({
    required this.id,
    required this.level,
    required this.version,
    required this.topic,
    required this.parts,
  });

  final String id;
  final Level level;
  final int version;
  final String topic;
  final List<Part> parts;

  factory Exam.fromJson(Map<String, Object?> j) {
    final parts = (j['parts']! as List<Object?>)
        .map((p) => Part.fromJson(p! as Map<String, Object?>))
        .toList(growable: false);
    if (parts.length != 4) throw const FormatException('an exam has 4 parts');
    return Exam(
      id: j['id']! as String,
      level: LevelCode.parse(j['level']! as String),
      version: j['version']! as int,
      topic: j['topic']! as String,
      parts: parts,
    );
  }

  ExamStep step(String id) => parts.expand((p) => p.steps).firstWhere((s) => s.id == id);
}

/// Part 3 bubble diagram: drawn natively, never an image.
class Diagram {
  const Diagram({
    required this.id,
    required this.centralQuestion,
    required this.prompts,
    required this.decisionQuestion,
  });

  final String id;
  final String centralQuestion;
  final List<String> prompts;
  final String decisionQuestion;

  factory Diagram.fromJson(Map<String, Object?> j) {
    final prompts = (j['prompts']! as List<Object?>).cast<String>();
    if (prompts.length != 5) throw const FormatException('a diagram has 5 prompts');
    return Diagram(
      id: j['id']! as String,
      centralQuestion: j['centralQuestion']! as String,
      prompts: prompts,
      decisionQuestion: j['decisionQuestion']! as String,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'centralQuestion': centralQuestion,
        'prompts': prompts,
        'decisionQuestion': decisionQuestion,
      };
}
