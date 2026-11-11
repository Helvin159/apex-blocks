import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/audio_service.dart';
import 'services/haptics_service.dart';
import 'services/storage_service.dart';
import 'theme/themes.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final storage = await StorageService.open();
  final audio = AudioService();
  await audio.init();
  runApp(
    ApexBlocksApp(storage: storage, audio: audio, haptics: HapticsService()),
  );
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
    return MaterialApp(
      title: 'Apex Blocks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: nightRace.background,
        colorScheme: ColorScheme.dark(
          primary: nightRace.accent,
          surface: nightRace.background,
        ),
      ),
      home: HomeScreen(storage: storage, audio: audio, haptics: haptics),
    );
  }
}
