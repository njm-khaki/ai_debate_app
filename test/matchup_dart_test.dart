import 'package:flutter_test/flutter_test.dart';
import 'package:ai_resuba/models/debate_models.dart';
import 'package:ai_resuba/services/mock_debate_engine.dart';
import 'package:ai_resuba/state/battle_machine.dart';

/// Dart実エンジンでの総当たり（ロスター全員）。
/// Python 近似の相性分析を Dart の実モックで検証するためのテスト。20人ロスター版。
/// 条件: お題10種 × 3R/4R/6R × 先手立場(賛成/反対) × 先後入れ替え = 各ペア120試合、総計22,800試合。
/// DebateController のバトルループ(早期決着ガード含む)をタイマーなしで再現する。
void main() {
  const topics = [
    '週休3日制は日本で実現すべきか',
    'きのこの山 vs たけのこの里、買うならどっち',
    'リモートワークは今後も主流になるか',
    '現金はもう要らないか',
    '生成AIは学校教育に導入すべきか',
    '持ち家 vs 賃貸、結局どっちが得か',
    '副業は本業に支障をきたすか',
    '大学は全員が行くべきか',
    'SNSは社会に害か益か',
    '終身雇用は今も必要か',
  ];

  Future<DebaterId> simulate(LocalMockDebateEngine engine, BattleConfig cfg) async {
    final messages = <DebateMessage>[];
    final rawScores = <DebaterId, ScoreBreakdown>{
      cfg.first: ScoreBreakdown.zero,
      cfg.second: ScoreBreakdown.zero,
    };
    var momentum = 50.0;
    BattleContext ctx() => BattleContext(
          config: cfg,
          history: List.unmodifiable(messages),
          rawScores: Map.unmodifiable(rawScores),
          momentum: momentum,
        );
    int turnIndex() => messages.where((m) => m.kind == SpeakerKind.debater).length;
    final totalTurns = cfg.maxRounds * 2;
    while (turnIndex() < totalTurns) {
      final turn = await engine.nextTurn(ctx());
      messages.add(turn.message);
      final speakerId = turn.message.debaterId!;
      rawScores[speakerId] = rawScores[speakerId]! + turn.rawScore;
      momentum = (momentum + turn.momentumDelta).clamp(8, 92).toDouble();
      if (BattleMachine.shouldEarlyFinish(turnIndex: turnIndex(), momentum: momentum)) {
        break;
      }
    }
    final result = await engine.judgeAndSummarize(ctx());
    return result.winnerId;
  }

  test('20人総当たり Dart実エンジン', () async {
    final engine = LocalMockDebateEngine();
    final wins = <DebaterId, int>{for (final d in allDebaters) d.id: 0};
    final games = <DebaterId, int>{for (final d in allDebaters) d.id: 0};
    final winsAsFirst = <DebaterId, int>{for (final d in allDebaters) d.id: 0};
    final gamesAsFirst = <DebaterId, int>{for (final d in allDebaters) d.id: 0};
    final pairWins = <String, int>{};

    for (var i = 0; i < allDebaters.length; i++) {
      for (var j = i + 1; j < allDebaters.length; j++) {
        final a = allDebaters[i].id;
        final b = allDebaters[j].id;
        for (final swapped in [false, true]) {
          final first = swapped ? b : a;
          final second = swapped ? a : b;
          for (final topic in topics) {
            for (final stance in Stance.values) {
              for (final rounds in [3, 4, 6]) {
                final cfg = BattleConfig(topic: topic, first: first, second: second, firstStance: stance, maxRounds: rounds, entertainmentTone: true);
                final winner = await simulate(engine, cfg);
                wins[winner] = wins[winner]! + 1;
                games[a] = games[a]! + 1;
                games[b] = games[b]! + 1;
                gamesAsFirst[first] = gamesAsFirst[first]! + 1;
                if (winner == first) winsAsFirst[first] = winsAsFirst[first]! + 1;
                if (winner == a) pairWins['$a>$b'] = (pairWins['$a>$b'] ?? 0) + 1;
                if (winner == b) pairWins['$b>$a'] = (pairWins['$b>$a'] ?? 0) + 1;
              }
            }
          }
        }
      }
    }

    // 結果を print (flutter test --reporter expanded で確認)
    final ranked = allDebaters.toList()..sort((x, y) => (wins[y.id]! / games[y.id]!).compareTo(wins[x.id]! / games[x.id]!));
    // ignore: avoid_print
    print('=== Dart 20人総当たり 結果 ===');
    for (var k = 0; k < ranked.length; k++) {
      final d = ranked[k];
      final wr = wins[d.id]! / games[d.id]! * 100;
      final firstWr = gamesAsFirst[d.id]! == 0 ? 0.0 : winsAsFirst[d.id]! / gamesAsFirst[d.id]! * 100;
      final secondWr = 2 * wr - firstWr;
      // ignore: avoid_print
      print('${k + 1}. ${d.name} ${wr.toStringAsFixed(1)}% (先手 ${firstWr.toStringAsFixed(1)}% / 後手 ${secondWr.toStringAsFixed(1)}%) wins=${wins[d.id]} games=${games[d.id]}');
    }
    // 互角ペア抽出: 勝率45-55%
    // ignore: avoid_print
    print('=== 互角ペア (45-55%) ===');
    for (var i = 0; i < allDebaters.length; i++) {
      for (var j = i + 1; j < allDebaters.length; j++) {
        final a = allDebaters[i].id; final b = allDebaters[j].id;
        final aw = pairWins['$a>$b'] ?? 0; final bw = pairWins['$b>$a'] ?? 0;
        if (aw + bw == 0) continue;
        final rate = aw / (aw + bw) * 100;
        if (rate >= 45 && rate <= 55) {
          // ignore: avoid_print
          print('${allDebaters[i].name} vs ${allDebaters[j].name}: ${rate.toStringAsFixed(0)}:${(100 - rate).toStringAsFixed(0)} ($aw-$bw)');
        }
      }
    }
    expect(games.values.fold<int>(0, (s, v) => s + v), 20 * 19 * 120);
    expect(wins.values.fold<int>(0, (s, v) => s + v), 190 * 120);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
