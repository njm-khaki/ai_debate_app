import 'gemini_debate_engine.dart';
import 'mock_debate_engine.dart';
import 'openai_debate_engine.dart';

/// エンジン選択の優先順位：
/// 1. GEMINI_API_KEY があれば Gemini
/// 2. OPENAI_API_KEY があれば OpenAI
/// 3. どちらもなければローカルモック
DebateEngine selectEngine({
  String geminiApiKey = '',
  String openAiApiKey = '',
  String geminiModel = 'gemini-3.8-flash',
  String openAiModel = 'gpt-4o-mini',
}) {
  if (geminiApiKey.isNotEmpty) {
    return GeminiDebateEngine(apiKey: geminiApiKey, model: geminiModel);
  }
  if (openAiApiKey.isNotEmpty) {
    return OpenAiDebateEngine(apiKey: openAiApiKey, model: openAiModel);
  }
  return LocalMockDebateEngine();
}

/// 起動時（--dart-define）からエンジンを選ぶ。
///
/// 例:
/// flutter run --dart-define=GEMINI_API_KEY=AIza... --dart-define=GEMINI_MODEL=gemini-3.8-flash
/// flutter run --dart-define=OPENAI_API_KEY=sk-... --dart-define=OPENAI_MODEL=gpt-4o-mini
/// （両方指定した場合は Gemini が優先）
DebateEngine createDefaultEngine() {
  return selectEngine(
    geminiApiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    openAiApiKey: const String.fromEnvironment('OPENAI_API_KEY'),
    geminiModel: const String.fromEnvironment('GEMINI_MODEL',
        defaultValue: 'gemini-3.8-flash'),
    openAiModel:
        const String.fromEnvironment('OPENAI_MODEL', defaultValue: 'gpt-4o-mini'),
  );
}
