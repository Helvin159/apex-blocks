import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/themes.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const ApexBlocksApp());
}

class ApexBlocksApp extends StatelessWidget {
  const ApexBlocksApp({super.key});

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
      home: const GameScreen(),
    );
  }
}
