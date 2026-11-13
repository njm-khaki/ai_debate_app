import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/debate_models.dart';
import 'mock_debate_engine.dart';
import 'persona_prompts.dart';

/// OpenAI APIを使う実AIエンジン。
///
/// 起動時に `--dart-define=OPENAI_API_KEY=...` が渡された場合のみ有効
/// （選択ロジックは debate_engine_factory.dart）。
/// API呼び出しが失敗したターン／判定はモックへフォールバックするので、
/// キーが無効でもアプリが止まることはない。
class OpenAiDebateEngine implements DebateEngine {
  final String apiKey;
  final String model;
  final http.Client _client;
  final LocalMockDebateEngine _fallback = LocalMockDebateEngine();
  int _fallbackCount = 0;

  @override
  String get label => 'OpenAI ($model)';

  @override
  int get fallbackCount => _fallbackCount;

  OpenAiDebateEngine({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _endpoint = 'https://api.openai.com/v1/chat/completions';

  Future<String?> _chat(List<Map<String, String>> messages) async {
    try {
      final res = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'temperature': 0.9,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return decoded['choices'][0]['message']['content'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DebateTurn> nextTurn(BattleContext context) async {
    final fallback = await _fallback.nextTurn(context);
    final speaker = context.nextSpeaker;

    // ペルソナ未定義の論客が増えても落とさず、モックへ倒す（他経路と同じ方針）
    final persona = PersonaPrompts.persona[speaker];
    if (persona == null) {
      _fallbackCount++;
      return fallback;
    }

    final content = await _chat([
      {'role': 'system', 'content': persona},
      {'role': 'user', 'content': PersonaPrompts.turnUserPrompt(context)},
    ]);
    if (content == null || content.trim().isEmpty) {
      _fallbackCount++;
      return fallback;
    }
    return DebateTurn(
      message: DebateMessage.debater(speaker, content.trim(), context.turnIndex),
      momentumDelta: fallback.momentumDelta,
      rawScore: fallback.rawScore,
      judgeComment: fallback.judgeComment,
    );
  }

  @override
  Future<BattleResult> judgeAndSummarize(BattleContext context) async {
    final fallback = await _fallback.judgeAndSummarize(context);
    final content = await _chat([
      {'role': 'system', 'content': PersonaPrompts.judgeSystemFor(context.config)},
      {'role': 'user', 'content': PersonaPrompts.judgeUserPrompt(context)},
    ]);
    if (content == null) {
      _fallbackCount++;
      return fallback;
    }
    final parsed = PersonaPrompts.parseJudgeResult(content, fallback);
    if (parsed == null) _fallbackCount++;
    return parsed ?? fallback;
  }
}
