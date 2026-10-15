import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speaking_p2p/core/l10n/l10n.dart';
import 'package:speaking_p2p/core/theming/app_theme.dart';
import 'package:speaking_p2p/core/theming/preferences.dart';
import 'package:speaking_p2p/data/agenda/agenda_repository.dart';
import 'package:speaking_p2p/data/session/session_repository.dart' show PublicProfile;
import 'package:speaking_p2p/domain/account/account.dart';
import 'package:speaking_p2p/domain/agenda/agenda.dart';
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/features/agenda/agenda_common.dart';
import 'package:speaking_p2p/features/agenda/agenda_screen.dart';
import 'package:speaking_p2p/features/agenda/chat_screen.dart';

final now = DateTime(2026, 10, 15, 16, 0);
DateTime today(int h, [int m = 0]) => DateTime(2026, 10, 15, h, m);

Meeting meeting({String id = 'm1', MeetingStatus status = MeetingStatus.pending, DateTime? at, bool creatorOk = false, bool acceptorOk = false}) =>
    Meeting(
      id: id,
      offerId: 'o-mine',
      creatorId: 'marta',
      acceptorId: 'me',
      level: Level.c1,
      scheduledAt: at ?? DateTime(2026, 10, 16, 18, 30),
      creatorConfirmed: creatorOk,
      acceptorConfirmed: acceptorOk,
      status: status,
    );

class FakeAgenda implements AgendaRepository {
  List<Offer> mine = [
    Offer(id: 'o-mine', creatorId: 'me', level: Level.c1, windowStart: DateTime(2026, 10, 16, 17), windowEnd: DateTime(2026, 10, 16, 20), status: OfferStatus.open, interested: 2),
  ];
  List<Offer> boardOffers = [
    Offer(id: 'o-sergi', creatorId: 'sergi', level: Level.c1, windowStart: today(18), windowEnd: today(21), status: OfferStatus.open, creatorName: 'sergi_cae', creatorLanguages: const ['es', 'ca', 'en']),
  ];
  List<Meeting> confirmed = [meeting(id: 'm-busy', status: MeetingStatus.confirmed, at: today(19))];
  Meeting card = meeting(creatorOk: true);
  final accepted = <(String, DateTime)>[];
  final created = <(Level, DateTime, DateTime)>[];
  final sent = <String>[];
  final confirms = <String>[];
  List<List<Level>> boardQueries = [];

  @override
  String get me => 'me';
  @override
  Future<List<Offer>> myOffers() async => mine;
  @override
  Future<List<Offer>> board(List<Level> levels) async {
    boardQueries.add(levels);
    return boardOffers.where((o) => levels.contains(o.level)).toList();
  }

  @override
  Future<List<ChatSummary>> chats({String? chatId}) async => [
        ChatSummary(
          chatId: 'c1',
          meeting: card,
          partnerId: 'marta',
          partnerName: 'marta.eng',
          partnerLanguages: const ['es', 'en'],
          lastMessage: ChatMessage(id: 'x', senderId: 'marta', kind: 'user', createdAt: today(15, 40), body: '¿Y si mejor a las 18:30?'),
        ),
      ];
  @override
  Future<List<Meeting>> myMeetings() async => confirmed;
  @override
  Stream<Meeting> watchMeeting(String meetingId) => Stream.value(card);
  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) => Stream.value([
        ChatMessage(id: '1', senderId: null, kind: 'system', createdAt: today(10), systemCode: 'meeting_proposed',
            systemArgs: {'by': 'me', 'scheduled_at': DateTime(2026, 10, 16, 18).toUtc().toIso8601String(), 'level': 'C1'}),
        ChatMessage(id: '2', senderId: 'marta', kind: 'user', createdAt: today(10, 5), body: '¿Te va bien a las 18:30?'),
        ChatMessage(id: '3', senderId: null, kind: 'system', createdAt: today(10, 6), systemCode: 'meeting_modified',
            systemArgs: {'by': 'marta', 'scheduled_at': DateTime(2026, 10, 16, 18, 30).toUtc().toIso8601String(), 'level': 'C1'}),
        ChatMessage(id: '4', senderId: null, kind: 'system', createdAt: today(10, 7), systemCode: 'meeting_confirmed_by', systemArgs: {'by': 'marta'}),
      ]);
  @override
  Future<void> send(String chatId, String body, String clientId) async => sent.add(body);
  @override
  Future<PublicProfile?> profile(String userId) async => PublicProfile(id: userId, username: '${userId}_x', languages: const ['es']);
  @override
  Future<String> createOffer(Level level, DateTime start, DateTime end) async {
    created.add((level, start, end));
    return 'new';
  }

  @override
  Future<void> cancelOffer(String offerId) async {}
  @override
  Future<({String meetingId, String chatId})> accept(String offerId, DateTime at) async {
    accepted.add((offerId, at));
    return (meetingId: 'm2', chatId: 'c2');
  }

  @override
  Future<void> modify(String meetingId, DateTime at, Level level) async {}
  @override
  Future<String> confirm(String meetingId) async {
    confirms.add(meetingId);
    return 'confirmed';
  }

  @override
  Future<void> cancel(String meetingId) async {}
  @override
  Future<String> enter(String meetingId, int contentVersion) async => throw const AppFailure('too_early');
}

Future<FakeAgenda> pump(WidgetTester tester, {String location = '/agenda', FakeAgenda? fake}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'target_level': 'C1'});
  final prefs = await SharedPreferences.getInstance();
  final f = fake ?? FakeAgenda();
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(path: '/agenda', builder: (_, s) => AgendaScreen(openCreate: s.uri.queryParameters['create'] == '1')),
    GoRoute(path: '/chat/:id', builder: (_, s) => ChatScreen(chatId: s.pathParameters['id']!)),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      agendaRepositoryProvider.overrideWithValue(f),
      sharedPreferencesProvider.overrideWithValue(prefs),
      agendaClockProvider.overrideWithValue(() => now),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: buildTheme(Brightness.light),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    ),
  ));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return f;
}

void main() {
  testWidgets('tablón: mis ofertas, filtro adyacente y elegir hora con "Ocupado"', (tester) async {
    final f = await pump(tester);
    expect(find.text('MIS OFERTAS · 1 DE 2'), findsOneWidget);
    expect(find.text('2 interesados'), findsOneWidget);
    expect(find.text('sergi_cae'), findsOneWidget);
    expect(find.text('Hoy · 18:00–21:00'), findsOneWidget);
    expect(f.boardQueries.last, [Level.c1]);

    await tester.tap(find.text('+ Incluir B2'));
    await tester.pump();
    expect(f.boardQueries.last, [Level.c1, Level.b2]);
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Elegir hora'));
    await tester.pumpAndSettle();
    expect(find.text('Examen con sergi_cae'), findsOneWidget);
    expect(find.text('Ocupado'), findsOneWidget, reason: '19:00 choca con una reunión confirmada');
    await tester.tap(find.text('19:00'));
    await tester.pump();
    expect(find.text('Elige una hora'), findsOneWidget, reason: 'una hora ocupada no se puede elegir');
    await tester.tap(find.text('19:30'));
    await tester.pump();
    await tester.tap(find.text('Proponer 19:30 y abrir chat'));
    await tester.pumpAndSettle();
    expect(f.accepted.single.$1, 'o-sergi');
    expect(f.accepted.single.$2.isAtSameMomentAs(today(19, 30)), isTrue);
    expect(find.text('marta.eng'), findsWidgets, reason: 'tras aceptar se abre el chat');
  });

  testWidgets('chat: tarjeta con ✓/○, mensajes de sistema traducidos, confirmar y enviar', (tester) async {
    final f = await pump(tester, location: '/chat/c1');
    expect(find.text('✓ marta.eng'), findsOneWidget);
    expect(find.text('○ Tú'), findsOneWidget);
    expect(find.text('Mañana · 18:30 · C1'), findsOneWidget);
    expect(find.text('Propusiste Mañana · 18:00'), findsOneWidget);
    expect(find.text('marta.eng cambió la hora a Mañana · 18:30 · confirmaciones reiniciadas'), findsOneWidget);
    expect(find.text('marta.eng ha confirmado ✓'), findsOneWidget);

    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    expect(f.confirms, ['m1']);

    await tester.enterText(find.byType(TextField), '  Perfecto, ahora confirmo ');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump();
    expect(f.sent, ['Perfecto, ahora confirmo']);
  });

  testWidgets('crear reunión: abre con ?create=1, cuenta las ofertas y publica', (tester) async {
    final f = await pump(tester, location: '/agenda?create=1');
    await tester.pumpAndSettle();
    expect(find.text('Puedes tener 2 ofertas activas · te queda 1'), findsOneWidget);
    await tester.tap(find.text('B2').last);
    await tester.pump();
    await tester.tap(find.text('Publicar oferta'));
    await tester.pumpAndSettle();
    expect(f.created.single, (Level.b2, today(17), today(20)));
  });

  testWidgets('crear reunión: con 2 ofertas abiertas el botón está desactivado', (tester) async {
    final fake = FakeAgenda();
    fake.mine = [...fake.mine, fake.mine.first];
    await pump(tester, location: '/agenda?create=1', fake: fake);
    await tester.pumpAndSettle();
    expect(find.text('Puedes tener 2 ofertas activas · no te quedan'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publicar oferta'));
    expect(button.onPressed, isNull);
  });

  test('canEnter respeta −5 min / +10 min y solo confirmadas', () {
    final m = meeting(status: MeetingStatus.confirmed, at: today(19));
    expect(AgendaRules.canEnter(m, today(18, 54)), isFalse);
    expect(AgendaRules.canEnter(m, today(18, 55)), isTrue);
    expect(AgendaRules.canEnter(m, today(19, 10)), isTrue);
    expect(AgendaRules.canEnter(m, today(19, 11)), isFalse);
    expect(AgendaRules.canEnter(meeting(at: today(19)), today(19)), isFalse);
  });
}
