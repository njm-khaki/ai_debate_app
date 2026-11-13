import 'package:ai_resuba/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('アプリのロケールが日本語（ja）に固定されている', (tester) async {
    await tester.pumpWidget(const ResubaArenaApp());
    await tester.pump();

    final context = tester.element(find.byType(Scaffold).first);
    expect(Localizations.localeOf(context), const Locale('ja'));
  });

  testWidgets('お題入力画面が表示される', (tester) async {
    await tester.pumpWidget(const ResubaArenaApp());
    await tester.pump();

    expect(find.text('AIレスバ アリーナ'), findsOneWidget);
    // ロスターはスクロール領域の下部にあるため、表示されるまでスクロールする
    // （「ひろゆきAI」はスロットカード側にも出るため、グリッド内に限定する）
    final hiroyukiInRoster = find.descendant(
      of: find.byType(GridView),
      matching: find.text('ひろゆきAI'),
    );
    await tester.scrollUntilVisible(
      hiroyukiInRoster,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(hiroyukiInRoster, findsOneWidget);
    expect(find.text('ホリエモンAI'), findsWidgets);
    // 開始ボタンはスクロール領域の下部にあるため、表示されるまでスクロールする
    await tester.scrollUntilVisible(
      find.text('バトル開始'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('バトル開始'), findsOneWidget);
  });
}
