import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/debate_models.dart';
import '../services/mock_debate_engine.dart';
import 'battle_machine.dart';

/// バトル全体の進行管理。
///
/// フェーズ遷移はすべて BattleMachine のイベントディスパッチ経由で行い、
/// 直接代入はしない（不正遷移は拒否される）。タイマーとエンジン呼び出しは
/// 世代トークンで守り、キャンセル済みバトルのループが状態を書き換える
/// ことはない。設計の詳細は docs/state_machine_design.md。
class DebateController extends ChangeNotifier {
  final DebateEngine engine;

  DebateController({DebateEngine? engine})
      : engine = engine ?? LocalMockDebateEngine();

  /// 現在のエンジン表示名（起動時のキー選択で決まる）
  String get engineLabel => engine.label;

  /// このバトル開始時点のfallback累計。画面は「今のバトルでのfallback数」を出す
  int _fallbackAtBattleStart = 0;

  int get fallbackInCurrentBattle =>
      engine.fallbackCount - _fallbackAtBattleStart;

  BattleConfig? config;

  BattlePhase _phase = BattlePhase.setting;
  BattlePhase get phase => _phase;

  final List<DebateMessage> messages = [];
  final Map<DebaterId, ScoreBreakdown> _rawScores = {};

  /// 先手側シェア 0-100
  double momentum = 50;

  /// ジャッジの決着度 0-1
  double settleProgress = 0;

  DebaterId? typingDebater;
  String? latestJudgeComment;
  BattleResult? result;

  PlaybackState _playback = PlaybackState.playing;
  bool get paused => _playback == PlaybackState.paused;

  /// 再生速度は状態ではなく拡張状態（context）として保持する
  double speed = 1.0;

  bool _verdictRequested = false;

  /// 実行中バトルの世代。開始・キャンセルごとに進み、古いループを無効化する
  int _generation = 0;

  final List<BattleResult> historyResults = [];
  final List<String> historyTopics = [];

  BattleContext get _context => BattleContext(
        config: config!,
        history: List.unmodifiable(messages),
        rawScores: Map.unmodifiable(_rawScores),
        momentum: momentum,
      );

  int get turnIndex =>
      messages.where((m) => m.kind == SpeakerKind.debater).length;

  /// 「判定を促す」が今有効か（画面側もこのガードを参照する）
  bool get canRequestVerdictNow => BattleMachine.canRequestVerdict(
      phase: _phase, turnIndex: turnIndex);

  /// イベントをディスパッチする。不正遷移は拒否して false を返す。
  bool _dispatch(BattleEvent event) {
    final next = BattleMachine.transition(_phase, event);
    if (next == null) {
      if (kDebugMode) {
        debugPrint(
            '[BattleMachine] 不正遷移を拒否: $_phase に $event');
      }
      return false;
    }
    _phase = next;
    return true;
  }

  bool _isCurrent(int generation) => generation == _generation;

  Future<void> _wait(int ms, int generation) async {
    var remaining = ms / speed;
    while (remaining > 0) {
      if (!_isCurrent(generation)) return;
      await Future.delayed(const Duration(milliseconds: 100));
      if (!paused) remaining -= 100;
    }
  }

  /// バトル開始。start イベントが受理された場合のみ進む（二重起動は即拒否）。
  Future<void> startBattle(BattleConfig cfg) async {
    if (!_dispatch(BattleEvent.start)) return;
    final generation = ++_generation;

    config = cfg;
    messages.clear();
    _rawScores.clear();
    _rawScores[cfg.first] = ScoreBreakdown.zero;
    _rawScores[cfg.second] = ScoreBreakdown.zero;
    momentum = 50;
    settleProgress = 0;
    result = null;
    latestJudgeComment = null;
    _verdictRequested = false;
    _playback = PlaybackState.playing;
    typingDebater = null;
    _fallbackAtBattleStart = engine.fallbackCount;
    notifyListeners();

    await _wait(1400, generation);
    if (!_isCurrent(generation)) return;
    if (!_dispatch(BattleEvent.versusElapsed)) return;

    messages.add(DebateMessage.judge(
        'ジャッジAI：お題「${cfg.topic}」。${debaterOf(cfg.first).name}は${cfg.stanceOf(cfg.first).label}、${debaterOf(cfg.second).name}は${cfg.stanceOf(cfg.second).label}で討論を開始します。',
        -1));
    notifyListeners();

    await _debateLoop(generation);
  }

  Future<void> _debateLoop(int generation) async {
    final totalTurns = config!.maxRounds * 2;
    while (turnIndex < totalTurns) {
      if (!_isCurrent(generation) || _phase != BattlePhase.debating) return;
      if (_verdictRequested) break;

      final speaker = _context.nextSpeaker;
      typingDebater = speaker;
      notifyListeners();
      await _wait(1100, generation);
      if (!_isCurrent(generation)) return;
      typingDebater = null;

      final turn = await engine.nextTurn(_context);
      if (!_isCurrent(generation) || _phase != BattlePhase.debating) return;
      messages.add(turn.message);
      final speakerId = turn.message.debaterId!;
      _rawScores[speakerId] = _rawScores[speakerId]! + turn.rawScore;
      momentum = (momentum + turn.momentumDelta).clamp(8, 92);
      settleProgress = _calcSettle(turnIndex, totalTurns);
      if (turn.judgeComment != null) {
        latestJudgeComment = turn.judgeComment;
        messages.add(DebateMessage.judge(
            'ジャッジAI：${turn.judgeComment}', turnIndex));
      }
      notifyListeners();

      // 早期決着：勢い差が大きく、最低ターン数を過ぎていればジャッジが止める
      if (BattleMachine.shouldEarlyFinish(
          turnIndex: turnIndex, momentum: momentum)) {
        break;
      }
      await _wait(1500, generation);
    }
    if (!_isCurrent(generation) || _phase != BattlePhase.debating) return;
    await _finish(generation);
  }

  double _calcSettle(int done, int total) {
    final base = done / total * 0.75;
    final lead = (momentum - 50).abs() / 50 * 0.25;
    return (base + lead).clamp(0, 1);
  }

  Future<void> _finish(int generation) async {
    if (!_dispatch(BattleEvent.debateFinished)) return;
    settleProgress = 1;
    messages.add(DebateMessage.judge('ジャッジAI：決着と判断しました。判定に移ります。', turnIndex));
    notifyListeners();
    await _wait(1600, generation);
    if (!_isCurrent(generation)) return;

    if (!_dispatch(BattleEvent.verdictShown)) return;
    notifyListeners();
    final judged = await engine.judgeAndSummarize(_context);
    if (!_isCurrent(generation) || _phase != BattlePhase.summarizing) return;
    result = judged;
    historyResults.insert(0, result!);
    historyTopics.insert(0, config!.topic);

    if (!_dispatch(BattleEvent.summaryCompleted)) return;
    notifyListeners();
  }

  void togglePause() {
    final event =
        paused ? PlaybackEvent.resume : PlaybackEvent.pause;
    final next =
        PlaybackMachine.transition(_playback, event, phase: _phase);
    if (next == null) return; // 対戦中以外では受理しない
    _playback = next;
    notifyListeners();
  }

  void toggleSpeed() {
    speed = speed == 1.0 ? 2.0 : 1.0;
    notifyListeners();
  }

  /// ユーザーがジャッジに判定を促す（ガードを通った場合のみ受理）
  void requestVerdict() {
    if (canRequestVerdictNow) _verdictRequested = true;
  }

  /// 進行中バトルを中断する（画面を離れるとき用）。
  /// finished / setting では何もしない（結果表示を壊さないため）。
  void cancelCurrentBattle() {
    if (_phase == BattlePhase.setting || _phase == BattlePhase.finished) {
      return;
    }
    _generation++;
    typingDebater = null;
    _dispatch(BattleEvent.reset);
    notifyListeners();
  }

  void resetToSetting() {
    _generation++;
    if (_dispatch(BattleEvent.reset)) {
      messages.clear();
      result = null;
      typingDebater = null;
      _verdictRequested = false;
      notifyListeners();
    }
  }
}
