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

Meeting meeting({
  String id = 'm1',
  MeetingStatus status = MeetingStatus.pending,
  DateTime? at,
  bool creatorOk = false,
  bool acceptorOk = false,
  String? offerId,
  String creator = 'marta',
  String acceptor = 'me',
}) =>
    Meeting(
      id: id,
      offerId: offerId,
      creatorId: creator,
      acceptorId: acceptor,
      level: Level.c1,
      scheduledAt: at ?? DateTime(2026, 10, 16, 18, 30),
      creatorConfirmed: creatorOk,
      acceptorConfirmed: acceptorOk,
      status: status,
    );

class FakeAgenda implements AgendaRepository {
  List<Offer> mine = [
    Offer(id: 'o-mine', creatorId: 'me', level: Level.c1, windowStart: DateTime(2026, 10, 16, 17), windowEnd: DateTime(2026, 10, 16, 20), status: OfferStatus.open, interested: 1),
  ];
  List<Offer> boardOffers = [
    Offer(
      id: 'o-sergi',
      creatorId: 'sergi',
      level: Level.c1,
      windowStart: today(18),
      windowEnd: today(21),
      status: OfferStatus.open,
      creatorName: 'sergi_cae',
      creatorLanguages: const ['es', 'ca', 'en'],
      taken: [today(18, 30)],
    ),
  ];
  List<Meeting> confirmed = [meeting(id: 'm-busy', status: MeetingStatus.confirmed, at: today(19), creatorOk: true, acceptorOk: true)];

  /// marta changed the time and confirmed; I have not yet ("Te toca").
  Meeting card = meeting(creatorOk: true);
  List<ChatSummary> extraChats = [
    ChatSummary(
      chatId: 'c-busy',
      meeting: meeting(id: 'm-busy', status: MeetingStatus.confirmed, at: today(19), creatorOk: true, acceptorOk: true, creator: 'pau'),
      partnerId: 'pau',
      partnerName: 'pau_v',
    ),
    ChatSummary(
      chatId: 'c-booked',
      meeting: meeting(id: 'm-booked', status: MeetingStatus.confirmed, at: DateTime(2026, 10, 16, 17, 30), creatorOk: true, acceptorOk: true, offerId: 'o-mine', creator: 'me', acceptor: 'laura'),
      partnerId: 'laura',
      partnerName: 'laura_m',
    ),
    ChatSummary(
      chatId: 'c-old',
      meeting: meeting(id: 'm-old', status: MeetingStatus.cancelled, at: DateTime(2026, 10, 14, 18), creator: 'joan'),
      partnerId: 'joan',
      partnerName: 'joan_r',
    ),
  ];
  List<Companion> friends = [
    const Companion(partnerId: 'ana', iAdded: true, theyAdded: true, name: 'ana_p', sessionsTogether: 3, lastSessionId: 's-ana'),
    const Companion(partnerId: 'leo', iAdded: false, theyAdded: true, name: 'leo_k', sessionsTogether: 1, lastSessionId: 's-leo'),
  ];
  final accepted = <(String, DateTime)>[];
  final created = <(Level, DateTime, DateTime)>[];
  final invites = <(String, DateTime, Level)>[];
  final added = <String>[];
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
        ...extraChats,
      ].where((c) => chatId == null || c.chatId == chatId).toList();
  @override
  Future<List<Meeting>> myMeetings() async => confirmed;
  @override
  Stream<Meeting> watchMeeting(String meetingId) => Stream.value(card);
  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) => Stream.value([
        ChatMessage(id: '1', senderId: null, kind: 'system', createdAt: today(10), systemCode: 'meeting_booked',
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
    return (meetingId: 'm2', chatId: 'c1');
  }

  @override
  Future<({String meetingId, String chatId})> invite(String partnerId, DateTime at, Level level) async {
    invites.add((partnerId, at, level));
    return (meetingId: 'm3', chatId: 'c1');
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
  @override
  Future<String> enterNow(String meetingId, int contentVersion) async => throw const AppFailure('not_found');
  @override
  Future<List<Companion>> companions() async => friends;
  @override
  Future<void> addCompanion(String sessionId) async => added.add(sessionId);
  @override
  Future<void> removeCompanion(String userId) async {}
}

Future<FakeAgenda> pump(WidgetTester tester, {String location = '/agenda', FakeAgenda? fake}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'target_level': 'C1'});
  final prefs = await SharedPreferences.getInstance();
  final f = fake ?? FakeAgenda();
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(
      path: '/agenda',
      builder: (_, s) => AgendaScreen(openCreate: s.uri.queryParameters['create'] == '1', invite: s.uri.queryParameters['invite']),
    ),
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
  testWidgets('mis exámenes: te toca, próximos, mis propuestas con quién reservó, anteriores', (tester) async {
    final f = await pump(tester);
    expect(find.text('Mis exámenes · 3'), findsOneWidget);
    expect(find.text('TE TOCA'), findsOneWidget);
    expect(find.text('Falta tu confirmación'), findsOneWidget);
    expect(find.text('PRÓXIMOS'), findsOneWidget);
    expect(find.text('Examen C1 con pau_v'), findsOneWidget);
    expect(find.text('MIS PROPUESTAS · 1 DE 2'), findsOneWidget);
    expect(find.text('laura_m · 17:30'), findsOneWidget, reason: 'quien reservó y a qué hora, en mi propuesta');
    expect(find.text('COMPAÑEROS'), findsOneWidget);
    expect(find.text('Invitar'), findsOneWidget);
    expect(find.text('Añadir también'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-m1')));
    await tester.pump();
    expect(f.confirms, ['m1']);

    await tester.scrollUntilVisible(find.text('Anteriores (1)'), 200, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    expect(find.text('Examen C1 con joan_r'), findsNothing, reason: 'las anteriores van plegadas');
    await tester.tap(find.text('Anteriores (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Examen C1 con joan_r'), findsOneWidget);
  });

  testWidgets('buscar horario: huecos en la tarjeta, reservados ocultos, ocupados tachados y reservar', (tester) async {
    final f = await pump(tester);
    await tester.tap(find.byKey(const Key('agenda-tab-board')));
    await tester.pumpAndSettle();
    expect(find.text('sergi_cae'), findsOneWidget);
    expect(find.text('Libre de 18:00 a 21:00'), findsOneWidget);
    expect(f.boardQueries.last, [Level.c1]);
    expect(find.byKey(const Key('slot-o-sergi-18:30')), findsNothing, reason: 'ya reservado por otra persona');
    expect(find.byKey(const Key('slot-o-sergi-19:00')), findsOneWidget, reason: 'choca con mi reunión: se ve tachado');

    await tester.tap(find.byKey(const Key('slot-o-sergi-19:00')));
    await tester.pumpAndSettle();
    expect(find.text('Reservar este hueco'), findsNothing, reason: 'un hueco ocupado no se puede reservar');

    await tester.tap(find.byKey(const Key('board-adjacent')));
    await tester.pumpAndSettle();
    expect(f.boardQueries.last, [Level.c1, Level.b2]);

    await tester.tap(find.byKey(const Key('slot-o-sergi-19:30')));
    await tester.pumpAndSettle();
    expect(find.text('Examen C1 con sergi_cae'), findsOneWidget);
    await tester.tap(find.text('Reservar este hueco'));
    await tester.pumpAndSettle();
    expect(f.accepted.single.$1, 'o-sergi');
    expect(f.accepted.single.$2.isAtSameMomentAs(today(19, 30)), isTrue);
    expect(find.text('marta.eng'), findsWidgets, reason: 'tras reservar se abre el chat');
  });

  testWidgets('chat: pasos de confirmación, mensajes de sistema, confirmar, enviar y respuestas rápidas', (tester) async {
    final f = await pump(tester, location: '/chat/c1');
    expect(find.text('Propuesta ✓'), findsOneWidget);
    expect(find.text('marta.eng ✓'), findsOneWidget);
    expect(find.text('Tú'), findsOneWidget);
    expect(find.text('Mañana · 18:30 · C1'), findsOneWidget);
    expect(find.text('Reservaste Mañana · 18:00'), findsOneWidget);
    expect(find.text('marta.eng propone cambiar a Mañana · 18:30'), findsOneWidget);
    expect(find.text('marta.eng ha confirmado ✓'), findsOneWidget);

    await tester.tap(find.byKey(const Key('card-confirm')));
    await tester.pump();
    expect(f.confirms, ['m1']);

    await tester.enterText(find.byType(TextField), '  Perfecto, ahora confirmo ');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump();
    await tester.tap(find.text('Llego 5 min tarde'));
    await tester.pump();
    expect(f.sent, ['Perfecto, ahora confirmo', 'Llego 5 min tarde']);
  });

  testWidgets('chat: una reunión cancelada deja el chat en solo lectura', (tester) async {
    final fake = FakeAgenda()..card = meeting(status: MeetingStatus.cancelled);
    await pump(tester, location: '/chat/c1', fake: fake);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Este chat ya se cerró: solo sirve para organizar su reunión.'), findsOneWidget);
  });

  testWidgets('compañeros: invitar a un compañero mutuo con día, hora y nivel', (tester) async {
    final f = await pump(tester);
    await tester.tap(find.byKey(const Key('companion-ana')));
    await tester.pumpAndSettle();
    expect(find.text('3 exámenes juntos'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Invitar'));
    await tester.pumpAndSettle();
    expect(find.text('Invitar a ana_p'), findsOneWidget);
    await tester.tap(find.text('Mañana'));
    await tester.pump();
    await tester.ensureVisible(find.text('10:00'));
    await tester.tap(find.text('10:00'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('send-invite')));
    await tester.pumpAndSettle();
    expect(f.invites.single.$1, 'ana');
    expect(f.invites.single.$2.isAtSameMomentAs(DateTime(2026, 10, 16, 10)), isTrue);
    expect(f.invites.single.$3, Level.c1);
  });

  testWidgets('compañeros: añadir también a quien ya me añadió', (tester) async {
    final f = await pump(tester);
    await tester.tap(find.byKey(const Key('companion-leo')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Añadir también'));
    await tester.pumpAndSettle();
    expect(f.added, ['s-leo']);
  });

  testWidgets('"Repetir con…" abre la invitación con ?invite=', (tester) async {
    await pump(tester, location: '/agenda?invite=ana');
    await tester.pumpAndSettle();
    expect(find.text('Invitar a ana_p'), findsOneWidget);
  });

  testWidgets('proponer horario: abre con ?create=1, cuenta las propuestas y publica', (tester) async {
    final f = await pump(tester, location: '/agenda?create=1');
    await tester.pumpAndSettle();
    expect(find.text('Puedes tener 2 propuestas abiertas · te queda 1'), findsOneWidget);
    await tester.tap(find.text('B2').last);
    await tester.pump();
    await tester.tap(find.text('Publicar propuesta'));
    await tester.pumpAndSettle();
    expect(f.created.single, (Level.b2, today(17), today(20)));
  });

  testWidgets('proponer horario: con 2 propuestas abiertas el botón está desactivado', (tester) async {
    final fake = FakeAgenda();
    fake.mine = [...fake.mine, fake.mine.first];
    await pump(tester, location: '/agenda?create=1', fake: fake);
    await tester.pumpAndSettle();
    expect(find.text('Puedes tener 2 propuestas abiertas · no te quedan'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publicar propuesta'));
    expect(button.onPressed, isNull);
  });

  testWidgets('sin nada mío la agenda abre en "Buscar horario"', (tester) async {
    final fake = FakeAgenda()
      ..mine = []
      ..extraChats = []
      ..card = meeting(status: MeetingStatus.closed);
    await pump(tester, fake: fake);
    await tester.pumpAndSettle();
    expect(find.text('sergi_cae'), findsOneWidget);
  });

  testWidgets('«Mis exámenes» vacío: el círculo naranja abre «Proponer horario» (D-050)', (tester) async {
    final fake = FakeAgenda()
      ..mine = []
      ..extraChats = []
      ..card = meeting(status: MeetingStatus.closed);
    await pump(tester, fake: fake);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agenda-tab-mine')));
    // The rings pulse forever: pumpAndSettle would never settle.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('agenda-pulse')), findsOneWidget);
    await tester.tap(find.byKey(const Key('agenda-pulse')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Publicar propuesta'), findsOneWidget, reason: 'se abre la hoja de proponer');
  });

  testWidgets('«Buscar horario» sin propuestas: el mismo círculo naranja abre «Proponer horario»', (tester) async {
    final fake = FakeAgenda()
      ..mine = []
      ..extraChats = []
      ..boardOffers = []
      ..card = meeting(status: MeetingStatus.closed);
    await pump(tester, fake: fake);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('board-pulse')), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Proponer el mío'), findsNothing, reason: 'el botón antiguo ya no está');
    await tester.tap(find.byKey(const Key('board-pulse')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Publicar propuesta'), findsOneWidget);
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
