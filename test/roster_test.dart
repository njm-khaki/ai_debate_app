import 'dart:io';

import 'package:ai_resuba/models/debate_models.dart';
import 'package:ai_resuba/screens/topic_screen.dart';
import 'package:ai_resuba/services/mock_debate_engine.dart';
import 'package:ai_resuba/state/debate_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// ロスター（20人）とペア選択のテスト。
void main() {
  group('ロスター定義', () {
    test('20人全員が定義され、色とアバターが重複しない', () {
      expect(allDebaters.length, 20);
      expect(allDebaters.map((d) => d.id).toSet().length, 20);
      expect(allDebaters.map((d) => d.color).toSet().length, 20);
      expect(allDebaters.map((d) => d.avatarAsset).toSet().length, 20);
      for (final id in DebaterId.values) {
        expect(debaterOf(id).id, id);
      }
    });

    test('パラメータの方向性：修造は熱量最大・論理低、池上は熱量最小', () {
      expect(debaterOf(DebaterId.shuzo).paramHeat, greaterThan(5));
      expect(debaterOf(DebaterId.shuzo).paramLogic,
          lessThan(debaterOf(DebaterId.hiroyuki).paramLogic));
      expect(debaterOf(DebaterId.ikegami).paramHeat, 1);
      expect(debaterOf(DebaterId.matsuko).bias.humor, greaterThan(1.2));
    });

    test('パラメータの方向性：進次郎は論理最小級、なんJ民は熱量最大・ユーモア倍率最大', () {
      expect(debaterOf(DebaterId.koizumi).paramLogic, 1);
      expect(debaterOf(DebaterId.koizumi).bias.logic, lessThan(0.6));
      expect(debaterOf(DebaterId.nanji).paramHeat, greaterThan(5));
      expect(debaterOf(DebaterId.nanji).bias.humor,
          greaterThan(debaterOf(DebaterId.matsuko).bias.humor));
    });

    test('パラメータの方向性：カズレーザーは論理・根拠トップ級、関は論理最小・自称根拠', () {
      expect(debaterOf(DebaterId.kazlaser).paramLogic, 5);
      expect(debaterOf(DebaterId.kazlaser).bias.evidence,
          greaterThan(debaterOf(DebaterId.ikegami).bias.evidence));
      expect(debaterOf(DebaterId.seki).paramLogic, 1);
      expect(debaterOf(DebaterId.seki).bias.logic, lessThan(0.5));
      expect(debaterOf(DebaterId.seki).bias.evidence, greaterThan(1.0));
    });

    test('パラメータの方向性：第3弾5人の個性（徹子の共感・細木の占い・和田の反論・ジミーのユーモア・出川の熱量）',
        () {
      expect(debaterOf(DebaterId.tetsuko).paramEmpathy, 5);
      expect(debaterOf(DebaterId.hosoki).bias.logic,
          lessThan(debaterOf(DebaterId.koizumi).bias.logic));
      expect(debaterOf(DebaterId.hosoki).bias.evidence, greaterThan(1.0));
      expect(debaterOf(DebaterId.wada).bias.rebuttal,
          greaterThan(debaterOf(DebaterId.shuzo).bias.rebuttal));
      expect(debaterOf(DebaterId.jimmy).bias.humor,
          greaterThan(debaterOf(DebaterId.matsuko).bias.humor));
      expect(debaterOf(DebaterId.jimmy).bias.humor,
          lessThan(debaterOf(DebaterId.nanji).bias.humor));
      expect(debaterOf(DebaterId.degawa).paramHeat, 5);
    });

    test('パラメータの方向性：第4弾5人の個性（ナガノの共感ゼロ・ちい〇わの最弱・う〇ぎの熱量最大級）',
        () {
      // ナガノ：サイコパス設定で共感は全員で唯一の0、反論は和田に次ぐ水準
      expect(debaterOf(DebaterId.nagano).paramEmpathy, 0);
      expect(debaterOf(DebaterId.nagano).bias.rebuttal,
          greaterThanOrEqualTo(debaterOf(DebaterId.shuzo).bias.rebuttal));
      // ちい〇わ：議論できないネタ枠で、論理倍率は細木（0.3）を下回る全員最弱
      expect(debaterOf(DebaterId.chiikawa).bias.logic,
          lessThan(debaterOf(DebaterId.hosoki).bias.logic));
      expect(debaterOf(DebaterId.chiikawa).paramEmpathy, 5);
      // ハチ〇レ：まともに議論できる中位（進次郎より論理が高い）
      expect(debaterOf(DebaterId.hachiware).paramLogic,
          greaterThan(debaterOf(DebaterId.koizumi).paramLogic));
      // う〇ぎ：奇声ネタ枠。熱量は修造・なんJ民と同じ最大級、ユーモアはなんJ民に次ぐ
      expect(debaterOf(DebaterId.usagi).paramHeat, greaterThan(5));
      expect(debaterOf(DebaterId.usagi).bias.humor,
          lessThan(debaterOf(DebaterId.nanji).bias.humor));
      expect(debaterOf(DebaterId.usagi).bias.humor,
          greaterThan(debaterOf(DebaterId.matsuko).bias.humor));
      // モ〇ンガ：あざとい枠。反論は標準（1.0）で、論理・根拠は低め
      expect(debaterOf(DebaterId.momonga).bias.rebuttal, 1.0);
      expect(debaterOf(DebaterId.momonga).bias.logic, lessThan(0.8));
    });
  });

  group('BattleConfig（任意ペア）', () {
    const cfg = BattleConfig(
      topic: 'テスト',
      first: DebaterId.shuzo,
      second: DebaterId.ikegami,
      firstStance: Stance.con,
      maxRounds: 3,
      entertainmentTone: true,
    );

    test('stanceOf / opponentOf がペアで解決される', () {
      expect(cfg.stanceOf(DebaterId.shuzo), Stance.con);
      expect(cfg.stanceOf(DebaterId.ikegami), Stance.pro);
      expect(cfg.opponentOf(DebaterId.shuzo), DebaterId.ikegami);
      expect(cfg.opponentOf(DebaterId.ikegami), DebaterId.shuzo);
    });

    test('nextSpeaker は先手から交互', () {
      BattleContext ctx(int turns) => BattleContext(
            config: cfg,
            history: [
              for (var i = 0; i < turns; i++)
                DebateMessage.debater(
                    i.isEven ? DebaterId.shuzo : DebaterId.ikegami, 'x', i),
            ],
            rawScores: const {},
            momentum: 50,
          );
      expect(ctx(0).nextSpeaker, DebaterId.shuzo);
      expect(ctx(1).nextSpeaker, DebaterId.ikegami);
      expect(ctx(2).nextSpeaker, DebaterId.shuzo);
    });
  });

  group('モックエンジン（新ペルソナ）', () {
    final engine = LocalMockDebateEngine();

    BattleContext ctxFor(DebaterId first, DebaterId second,
            {double momentum = 50}) =>
        BattleContext(
          config: BattleConfig(
            topic: '週休3日制は日本で実現すべきか',
            first: first,
            second: second,
            firstStance: Stance.pro,
            maxRounds: 4,
            entertainmentTone: true,
          ),
          history: const [],
          rawScores: const {},
          momentum: momentum,
        );

    test('追加18人とも先手として発言できる', () async {
      for (final id in [
        DebaterId.shuzo,
        DebaterId.matsuko,
        DebaterId.ikegami,
        DebaterId.ochiai,
        DebaterId.koizumi,
        DebaterId.nanji,
        DebaterId.kazlaser,
        DebaterId.seki,
        DebaterId.tetsuko,
        DebaterId.hosoki,
        DebaterId.wada,
        DebaterId.jimmy,
        DebaterId.degawa,
        DebaterId.nagano,
        DebaterId.chiikawa,
        DebaterId.hachiware,
        DebaterId.usagi,
        DebaterId.momonga,
      ]) {
        final turn = await engine.nextTurn(ctxFor(id, DebaterId.hiroyuki));
        expect(turn.message.debaterId, id);
        expect(turn.message.text, isNotEmpty);
      }
    });

    test('進次郎は進次郎構文、なんJ民はなんJ語で話す', () async {
      final koizumi =
          await engine.nextTurn(ctxFor(DebaterId.koizumi, DebaterId.hiroyuki));
      expect(koizumi.message.text, contains('ということ'));
      final nanji =
          await engine.nextTurn(ctxFor(DebaterId.nanji, DebaterId.hiroyuki));
      expect(nanji.message.text, contains('ワイ'));
      expect(nanji.message.text, contains('やで'));
    });

    test('カズレーザーは豆知識、関は都市伝説の口調で話す', () async {
      final kaz =
          await engine.nextTurn(ctxFor(DebaterId.kazlaser, DebaterId.hiroyuki));
      expect(kaz.message.text, contains('ちなみに'));
      final seki =
          await engine.nextTurn(ctxFor(DebaterId.seki, DebaterId.hiroyuki));
      expect(seki.message.text, contains('偶然'));
    });

    test('第3弾5人がそれぞれの口調で話す', () async {
      final tetsuko =
          await engine.nextTurn(ctxFor(DebaterId.tetsuko, DebaterId.hiroyuki));
      expect(tetsuko.message.text, contains('ねえ'));
      final hosoki =
          await engine.nextTurn(ctxFor(DebaterId.hosoki, DebaterId.hiroyuki));
      expect(hosoki.message.text, contains('ズバリ'));
      final wada =
          await engine.nextTurn(ctxFor(DebaterId.wada, DebaterId.hiroyuki));
      expect(wada.message.text, contains('あのね'));
      final jimmy =
          await engine.nextTurn(ctxFor(DebaterId.jimmy, DebaterId.hiroyuki));
      expect(jimmy.message.text, contains('ボク'));
      final degawa =
          await engine.nextTurn(ctxFor(DebaterId.degawa, DebaterId.hiroyuki));
      expect(degawa.message.text, contains('ヤバいよ'));
    });

    test('修造 vs マツコで最後まで対戦でき、勝者はどちらかになる', () async {
      var ctx = ctxFor(DebaterId.shuzo, DebaterId.matsuko);
      final messages = <DebateMessage>[];
      final scores = <DebaterId, ScoreBreakdown>{
        DebaterId.shuzo: ScoreBreakdown.zero,
        DebaterId.matsuko: ScoreBreakdown.zero,
      };
      var momentum = 50.0;
      while (messages.where((m) => m.kind == SpeakerKind.debater).length <
          ctx.totalTurns) {
        ctx = BattleContext(
          config: ctx.config,
          history: List.of(messages),
          rawScores: Map.of(scores),
          momentum: momentum,
        );
        final turn = await engine.nextTurn(ctx);
        messages.add(turn.message);
        final id = turn.message.debaterId!;
        scores[id] = scores[id]! + turn.rawScore;
        momentum = (momentum + turn.momentumDelta).clamp(8, 92);
      }
      final result = await engine.judgeAndSummarize(BattleContext(
        config: ctx.config,
        history: messages,
        rawScores: scores,
        momentum: momentum,
      ));
      expect(result.scores.keys.toSet(),
          {DebaterId.shuzo, DebaterId.matsuko});
      expect([DebaterId.shuzo, DebaterId.matsuko], contains(result.winnerId));
      expect(result.judgeReason, contains(debaterOf(result.winnerId).name));
    });

    test('進次郎 vs なんJ民で最後まで対戦でき、勝者はどちらかになる', () async {
      var ctx = ctxFor(DebaterId.koizumi, DebaterId.nanji);
      final messages = <DebateMessage>[];
      final scores = <DebaterId, ScoreBreakdown>{
        DebaterId.koizumi: ScoreBreakdown.zero,
        DebaterId.nanji: ScoreBreakdown.zero,
      };
      var momentum = 50.0;
      while (messages.where((m) => m.kind == SpeakerKind.debater).length <
          ctx.totalTurns) {
        ctx = BattleContext(
          config: ctx.config,
          history: List.of(messages),
          rawScores: Map.of(scores),
          momentum: momentum,
        );
        final turn = await engine.nextTurn(ctx);
        messages.add(turn.message);
        final id = turn.message.debaterId!;
        scores[id] = scores[id]! + turn.rawScore;
        momentum = (momentum + turn.momentumDelta).clamp(8, 92);
      }
      final result = await engine.judgeAndSummarize(BattleContext(
        config: ctx.config,
        history: messages,
        rawScores: scores,
        momentum: momentum,
      ));
      expect(result.scores.keys.toSet(),
          {DebaterId.koizumi, DebaterId.nanji});
      expect([DebaterId.koizumi, DebaterId.nanji], contains(result.winnerId));
    });

    test('カズレーザー vs 関で最後まで対戦でき、勝者はどちらかになる', () async {
      var ctx = ctxFor(DebaterId.kazlaser, DebaterId.seki);
      final messages = <DebateMessage>[];
      final scores = <DebaterId, ScoreBreakdown>{
        DebaterId.kazlaser: ScoreBreakdown.zero,
        DebaterId.seki: ScoreBreakdown.zero,
      };
      var momentum = 50.0;
      while (messages.where((m) => m.kind == SpeakerKind.debater).length <
          ctx.totalTurns) {
        ctx = BattleContext(
          config: ctx.config,
          history: List.of(messages),
          rawScores: Map.of(scores),
          momentum: momentum,
        );
        final turn = await engine.nextTurn(ctx);
        messages.add(turn.message);
        final id = turn.message.debaterId!;
        scores[id] = scores[id]! + turn.rawScore;
        momentum = (momentum + turn.momentumDelta).clamp(8, 92);
      }
      final result = await engine.judgeAndSummarize(BattleContext(
        config: ctx.config,
        history: messages,
        rawScores: scores,
        momentum: momentum,
      ));
      expect(
          result.scores.keys.toSet(), {DebaterId.kazlaser, DebaterId.seki});
      expect([DebaterId.kazlaser, DebaterId.seki], contains(result.winnerId));
    });

    test('黒柳 vs 出川で最後まで対戦でき、勝者はどちらかになる', () async {
      var ctx = ctxFor(DebaterId.tetsuko, DebaterId.degawa);
      final messages = <DebateMessage>[];
      final scores = <DebaterId, ScoreBreakdown>{
        DebaterId.tetsuko: ScoreBreakdown.zero,
        DebaterId.degawa: ScoreBreakdown.zero,
      };
      var momentum = 50.0;
      while (messages.where((m) => m.kind == SpeakerKind.debater).length <
          ctx.totalTurns) {
        ctx = BattleContext(
          config: ctx.config,
          history: List.of(messages),
          rawScores: Map.of(scores),
          momentum: momentum,
        );
        final turn = await engine.nextTurn(ctx);
        messages.add(turn.message);
        final id = turn.message.debaterId!;
        scores[id] = scores[id]! + turn.rawScore;
        momentum = (momentum + turn.momentumDelta).clamp(8, 92);
      }
      final result = await engine.judgeAndSummarize(BattleContext(
        config: ctx.config,
        history: messages,
        rawScores: scores,
        momentum: momentum,
      ));
      expect(result.scores.keys.toSet(), {DebaterId.tetsuko, DebaterId.degawa});
      expect([DebaterId.tetsuko, DebaterId.degawa], contains(result.winnerId));
    });

    test('第4弾5人がそれぞれの口調で話す', () async {
      final nagano =
          await engine.nextTurn(ctxFor(DebaterId.nagano, DebaterId.hiroyuki));
      expect(nagano.message.text, contains('ふふ'));
      final chiikawa = await engine
          .nextTurn(ctxFor(DebaterId.chiikawa, DebaterId.hiroyuki));
      expect(chiikawa.message.text, contains('わぁ'));
      final hachiware = await engine
          .nextTurn(ctxFor(DebaterId.hachiware, DebaterId.hiroyuki));
      expect(hachiware.message.text, contains('ぼく'));
      final usagi =
          await engine.nextTurn(ctxFor(DebaterId.usagi, DebaterId.hiroyuki));
      expect(usagi.message.text, contains('プルヤ'));
      final momonga = await engine
          .nextTurn(ctxFor(DebaterId.momonga, DebaterId.hiroyuki));
      expect(momonga.message.text, contains('ボク'));
    });

    test('ナガノ vs モ〇ンガ／ちい〇わ vs う〇ぎ で最後まで対戦できる', () async {
      Future<void> expectBattleCompletes(
          DebaterId first, DebaterId second) async {
        var ctx = ctxFor(first, second);
        final messages = <DebateMessage>[];
        final scores = <DebaterId, ScoreBreakdown>{
          first: ScoreBreakdown.zero,
          second: ScoreBreakdown.zero,
        };
        var momentum = 50.0;
        while (messages.where((m) => m.kind == SpeakerKind.debater).length <
            ctx.totalTurns) {
          ctx = BattleContext(
            config: ctx.config,
            history: List.of(messages),
            rawScores: Map.of(scores),
            momentum: momentum,
          );
          final turn = await engine.nextTurn(ctx);
          messages.add(turn.message);
          final id = turn.message.debaterId!;
          scores[id] = scores[id]! + turn.rawScore;
          momentum = (momentum + turn.momentumDelta).clamp(8, 92);
        }
        final result = await engine.judgeAndSummarize(BattleContext(
          config: ctx.config,
          history: messages,
          rawScores: scores,
          momentum: momentum,
        ));
        expect(result.scores.keys.toSet(), {first, second});
        expect([first, second], contains(result.winnerId));
      }

      await expectBattleCompletes(DebaterId.nagano, DebaterId.momonga);
      await expectBattleCompletes(DebaterId.chiikawa, DebaterId.usagi);
    });

    test('修造の逆境燃焼：劣勢時の方が反論スコアが高い', () async {
      final ahead =
          await engine.nextTurn(ctxFor(DebaterId.shuzo, DebaterId.hiroyuki, momentum: 80));
      final behind = await engine
          .nextTurn(ctxFor(DebaterId.shuzo, DebaterId.hiroyuki, momentum: 20));
      expect(behind.rawScore.rebuttal, greaterThan(ahead.rawScore.rebuttal));
    });
  });

  group('討論者選択UI', () {
    Finder rosterCard(String name) => find.descendant(
        of: find.byType(GridView), matching: find.text(name));

    Future<DebateController> pumpTopic(WidgetTester tester) async {
      final controller = DebateController();
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      await tester.pumpWidget(MaterialApp(home: TopicScreen(controller: controller)));
      await tester.pump();
      return controller;
    }

    testWidgets('ロスターから選ぶとスロットが入れ替わり、開始設定に反映される',
        (tester) async {
      final controller = await pumpTopic(tester);
      await tester.enterText(find.byType(TextField), 'テストお題');

      // 先手スロット（初期アクティブ）に池上を割り当てる
      await tester.scrollUntilVisible(rosterCard('池上彰AI'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(rosterCard('池上彰AI'));
      await tester.pump();

      // アクティブスロットが後手へ自動で移り、修造を後手に割り当てる
      await tester.scrollUntilVisible(rosterCard('松岡修造AI'), 100,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(rosterCard('松岡修造AI'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('バトル開始'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('バトル開始'));
      await tester.pump();
      await tester.pump();

      expect(controller.config, isNotNull);
      expect(controller.config!.first, DebaterId.ikegami);
      expect(controller.config!.second, DebaterId.shuzo);

      // 開始したバトルを止めてタイマを残さない
      controller.cancelCurrentBattle();
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('相手スロットにいる論客を選ぶと入れ替えになる（重複選択防止）',
        (tester) async {
      final controller = await pumpTopic(tester);
      await tester.enterText(find.byType(TextField), 'テストお題');

      // 先手スロットをアクティブにして、後手のホリエモンを選ぶ → 入れ替え
      // （ロスター側の「先手」バッジと区別するため first を使う）
      await tester.scrollUntilVisible(find.text('先手').first, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('先手').first);
      await tester.pump();
      await tester.scrollUntilVisible(rosterCard('ホリエモンAI'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(rosterCard('ホリエモンAI'));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('バトル開始'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('バトル開始'));
      await tester.pump();
      await tester.pump();

      expect(controller.config!.first, DebaterId.horiemon);
      expect(controller.config!.second, DebaterId.hiroyuki);

      controller.cancelCurrentBattle();
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('360×789で20人全員がスクロールなしに見える', (tester) async {
      // テスト描画環境の既定フォントは実機より行高が大きく、そのままでは
      // 実機で収まるレイアウトでもはみ出す。実機に近い検証のため、
      // /tmp/fonts に Noto Sans CJK JP があれば読み込んで使う（無ければ
      // 検証をスキップする。GIF撮影用に用意したフォントを流用）。
      final fontFiles = [
        File('/tmp/fonts/NotoSansCJKjp-Regular.otf'),
        File('/tmp/fonts/NotoSansCJKjp-Bold.otf'),
      ];
      if (!fontFiles.any((f) => f.existsSync())) {
        // ignore: avoid_print
        print('Noto Sans CJK JP が無いため 360×789 の収まり検証をスキップ');
        return;
      }
      final loader = FontLoader('Noto Sans JP');
      for (final f in fontFiles) {
        if (f.existsSync()) {
          loader.addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
        }
      }
      await loader.load();

      final controller = DebateController();
      await tester.binding.setSurfaceSize(const Size(360, 789));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Noto Sans JP'),
        home: TopicScreen(controller: controller),
      ));
      await tester.pump();

      // 最後のロスター（モ〇ンガAI）の名前が画面内に収まっている
      final rect = tester.getRect(rosterCard('モ〇ンガAI'));
      expect(rect.bottom, lessThanOrEqualTo(789 - 14)); // ラベル＋余白の分
      // 先頭のひろゆきも見えている
      expect(tester.getRect(rosterCard('ひろゆきAI')).top, greaterThan(0));
    });
  });
}
