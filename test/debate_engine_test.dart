import 'package:ai_resuba/models/debate_models.dart';
import 'package:ai_resuba/services/mock_debate_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalMockDebateEngine', () {
    final engine = LocalMockDebateEngine();
    const config = BattleConfig(
      topic: '週休3日制は日本で実現すべきか',
      first: DebaterId.hiroyuki,
      second: DebaterId.horiemon,
      firstStance: Stance.pro,
      maxRounds: 4,
      entertainmentTone: true,
    );

    Future<BattleContext> playAll() async {
      final messages = <DebateMessage>[];
      final scores = <DebaterId, ScoreBreakdown>{
        DebaterId.hiroyuki: ScoreBreakdown.zero,
        DebaterId.horiemon: ScoreBreakdown.zero,
      };
      var momentum = 50.0;
      for (var i = 0; i < config.maxRounds * 2; i++) {
        final ctx = BattleContext(
          config: config,
          history: List.unmodifiable(messages),
          rawScores: Map.unmodifiable(scores),
          momentum: momentum,
        );
        final turn = await engine.nextTurn(ctx);
        messages.add(turn.message);
        final id = turn.message.debaterId!;
        scores[id] = scores[id]! + turn.rawScore;
        momentum = (momentum + turn.momentumDelta).clamp(8, 92);
      }
      return BattleContext(
        config: config,
        history: List.unmodifiable(messages),
        rawScores: Map.unmodifiable(scores),
        momentum: momentum,
      );
    }

    test('発言が交互になり、お題が本文に含まれる', () async {
      final ctx = await playAll();
      final debaterMsgs =
          ctx.history.where((m) => m.kind == SpeakerKind.debater).toList();
      expect(debaterMsgs.length, 8);
      for (var i = 0; i < debaterMsgs.length; i++) {
        expect(
          debaterMsgs[i].debaterId,
          i.isEven ? DebaterId.hiroyuki : DebaterId.horiemon,
        );
      }
      expect(debaterMsgs.first.text, contains('週休3日制'));
    });

    test('判定と要約が生成され、勝者とスコアが妥当', () async {
      final ctx = await playAll();
      final result = await engine.judgeAndSummarize(ctx);
      expect(result.winnerId, isIn(DebaterId.values));
      expect(result.judgeReason, isNotEmpty);
      expect(result.conclusion, contains('週休3日制'));
      expect(result.proPoints.length, 3);
      expect(result.conPoints.length, 3);
      for (final s in result.scores.values) {
        expect(s.logic, inInclusiveRange(0, 100));
        expect(s.total, greaterThan(0));
      }
      // 勝者の合計が敗者以上であること
      final winnerScore = result.scores[result.winnerId]!;
      final loserScore = result.scores[
          result.winnerId == DebaterId.hiroyuki
              ? DebaterId.horiemon
              : DebaterId.hiroyuki]!;
      expect(winnerScore.total, greaterThanOrEqualTo(loserScore.total));
    });

    test('同じお題では同じ展開になる（決定的）', () async {
      final a = await playAll();
      final b = await playAll();
      expect(
        a.history.map((m) => m.text).toList(),
        b.history.map((m) => m.text).toList(),
      );
    });
  });
}
