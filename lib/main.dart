import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/themes.dart';
import 'services/storage_service.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final storage = await StorageService.open();
  runApp(ApexBlocksApp(storage: storage));
}

class ApexBlocksApp extends StatelessWidget {
  final StorageService storage;

  const ApexBlocksApp({super.key, required this.storage});

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
      home: HomeScreen(storage: storage),
    );
  }
}
