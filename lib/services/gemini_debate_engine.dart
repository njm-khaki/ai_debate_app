import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/debate_models.dart';
import 'mock_debate_engine.dart';
import 'persona_prompts.dart';

/// Google Gemini APIを使う実AIエンジン。
///
/// 起動時に `--dart-define=GEMINI_API_KEY=...` が渡された場合に有効
/// （選択ロジックは debate_engine_factory.dart。OpenAIキーより優先）。
/// API呼び出しが失敗したターン／判定はモックへフォールバックするので、
/// キーが無効でもアプリが止まることはない。
///
/// 接続仕様（Gemini API公式REST）:
/// - POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
/// - 認証は `x-goog-api-key` ヘッダー（クエリパラメータには載せない）
/// - システムプロンプトは `system_instruction`、会話は `contents`/`parts`
/// - 判定は generationConfig.responseMimeType = application/json でJSON応答を要求
class GeminiDebateEngine implements DebateEngine {
  final String apiKey;
  final String model;
  final http.Client _client;
  final LocalMockDebateEngine _fallback = LocalMockDebateEngine();
  int _fallbackCount = 0;

  @override
  String get label => 'Gemini ($model)';

  @override
  int get fallbackCount => _fallbackCount;

  GeminiDebateEngine({
    required this.apiKey,
    this.model = 'gemini-3.8-flash',
    http.Client? client,
  }) : _client = client ?? http.Client();

  String get _endpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

  /// Geminiへ1リクエスト投げ、応答テキストを返す。失敗時は null。
  Future<String?> _generate({
    required String system,
    required String user,
    bool jsonMode = false,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {'text': system},
                ],
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': user},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.9,
                if (jsonMode) 'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      final parts = decoded['candidates']?[0]?['content']?['parts'];
      if (parts is! List || parts.isEmpty) return null;
      // 複数partに分かれる場合は連結する
      final text = parts
          .map((p) => (p is Map ? p['text'] : null) as String? ?? '')
          .join();
      return text.isEmpty ? null : text;
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

    final content = await _generate(
      system: persona,
      user: PersonaPrompts.turnUserPrompt(context),
    );
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
    final content = await _generate(
      system: PersonaPrompts.judgeSystemFor(context.config),
      user: PersonaPrompts.judgeUserPrompt(context),
      jsonMode: true,
    );
    if (content == null) {
      _fallbackCount++;
      return fallback;
    }
    final parsed = PersonaPrompts.parseJudgeResult(content, fallback);
    if (parsed == null) _fallbackCount++;
    return parsed ?? fallback;
  }
}
