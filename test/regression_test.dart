import 'dart:convert';

import 'package:ai_resuba/models/debate_models.dart';
import 'package:ai_resuba/services/mock_debate_engine.dart';
import 'package:ai_resuba/services/openai_debate_engine.dart';
import 'package:ai_resuba/services/persona_prompts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

/// セルフコードレビュー（2026-11-10）で見つけた問題の回帰テスト。
/// 各テストは修正前のコードでは失敗する（または仕様を固定する）もの。
void main() {
  group('F1: スコア正規化は実際のターン数で割る', () {
    // 1ターンあたり全く同じ質の発言を、ひろゆき3ターン／ホリエモン2ターン。
    // 修正前は分母が共通（規定ターン数）だったため、ターン数の多い側が
    // 構造的に高スコアになっていた。
    BattleContext unevenContext() {
      ScoreBreakdown perTurn(int n) => ScoreBreakdown(
            logic: 80 * n,
            evidence: 70 * n,
            rebuttal: 60 * n,
            humor: 50 * n,
          );
      final history = <DebateMessage>[
        DebateMessage.debater(DebaterId.hiroyuki, 'h1', 0),
        DebateMessage.debater(DebaterId.horiemon, 'o1', 1),
        DebateMessage.debater(DebaterId.hiroyuki, 'h2', 2),
        DebateMessage.debater(DebaterId.horiemon, 'o2', 3),
        DebateMessage.debater(DebaterId.hiroyuki, 'h3', 4),
      ];
      return BattleContext(
        config: const BattleConfig(
          topic: '回帰テストお題',
          first: DebaterId.hiroyuki,
      second: DebaterId.horiemon,
      firstStance: Stance.pro,
          maxRounds: 4,
          entertainmentTone: true,
        ),
        history: history,
        rawScores: {
          DebaterId.hiroyuki: perTurn(3),
          DebaterId.horiemon: perTurn(2),
        },
        momentum: 50,
      );
    }

    test('ターン数が違っても、同じ質なら同スコアになる', () async {
      final engine = LocalMockDebateEngine();
      final result = await engine.judgeAndSummarize(unevenContext());
      final h = result.scores[DebaterId.hiroyuki]!;
      final o = result.scores[DebaterId.horiemon]!;
      expect(h.total, o.total);
      expect(h.logic, o.logic);
      // スケールも規定ターン換算ではなく実ターン換算で 80/91 相当になる
      expect(h.logic, closeTo((80 / 91 * 100).round(), 1));
    });
  });

  group('F2: 判定JSONの winner バリデーション', () {
    const fallback = BattleResult(
      winnerId: DebaterId.horiemon,
      scores: {
        DebaterId.hiroyuki: ScoreBreakdown.zero,
        DebaterId.horiemon: ScoreBreakdown.zero,
      },
      judgeReason: 'fallback reason',
      conclusion: 'fallback conclusion',
      proPoints: [],
      conPoints: [],
      summaryText: 'fallback summary',
    );

    test('想定外の winner は null（フォールバックへ）', () {
      for (final bad in ['draw', 'ひろゆき', '', 'HIROYUKI']) {
        final r = PersonaPrompts.parseJudgeResult(
            jsonEncode({
              'winner': bad,
              'judgeReason': 'x',
              'conclusion': 'y',
              'summaryText': 'z',
            }),
            fallback);
        expect(r, isNull, reason: 'winner=$bad は拒否されるべき');
      }
    });

    test('winner欠落も null', () {
      final r = PersonaPrompts.parseJudgeResult(
          jsonEncode({'judgeReason': 'x'}), fallback);
      expect(r, isNull);
    });

    test('正常な winner はパースされる', () {
      final r = PersonaPrompts.parseJudgeResult(
          jsonEncode({
            'winner': 'horiemon',
            'judgeReason': '理由',
            'conclusion': '結論',
            'summaryText': '要約',
          }),
          fallback);
      expect(r, isNotNull);
      expect(r!.winnerId, DebaterId.horiemon);
      expect(r.judgeReason, '理由');
    });

    test('JSON前後の余分な文字列があっても抽出できる', () {
      final r = PersonaPrompts.parseJudgeResult(
          '以下が判定です。{"winner":"hiroyuki","judgeReason":"r","conclusion":"c","summaryText":"s"} 以上。',
          fallback);
      expect(r, isNotNull);
      expect(r!.winnerId, DebaterId.hiroyuki);
    });

    test('AIが返した proPoints/conPoints が採用される', () {
      final r = PersonaPrompts.parseJudgeResult(
          jsonEncode({
            'winner': 'hiroyuki',
            'judgeReason': 'r',
            'conclusion': 'c',
            'summaryText': 's',
            'proPoints': ['賛成の主張A', '賛成の主張B'],
            'conPoints': ['反対の主張A', '反対の主張B', '反対の主張C', '反対の主張D'],
          }),
          fallback);
      expect(r, isNotNull);
      expect(r!.proPoints, ['賛成の主張A', '賛成の主張B']);
      // 最大3件に切り詰められる
      expect(r.conPoints.length, 3);
    });

    test('proPoints/conPoints が欠けていればフォールバック値を使う', () {
      const fb = BattleResult(
        winnerId: DebaterId.horiemon,
        scores: {
          DebaterId.hiroyuki: ScoreBreakdown.zero,
          DebaterId.horiemon: ScoreBreakdown.zero,
        },
        judgeReason: 'fr',
        conclusion: 'fc',
        proPoints: ['モック賛成'],
        conPoints: ['モック反対'],
        summaryText: 'fs',
      );
      final r = PersonaPrompts.parseJudgeResult(
          jsonEncode({
            'winner': 'hiroyuki',
            'judgeReason': 'r',
            'conclusion': 'c',
            'summaryText': 's',
            'proPoints': <String>[],
          }),
          fb);
      expect(r, isNotNull);
      expect(r!.proPoints, ['モック賛成']);
      expect(r.conPoints, ['モック反対']);
    });
  });

  group('結果画面の主張リストは実際に使われた論点から作る', () {
    final engine = LocalMockDebateEngine();

    BattleContext ctxWithTurns(int turns, Stance firstStance) {
      final history = <DebateMessage>[
        for (var t = 0; t < turns; t++)
          DebateMessage.debater(
              t.isEven ? DebaterId.hiroyuki : DebaterId.horiemon, '発言$t', t),
      ];
      return BattleContext(
        config: BattleConfig(
          topic: '週休3日制は日本で実現すべきか',
          first: DebaterId.hiroyuki,
          second: DebaterId.horiemon,
          firstStance: firstStance,
          maxRounds: 4,
          entertainmentTone: true,
        ),
        history: history,
        rawScores: const {
          DebaterId.hiroyuki: ScoreBreakdown.zero,
          DebaterId.horiemon: ScoreBreakdown.zero,
        },
        momentum: 50,
      );
    }

    test('後手の立場は使った論点が先頭3件固定とずれる（毎回同じの回帰）', () async {
      // 先手=賛成（ターン0,2,4,6→論点0,1,2）、後手=反対（ターン1,3,5,7→論点1,2,3）
      final r = await engine.judgeAndSummarize(ctxWithTurns(8, Stance.pro));
      expect(r.proPoints.first, contains('導入にかかるコストより'));
      expect(r.conPoints, [
        '得をする人と損をする人の差が広がってしまう',
        'メリットが声の大きい一部の人に偏っている',
        'かかるコストと手間に見合っていない',
      ]);
    });

    test('立場を入れ替えると賛成リストも変わる', () async {
      // 先手=反対、後手=賛成 → 賛成側は後手なので論点1,2,3が並ぶ
      final r = await engine.judgeAndSummarize(ctxWithTurns(8, Stance.con));
      expect(r.proPoints, [
        '個人の選択肢が増えて、合わない人が無理をしなくて済む',
        '古い慣習に合わせ続けるより、仕組み自体を変えた方が早い',
        '技術や運用の工夫で解決できる部分がかなり大きい',
      ]);
      expect(r.conPoints.first, contains('現場の運用が追いつかず'));
    });

    test('早期終了でも3件に補完され、先頭は実際に使った論点になる', () async {
      // 1ターンずつで終了：賛成は論点0、反対は論点1を使った
      final r = await engine.judgeAndSummarize(ctxWithTurns(2, Stance.pro));
      expect(r.proPoints.length, 3);
      expect(r.conPoints.length, 3);
      expect(r.proPoints.first, contains('導入にかかるコストより'));
      expect(r.conPoints.first, contains('得をする人と損をする人の差'));
    });
  });

  group('OpenAIエンジン（未カバー領域の回帰）', () {
    BattleContext ctx() => const BattleContext(
          config: BattleConfig(
            topic: '週休3日制は日本で実現すべきか',
            first: DebaterId.hiroyuki,
      second: DebaterId.horiemon,
      firstStance: Stance.pro,
            maxRounds: 4,
            entertainmentTone: true,
          ),
          history: [],
          rawScores: {
            DebaterId.hiroyuki: ScoreBreakdown.zero,
            DebaterId.horiemon: ScoreBreakdown.zero,
          },
          momentum: 50,
        );

    test('chat/completions へ正しい形式で送り、応答を発言にする', () async {
      late http.Request captured;
      final client = http_testing.MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'OpenAIからの発言です'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final engine =
          OpenAiDebateEngine(apiKey: 'sk-test', model: 'gpt-4o-mini', client: client);
      final turn = await engine.nextTurn(ctx());

      expect(turn.message.text, 'OpenAIからの発言です');
      expect(captured.url.toString(),
          'https://api.openai.com/v1/chat/completions');
      expect(captured.headers['Authorization'], 'Bearer sk-test');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['model'], 'gpt-4o-mini');
      expect(body['messages'][0]['role'], 'system');
      expect(body['messages'][1]['content'], contains('週休3日制'));
    });

    test('API失敗時はモックへフォールバックする', () async {
      final client =
          http_testing.MockClient((req) async => http.Response('err', 401));
      final engine = OpenAiDebateEngine(apiKey: 'bad', client: client);
      final turn = await engine.nextTurn(ctx());
      expect(turn.message.text, contains('週休3日制'));
    });

    test('choices が空でも例外なくフォールバックする', () async {
      final client = http_testing.MockClient((req) async =>
          http.Response(jsonEncode({'choices': []}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'}));
      final engine = OpenAiDebateEngine(apiKey: 'k', client: client);
      final turn = await engine.nextTurn(ctx());
      expect(turn.message.text, isNotEmpty);
    });
  });
}
