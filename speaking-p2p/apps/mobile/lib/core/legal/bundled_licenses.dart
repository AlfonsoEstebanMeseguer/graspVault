// Licences of what ships inside the app and is not a Dart package: the fonts
// (SIL OFL 1.1 asks for its text to travel with the font) and the Phosphor
// icons (MIT). Flutter already lists the packages; this adds the rest to the
// same page (Settings > Open-source licences). docs/legal/ASPECTOS_A_COMPLETAR.md §13.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const bundledLicenseFiles = {
  'Instrument Sans': 'assets/fonts/OFL-instrumentsans.txt',
  'Newsreader': 'assets/fonts/OFL-newsreader.txt',
  'IBM Plex Mono': 'assets/fonts/OFL-ibmplexmono.txt',
  'Caveat': 'assets/fonts/OFL-caveat.txt',
  'Phosphor Icons': 'assets/fonts/LICENSE-phosphor.txt',
};

/// Once, from main(). Lazy: the files are read only when the page opens.
void registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: name, value: asset) in bundledLicenseFiles.entries) {
      yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString(asset));
    }
  });
}
