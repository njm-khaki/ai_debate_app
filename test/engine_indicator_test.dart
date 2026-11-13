import 'package:ai_resuba/models/debate_models.dart';
import 'package:ai_resuba/services/debate_engine_factory.dart';
import 'package:ai_resuba/services/gemini_debate_engine.dart';
import 'package:ai_resuba/services/mock_debate_engine.dart';
import 'package:ai_resuba/services/openai_debate_engine.dart';
import 'package:ai_resuba/state/debate_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

BattleContext _ctx() => const BattleContext(
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

void main() {
  group('エンジン表示名', () {
    test('selectEngine の各実装が表示名を持つ', () {
      expect(selectEngine().label, 'ローカルモック');
      expect(selectEngine(geminiApiKey: 'g').label, 'Gemini (gemini-3.8-flash)');
      expect(selectEngine(openAiApiKey: 'o').label, 'OpenAI (gpt-4o-mini)');
      expect(
        selectEngine(geminiApiKey: 'g', geminiModel: 'custom-model').label,
        'Gemini (custom-model)',
      );
    });

    test('DebateController がエンジン表示名を公開する', () {
      expect(DebateController().engineLabel, 'ローカルモック');
      expect(DebateController().fallbackInCurrentBattle, 0);
    });
  });

  group('fallback回数の可視化', () {
    test('Geminiが失敗するとfallbackCountが増える', () async {
      final client =
          http_testing.MockClient((req) async => http.Response('err', 500));
      final engine = GeminiDebateEngine(apiKey: 'k', client: client);
      expect(engine.fallbackCount, 0);
      await engine.nextTurn(_ctx());
      expect(engine.fallbackCount, 1);
      await engine.judgeAndSummarize(_ctx());
      expect(engine.fallbackCount, 2);
    });

    test('Geminiが成功するとfallbackCountは増えない', () async {
      final client = http_testing.MockClient((req) async => http.Response(
            '{"candidates":[{"content":{"parts":[{"text":"発言"}]}}]}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final engine = GeminiDebateEngine(apiKey: 'k', client: client);
      await engine.nextTurn(_ctx());
      expect(engine.fallbackCount, 0);
    });

    test('OpenAIが失敗するとfallbackCountが増える', () async {
      final client =
          http_testing.MockClient((req) async => http.Response('err', 401));
      final engine = OpenAiDebateEngine(apiKey: 'bad', client: client);
      await engine.nextTurn(_ctx());
      expect(engine.fallbackCount, 1);
    });

    test('モックのfallbackCountは常に0', () async {
      final engine = LocalMockDebateEngine();
      await engine.nextTurn(_ctx());
      expect(engine.fallbackCount, 0);
    });
  });
}
