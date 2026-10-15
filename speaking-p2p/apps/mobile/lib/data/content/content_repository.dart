// Exam content shipped in the bundle (assets/content, copied from /content).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/exam/models.dart';

class ContentIndexEntry {
  const ContentIndexEntry(this.id, this.level, this.version, this.topic);
  final String id;
  final Level level;
  final int version;
  final String topic;
}

class ContentIndex {
  const ContentIndex(this.version, this.exams, this.diagrams);

  /// Sent to the server when matching: it never picks an exam this build lacks.
  final int version;
  final List<ContentIndexEntry> exams;
  final List<String> diagrams;
}

class ContentRepository {
  ContentRepository(this._bundle);
  final AssetBundle _bundle;
  static const _root = 'assets/content';

  Future<Map<String, Object?>> _json(String path) async =>
      jsonDecode(await _bundle.loadString('$_root/$path')) as Map<String, Object?>;

  Future<ContentIndex> index() async {
    final j = await _json('index.json');
    return ContentIndex(
      j['version']! as int,
      (j['exams']! as List<Object?>).cast<Map<String, Object?>>().map((e) => ContentIndexEntry(
            e['id']! as String,
            LevelCode.parse(e['level']! as String),
            e['version']! as int,
            e['topic']! as String,
          )).toList(growable: false),
      (j['diagrams']! as List<Object?>).cast<String>(),
    );
  }

  /// Null when this build does not ship the exam (older app): the session is
  /// then aborted with reason content_missing instead of showing a broken exam.
  Future<Exam?> exam(Level level, String id) async {
    try {
      return Exam.fromJson(await _json('exams/${level.code}/$id.json'));
    } on FlutterError {
      return null;
    }
  }

  Future<Diagram> diagram(String id) async => Diagram.fromJson(await _json('diagrams/$id.json'));
}

final contentRepositoryProvider = Provider<ContentRepository>((ref) => ContentRepository(rootBundle));
final contentIndexProvider = FutureProvider<ContentIndex>((ref) => ref.watch(contentRepositoryProvider).index());
