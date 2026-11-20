import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/theming/app_theme.dart';
import 'package:speaking_p2p/data/content/content_repository.dart';
import 'package:speaking_p2p/features/exam/widgets/exam_widgets.dart';
import 'package:speaking_p2p/l10n/app_localizations.dart';

final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

Future<void> _pump(WidgetTester tester, {Map<String, String> files = const {}}) => tester.pumpWidget(ProviderScope(
      overrides: [photoCatalogProvider.overrideWith((ref) async => const PhotoCatalog(captions: {'b1-e01-a1': 'woman trying on a jacket'}))],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: PhotoGrid(assets: const ['b1-e01-a1'], files: files)),
      ),
    ));

void main() {
  testWidgets('sin archivo descargado: la foto vacía muestra la descripción del catálogo', (tester) async {
    await _pump(tester);
    await tester.pump();
    expect(find.textContaining('woman trying on a jacket'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('con la foto descargada de R2: muestra la imagen en lugar del hueco', (tester) async {
    final file = await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('photo_grid');
      addTearDown(() => dir.delete(recursive: true));
      return File('${dir.path}/b1-e01-a1.webp')..writeAsBytesSync(_png);
    });
    await _pump(tester, files: {'b1-e01-a1': file!.path});
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('jacket'), findsNothing);
  });
}
