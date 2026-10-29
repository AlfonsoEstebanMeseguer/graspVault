import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speaking_p2p/core/l10n/l10n.dart';
import 'package:speaking_p2p/core/theming/app_theme.dart';
import 'package:speaking_p2p/core/theming/preferences.dart';
import 'package:speaking_p2p/data/account/account_repository.dart';
import 'package:speaking_p2p/data/profile/avatar_repository.dart';
import 'package:speaking_p2p/data/profile/profile_repository.dart';
import 'package:speaking_p2p/domain/account/account.dart';
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/features/agenda/agenda_common.dart';
import 'package:speaking_p2p/features/profile/avatar/avatar_image.dart';
import 'package:speaking_p2p/features/profile/avatar/avatar_sheet.dart';
import 'package:speaking_p2p/features/profile/avatar/crop_geometry.dart';
import 'package:speaking_p2p/features/profile/profile_screen.dart';

import 'profile_settings_test.dart' show FakeAccount;

final _webp = Uint8List.fromList([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, 1, 2, 3]);
final _jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2]);

class FakeAvatars implements AvatarRepository {
  final uploads = <(int, String)>[];
  var removed = 0;
  String? failWith;
  @override
  Future<void> upload(Uint8List bytes, String mimeType) async {
    if (failWith != null) throw AppFailure(failWith!);
    uploads.add((bytes.length, mimeType));
  }

  @override
  Future<void> remove() async => removed++;
  @override
  Future<Uint8List?> download(String userId) async => null;
}

void main() {
  group('formato', () {
    test('se reconoce por los bytes, no por lo que se pidió', () {
      expect(sniffAvatarFormat(_webp), AvatarFormat.webp);
      expect(sniffAvatarFormat(_jpeg), AvatarFormat.jpeg);
      expect(sniffAvatarFormat(Uint8List.fromList([0x89, 0x50, 0x4e, 0x47])), isNull); // PNG
    });

    test('WebP si el móvil lo sabe codificar', () async {
      final r = await prepareAvatar(Uint8List(1), encode: (_, f, q) async => f == AvatarFormat.webp ? _webp : _jpeg);
      expect(r.mimeType, 'image/webp');
    });

    test('sin códec WebP (o si devuelve otra cosa) cae a JPEG y lo declara como JPEG', () async {
      final a = await prepareAvatar(Uint8List(1), encode: (_, f, q) async => f == AvatarFormat.webp ? null : _jpeg);
      expect(a.mimeType, 'image/jpeg');
      final b = await prepareAvatar(Uint8List(1), encode: (_, f, q) async => _jpeg);
      expect(b.mimeType, 'image/jpeg');
    });

    test('baja la calidad hasta que cabe', () async {
      final tried = <int>[];
      final r = await prepareAvatar(Uint8List(1), encode: (_, f, q) async {
        tried.add(q);
        return q > 60 ? Uint8List.fromList([..._webp, ...Uint8List(maxAvatarBytes)]) : _webp;
      });
      expect(tried, [85, 70, 55]);
      expect(r.bytes, _webp);
    });
  });

  group('recorte', () {
    const img = Size(1000, 500);
    final child = coverSize(imageSize: img, viewportSide: 300);

    test('sin gestos, el cuadrado central de la imagen... desde la izquierda', () {
      expect(child, const Size(600, 300));
      final r = computeCropRect(matrix: Matrix4.identity(), viewportSide: 300, childSize: child, imageSize: img);
      expect(r, const Rect.fromLTWH(0, 0, 500, 500));
    });

    test('zoom x2 desplazado: se sube exactamente lo que se ve', () {
      final m = Matrix4.identity()
        ..translateByDouble(-300, -150, 0, 1)
        ..scaleByDouble(2, 2, 1, 1);
      final r = computeCropRect(matrix: m, viewportSide: 300, childSize: child, imageSize: img);
      expect(r.left, closeTo(250, 0.01));
      expect(r.top, closeTo(125, 0.01));
      expect(r.width, closeTo(250, 0.01));
      expect(r.height, closeTo(250, 0.01));
    });
  });

  group('hoja de foto', () {
    Future<FakeAvatars> pump(WidgetTester tester, {String? avatarKey, Uint8List? picked}) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final avatars = FakeAvatars();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(FakeAccount()),
          avatarRepositoryProvider.overrideWithValue(avatars),
          avatarPickerProvider.overrideWithValue((_) async => picked),
          avatarCropProvider.overrideWithValue((_, bytes) async => bytes),
          avatarEncoderProvider.overrideWithValue((_, f, q) async => f == AvatarFormat.webp ? _webp : _jpeg),
          sharedPreferencesProvider.overrideWithValue(prefs),
          agendaClockProvider.overrideWithValue(() => DateTime(2026, 10, 15, 16)),
          myProfileProvider.overrideWith(
              (ref) async => MyProfile(id: 'me', username: 'laura_m', languages: const ['es'], targetLevel: Level.c1, avatarKey: avatarKey)),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: const ProfileScreen(),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.byKey(const Key('profile-avatar')));
      await tester.pumpAndSettle();
      return avatars;
    }

    testWidgets('elegir de la galería sube WebP y cierra la hoja', (tester) async {
      final avatars = await pump(tester, picked: Uint8List(10));
      expect(find.byKey(const Key('avatar-remove')), findsNothing); // sin foto, no hay nada que quitar
      await tester.tap(find.byKey(const Key('avatar-gallery')));
      await tester.pumpAndSettle();
      expect(avatars.uploads, [(_webp.length, 'image/webp')]);
      expect(find.text('Foto actualizada'), findsOneWidget);
      expect(find.byKey(const Key('avatar-gallery')), findsNothing);
    });

    testWidgets('cancelar el selector no es un error ni sube nada', (tester) async {
      final avatars = await pump(tester);
      await tester.tap(find.byKey(const Key('avatar-camera')));
      await tester.pumpAndSettle();
      expect(avatars.uploads, isEmpty);
      expect(find.byKey(const Key('avatar-camera')), findsOneWidget);
    });

    testWidgets('si falla, el error se ve dentro de la hoja para reintentar', (tester) async {
      final avatars = await pump(tester, picked: Uint8List(10));
      avatars.failWith = 'invalid_image';
      await tester.tap(find.byKey(const Key('avatar-gallery')));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo subir la foto'), findsOneWidget);
      expect(find.byKey(const Key('avatar-gallery')), findsOneWidget);
    });

    testWidgets('con foto, se puede quitar', (tester) async {
      final avatars = await pump(tester, avatarKey: 'avatars/me/x.webp');
      await tester.tap(find.byKey(const Key('avatar-remove')));
      await tester.pumpAndSettle();
      expect(avatars.removed, 1);
      expect(find.text('Foto eliminada'), findsOneWidget);
    });
  });
}
