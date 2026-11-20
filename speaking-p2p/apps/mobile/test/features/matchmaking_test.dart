import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/data/content/content_repository.dart';
import 'package:speaking_p2p/data/matchmaking/matchmaking_repository.dart';
import 'package:speaking_p2p/domain/account/account.dart';
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/features/matchmaking/matchmaking_controller.dart';

class FakeQueue implements MatchmakingRepository {
  int calls = 0;
  int? matchOnCall;
  bool openMeeting = false;
  String? fail;
  bool cancelled = false;
  final versions = <int>[];

  @override
  Future<EnqueueResult> enqueue(Level level, int contentVersion) async {
    calls++;
    versions.add(contentVersion);
    if (fail != null) throw AppFailure(fail!);
    return EnqueueResult(matchedSessionId: calls == matchOnCall ? 'sess-1' : null, hasOpenMeeting: openMeeting);
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

ProviderContainer container(FakeQueue q) => ProviderContainer(overrides: [
      matchmakingRepositoryProvider.overrideWithValue(q),
      contentIndexProvider.overrideWith((ref) async => const ContentIndex(7, [], [])),
    ]);

void main() {
  test('latido cada 10 s con la version de contenido de la app, y emparejamiento', () {
    fakeAsync((t) {
      final q = FakeQueue()..matchOnCall = 3;
      final c = container(q);
      c.read(matchmakingProvider.notifier).start(Level.b2);
      t.flushMicrotasks();
      expect(q.calls, 1);
      t.elapse(const Duration(seconds: 10));
      expect(q.calls, 2);
      t.elapse(const Duration(seconds: 10));
      expect(c.read(matchmakingProvider).matchedSessionId, 'sess-1');
      expect(c.read(matchmakingProvider).searching, isFalse);
      t.elapse(const Duration(seconds: 30));
      expect(q.calls, 3, reason: 'tras emparejar se deja de latir');
      expect(q.versions.toSet(), {7});
      c.dispose();
    });
  });

  test('aviso a los 15 s solo si no tiene reuniones abiertas', () {
    fakeAsync((t) {
      final q = FakeQueue();
      final c = container(q);
      c.read(matchmakingProvider.notifier).start(Level.c1);
      t.elapse(const Duration(seconds: 14));
      expect(c.read(matchmakingProvider).showPrompt, isFalse);
      t.elapse(const Duration(seconds: 1));
      expect(c.read(matchmakingProvider).showPrompt, isTrue);
      c.read(matchmakingProvider.notifier).dismissPrompt();
      expect(c.read(matchmakingProvider).showPrompt, isFalse);
      expect(c.read(matchmakingProvider).searching, isTrue, reason: '"No" sigue buscando');
      c.dispose();

      final q2 = FakeQueue()..openMeeting = true;
      final c2 = container(q2);
      c2.read(matchmakingProvider.notifier).start(Level.c1);
      t.elapse(const Duration(seconds: 20));
      expect(c2.read(matchmakingProvider).showPrompt, isFalse);
      c2.dispose();
    });
  });

  test('sin elegibilidad se para y muestra el motivo; cancelar avisa al servidor', () {
    fakeAsync((t) {
      final q = FakeQueue()..fail = 'not_eligible';
      final c = container(q);
      c.read(matchmakingProvider.notifier).start(Level.b1);
      t.flushMicrotasks();
      expect(c.read(matchmakingProvider).error, 'not_eligible');
      expect(c.read(matchmakingProvider).searching, isFalse);
      c.read(matchmakingProvider.notifier).cancel();
      t.flushMicrotasks();
      expect(q.cancelled, isTrue);
      c.dispose();
    });
  });
}
