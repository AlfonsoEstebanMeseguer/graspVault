import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/legal/bundled_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('cada fuente e iconos llevan su licencia en el bundle (OFL / MIT)', () async {
    for (final asset in bundledLicenseFiles.values) {
      final text = await rootBundle.loadString(asset);
      expect(text, anyOf(contains('SIL OPEN FONT LICENSE'), contains('MIT License')), reason: asset);
    }
  });
}
