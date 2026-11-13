import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/topic_screen.dart';
import 'services/debate_engine_factory.dart';
import 'state/debate_controller.dart';

void main() {
  runApp(const ResubaArenaApp());
}

class ResubaArenaApp extends StatefulWidget {
  const ResubaArenaApp({super.key});

  @override
  State<ResubaArenaApp> createState() => _ResubaArenaAppState();
}

class _ResubaArenaAppState extends State<ResubaArenaApp> {
  late final DebateController _controller =
      DebateController(engine: createDefaultEngine());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIレスバ アリーナ',
      // ロケールを日本語に固定する。未設定だと端末の既定ロケールで描画され、
      // 漢字の字形やフォントのフォールバックが日本語用にならないことがある。
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE5484D),
          brightness: Brightness.dark,
          surface: const Color(0xFF121830),
        ),
        fontFamilyFallback: const ['Hiragino Sans', 'Noto Sans JP'],
        useMaterial3: true,
      ),
      home: TopicScreen(controller: _controller),
    );
  }
}
