import 'dart:convert';

import 'package:ai_resuba/models/debate_models.dart';
import 'package:ai_resuba/services/debate_engine_factory.dart';
import 'package:ai_resuba/services/gemini_debate_engine.dart';
import 'package:ai_resuba/services/mock_debate_engine.dart';
import 'package:ai_resuba/services/openai_debate_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

BattleContext _emptyContext() {
  return const BattleContext(
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
}

String _geminiResponse(String text) {
  return jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': text},
          ],
        },
      },
    ],
  });
}

void main() {
  group('GeminiDebateEngine', () {
    test('generateContentへ正しい形式で送り、応答テキストを発言にする', () async {
      late http.Request captured;
      final client = http_testing.MockClient((req) async {
        captured = req;
        return http.Response(_geminiResponse('Geminiからの発言です'), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final engine = GeminiDebateEngine(apiKey: 'test-key-123', client: client);

      final turn = await engine.nextTurn(_emptyContext());

      expect(turn.message.text, 'Geminiからの発言です');
      expect(turn.message.debaterId, DebaterId.hiroyuki);
      // エンドポイントとモデル
      expect(captured.url.toString(),
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent');
      // 認証はヘッダーで、URLにキーを載せない
      expect(captured.headers['x-goog-api-key'], 'test-key-123');
      expect(captured.url.query, isNot(contains('test-key-123')));
      // ボディ形式
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['system_instruction']['parts'][0]['text'],
          contains('ひろゆき'));
      expect(body['contents'][0]['parts'][0]['text'], contains('週休3日制'));
    });

    test('判定はJSONモードで送り、勝者と理由をパースする', () async {
      late http.Request captured;
      final client = http_testing.MockClient((req) async {
        captured = req;
        return http.Response(
          _geminiResponse(jsonEncode({
            'winner': 'horiemon',
            'judgeReason': '行動量と具体性で上回った',
            'conclusion': '結論はホリエモン側',
            'summaryText': '要約テキスト',
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final engine = GeminiDebateEngine(apiKey: 'k', client: client);

      final result = await engine.judgeAndSummarize(_emptyContext());

      expect(result.winnerId, DebaterId.horiemon);
      expect(result.judgeReason, '行動量と具体性で上回った');
      expect(result.conclusion, '結論はホリエモン側');
      expect(result.summaryText, '要約テキスト');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['generationConfig']['responseMimeType'], 'application/json');
    });

    test('APIが失敗したらモックへフォールバックする', () async {
      final client = http_testing.MockClient(
          (req) async => http.Response('error', 500));
      final engine = GeminiDebateEngine(apiKey: 'k', client: client);

      final turn = await engine.nextTurn(_emptyContext());
      expect(turn.message.text, isNotEmpty);
      expect(turn.message.text, contains('週休3日制')); // モックの冒頭発言

      final result = await engine.judgeAndSummarize(_emptyContext());
      expect(result.judgeReason, isNotEmpty);
    });
  });

  group('selectEngine（優先順位）', () {
    test('GeminiキーがあればOpenAIキーより優先', () {
      final e = selectEngine(geminiApiKey: 'g', openAiApiKey: 'o');
      expect(e, isA<GeminiDebateEngine>());
    });

    test('OpenAIキーだけならOpenAI', () {
      final e = selectEngine(openAiApiKey: 'o');
      expect(e, isA<OpenAiDebateEngine>());
    });

    test('どちらもなければモック', () {
      final e = selectEngine();
      expect(e, isA<LocalMockDebateEngine>());
    });
  });
}
