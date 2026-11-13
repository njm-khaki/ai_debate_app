// 動作GIF作成用のフレームキャプチャ。通常のテスト実行では何もしない。
//
// 実行方法:
//   flutter test test/gif_capture_test.dart --update-goldens --dart-define=CAPTURE_GIF=true
// 生成された test/gif_frames/*.png を GIF に組み立てる。
import 'dart:io';

import 'package:ai_resuba/screens/topic_screen.dart';
import 'package:ai_resuba/services/debate_engine_factory.dart';
import 'package:ai_resuba/state/debate_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _captureEnabled = bool.fromEnvironment('CAPTURE_GIF');

// 撮影する討論者（ロスターの表示名）。未指定時は従来のペア。
// 例: --dart-define=CAPTURE_FIRST=池上彰AI --dart-define=CAPTURE_SECOND=落合陽一AI
const _firstName =
    String.fromEnvironment('CAPTURE_FIRST', defaultValue: 'マツコAI');
const _secondName =
    String.fromEnvironment('CAPTURE_SECOND', defaultValue: '松岡修造AI');

Future<void> _loadFont(String family, List<File> files) async {
  final loader = FontLoader(family);
  var added = false;
  for (final file in files) {
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
    added = true;
  }
  if (added) await loader.load();
}

void main() {
  setUpAll(() async {
    if (!_captureEnabled) return;
    // テスト描画環境には日本語フォントがないため、単一フェイスの
    // Noto Sans CJK JP（Regular/Bold）を読み込む。TTCだと太字や一部グリフが欠ける。
    await _loadFont('Noto Sans JP', [
      File('/tmp/fonts/NotoSansCJKjp-Regular.otf'),
      File('/tmp/fonts/NotoSansCJKjp-Bold.otf'),
    ]);
    // MaterialIcons（flutter_tester から artifacts/material_fonts を探す）
    final exe = File(Platform.resolvedExecutable);
    final icons = File(
        '${exe.parent.parent.parent.path}/material_fonts/MaterialIcons-Regular.otf');
    await _loadFont('MaterialIcons', [icons]);
  });

  testWidgets('GIFフレーム撮影', (tester) async {
    if (!_captureEnabled) return;
    await tester.binding.setSurfaceSize(const Size(420, 920));

    var frame = 0;
    Future<void> capture() async {
      final name =
          'gif_frames/frame_${(frame++).toString().padLeft(3, '0')}.png';
      await expectLater(
          find.byType(Scaffold).last, matchesGoldenFile(name));
    }

    // main.dart と同じ構成。テスト描画環境の既定フォントはフォールバックが
    // 効かないため、撮影時のみフォントを明示する（実機ではOSのフォントが使われる）。
    final controller = DebateController(engine: createDefaultEngine());
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Noto Sans JP',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1026),
        useMaterial3: true,
      ),
      home: TopicScreen(controller: controller),
    ));
    await tester.pump(const Duration(seconds: 1));
    await capture();
    await capture();

    // お題を入力
    await tester.enterText(
        find.byType(TextField), '週休3日制は日本で実現すべきか');
    await tester.pump(const Duration(milliseconds: 300));
    await capture();

    // 討論者を選択する（先手 → 後手の順。初期アクティブは先手）
    // ListView/GridView は遅延構築のため、ドラッグしながら探す
    Finder rosterCard(String name) => find.descendant(
        of: find.byType(GridView), matching: find.text(name));
    Future<void> scrollDownTo(Finder target) async {
      for (var i = 0; i < 25 && target.evaluate().isEmpty; i++) {
        await tester.drag(
            find.byType(ListView).first, const Offset(0, -320));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.scrollUntilVisible(target, 80,
          scrollable: find.byType(Scrollable).first);
      await tester.pump(const Duration(milliseconds: 200));
    }

    await scrollDownTo(rosterCard(_firstName));
    await capture();
    await tester.tap(rosterCard(_firstName));
    await tester.pump(const Duration(milliseconds: 300));
    await scrollDownTo(rosterCard(_secondName));
    await tester.tap(rosterCard(_secondName));
    await tester.pump(const Duration(milliseconds: 300));
    await capture();

    // 選択ペアが見える位置まで戻してから開始
    for (var i = 0;
        i < 25 && find.text('討論者を2人選ぶ').evaluate().isEmpty;
        i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, 320));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await capture();
    await scrollDownTo(find.text('バトル開始'));
    await tester.tap(find.text('バトル開始'));
    await tester.pump();

    // 対戦を最後まで進めながら撮影（0.45秒刻み）
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 450));
      await capture();
    }
    // 判定〜結果画面への遷移まで
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 450));
      await capture();
    }

    // 結果画面をスクロールして要約まで見せる
    await capture();
    await tester.drag(find.byType(ListView), const Offset(0, -550));
    await tester.pump(const Duration(milliseconds: 400));
    await capture();
    await capture();
    await tester.drag(find.byType(ListView), const Offset(0, -550));
    await tester.pump(const Duration(milliseconds: 400));
    await capture();
    await capture();

    // 終了時に残っているタイマ（スクロール減衰など）を流し切る
    await tester.pump(const Duration(seconds: 5));
  });
}
