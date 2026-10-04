import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/bouncestrike_constants.dart';
import 'ui/bouncestrike_game.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock screen orientation to Portrait for mobile store compliance
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B0E1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const BounceStrikeApp());
}

class BounceStrikeApp extends StatelessWidget {
  const BounceStrikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: BounceStrikeConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E676),
        ),
        useMaterial3: true,
      ),
      home: const BounceStrikeGame(),
    );
  }
}
