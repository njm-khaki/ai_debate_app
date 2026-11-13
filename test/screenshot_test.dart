// 画面の見た目確認用ゴールデンテスト。
// 実行: flutter test test/screenshot_test.dart --update-goldens
// 生成されたPNGは目視確認用で、通常のCIでは比較対象として使う。
import 'package:ai_resuba/models/debate_models.dart';
import 'package:ai_resuba/screens/battle_screen.dart';
import 'package:ai_resuba/screens/result_screen.dart';
import 'package:ai_resuba/state/debate_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _config = BattleConfig(
  topic: '週休3日制は日本で実現すべきか',
  first: DebaterId.hiroyuki,
      second: DebaterId.horiemon,
      firstStance: Stance.pro,
  maxRounds: 4,
  entertainmentTone: true,
);

Widget _wrap(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B1020),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE5484D),
        brightness: Brightness.dark,
        surface: const Color(0xFF121830),
      ),
      useMaterial3: true,
    ),
    home: child,
  );
}

void main() {
  testWidgets('screenshot: battle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 920));
    final controller = DebateController();
    await tester.pumpWidget(_wrap(BattleScreen(
      controller: controller,
      config: _config,
    )));
    // VS演出 → 対戦開始 → 数ターン進める（フェイク時間で前進）
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await expectLater(
      find.byType(BattleScreen),
      matchesGoldenFile('goldens/battle.png'),
    );
    // 最後まで進めてタイマーを残さない
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  });

  testWidgets('screenshot: result', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 920));
    final controller = DebateController()
      ..config = _config
      ..result = const BattleResult(
        winnerId: DebaterId.hiroyuki,
        scores: {
          DebaterId.hiroyuki: ScoreBreakdown(
              logic: 86, evidence: 78, rebuttal: 82, humor: 64),
          DebaterId.horiemon: ScoreBreakdown(
              logic: 68, evidence: 74, rebuttal: 61, humor: 79),
        },
        judgeReason:
            'ひろゆきAIは「論理性」でホリエモンAIを上回りました。特に相手の主張の弱い部分を的確に突き、最後まで論点がぶれなかった点が決め手です。',
        conclusion: '「週休3日制は日本で実現すべきか」には条件付きで賛成。決め手は論理性でした。',
        proPoints: [
          '導入にかかるコストより、得られるリターンの方が大きい',
          '個人の選択肢が増えて、合わない人が無理をしなくて済む',
          '古い慣習に合わせ続けるより、仕組み自体を変えた方が早い',
        ],
        conPoints: [
          '現場の運用が追いつかず、結局あちこちで混乱する',
          '得をする人と損をする人の差が広がってしまう',
          'メリットが声の大きい一部の人に偏っている',
        ],
        summaryText:
            '賛成側は現状維持のコストを問い続け、反対側は現場への影響と公平性から反論しました。終盤は論理性をめぐる応酬が焦点となりました。',
      );
    await tester.pumpWidget(_wrap(ResultScreen(controller: controller)));
    await tester.pump();
    await expectLater(
      find.byType(ResultScreen),
      matchesGoldenFile('goldens/result.png'),
    );
  });
}
