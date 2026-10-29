import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/features/exam/reader_player.dart';

void main() {
  const voices = ['bf_emma', 'bm_george', 'bf_isabella', 'bm_lewis'];

  test('los dos móviles de una sesión eligen la misma voz, y varía entre sesiones', () {
    const id = '12989979-0fdf-4900-a7c6-3e06746a845d';
    expect(voiceForSession(id, voices), voiceForSession(id, List.of(voices)));
    final picked = {
      for (var i = 0; i < 40; i++) voiceForSession('00000000-0000-0000-0000-${i.toString().padLeft(12, '0')}', voices),
    };
    expect(picked.length, greaterThan(1));
  });

  test('la clave en R2 inserta la voz tras audio/', () {
    expect(voiceKey('bm_george', 'audio/B2/b2-community-life/p1-intro.mp3'), 'audio/bm_george/B2/b2-community-life/p1-intro.mp3');
  });

  test('cache en disco: audio siempre; fotos durante 14 dias; nunca un archivo vacio', () {
    final dir = Directory.systemTemp.createTempSync('cache_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final now = DateTime.now();
    final photo = File('${dir.path}/p.webp')..writeAsBytesSync([1, 2, 3]);
    expect(reusable('img/B2/x/b2-e01-a1.webp', photo.statSync(), now), isTrue);
    photo.setLastModifiedSync(now.subtract(const Duration(days: 15)));
    expect(reusable('img/B2/x/b2-e01-a1.webp', photo.statSync(), now), isFalse, reason: 'una foto vieja se vuelve a pedir');
    expect(reusable('audio/bf_emma/B2/x/p1.mp3', photo.statSync(), now), isTrue, reason: 'el audio no caduca');
    final empty = File('${dir.path}/e.mp3')..writeAsBytesSync([]);
    expect(reusable('audio/bf_emma/B2/x/p1.mp3', empty.statSync(), now), isFalse);
    expect(reusable('audio/bf_emma/B2/x/p1.mp3', null, now), isFalse);
  });
}
