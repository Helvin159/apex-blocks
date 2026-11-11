import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/audio_service.dart';
import 'services/haptics_service.dart';
import 'services/storage_service.dart';
import 'ui/home_screen.dart';
import 'ui/setup_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final storage = await StorageService.open();
  final audio = AudioService();
  await audio.init();
  final haptics = HapticsService();
  applySavedSettings(storage, audio, haptics);
  await _registerFontLicenses();
  runApp(ApexBlocksApp(storage: storage, audio: audio, haptics: haptics));
}

/// Registers the SIL Open Font License texts of the bundled fonts.
Future<void> _registerFontLicenses() async {
  const fonts = {
    'Barlow Condensed': 'assets/fonts/OFL-BarlowCondensed.txt',
    'Inter': 'assets/fonts/OFL-Inter.txt',
  };
  for (final MapEntry(key: name, value: path) in fonts.entries) {
    final text = await rootBundle.loadString(path);
    LicenseRegistry.addLicense(
      () => Stream.value(LicenseEntryWithLineBreaks([name], text)),
    );
  }
}

class ApexBlocksApp extends StatelessWidget {
  final StorageService storage;
  final AudioService? audio;
  final HapticsService? haptics;

  const ApexBlocksApp({
    super.key,
    required this.storage,
    this.audio,
    this.haptics,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) {
        final theme = storage.theme;
        return MaterialApp(
          title: 'Apex Blocks',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: theme.background,
            colorScheme: ColorScheme.dark(
              primary: theme.accent,
              surface: theme.background,
            ),
          ),
          home: HomeScreen(storage: storage, audio: audio, haptics: haptics),
        );
      },
    );
  }
}
