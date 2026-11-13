import '../models/debate_models.dart';

/// バトルのフェーズ遷移イベント
enum BattleEvent {
  /// バトル開始（setting / finished からのみ）
  start,

  /// VS演出が終わった
  versusElapsed,

  /// 討論ループが終わった（規定ターン到達／早期決着／判定リクエスト）
  debateFinished,

  /// 「決着」演出が終わった
  verdictShown,

  /// 要約が生成された
  summaryCompleted,

  /// どの状態からでも初期状態へ戻る
  reset,
}

/// バトルの主ステートマシン（純粋関数だけの遷移表）。
///
/// 遷移表にない (状態, イベント) は不正遷移として null を返す。
/// 副作用（タイマー／API）は持たない。実行は DebateController の責務。
abstract final class BattleMachine {
  static const Map<BattlePhase, Map<BattleEvent, BattlePhase>> _transitions = {
    BattlePhase.setting: {BattleEvent.start: BattlePhase.versus},
    BattlePhase.versus: {BattleEvent.versusElapsed: BattlePhase.debating},
    BattlePhase.debating: {BattleEvent.debateFinished: BattlePhase.verdict},
    BattlePhase.verdict: {BattleEvent.verdictShown: BattlePhase.summarizing},
    BattlePhase.summarizing: {
      BattleEvent.summaryCompleted: BattlePhase.finished
    },
    BattlePhase.finished: {BattleEvent.start: BattlePhase.versus},
  };

  /// 遷移先を返す。不正な遷移なら null。
  static BattlePhase? transition(BattlePhase from, BattleEvent event) {
    if (event == BattleEvent.reset) return BattlePhase.setting;
    return _transitions[from]?[event];
  }

  static bool can(BattlePhase from, BattleEvent event) =>
      transition(from, event) != null;

  /// 「判定を促す」が有効になる最小ターン数
  static const minTurnsForVerdict = 4;

  /// 早期決着に必要な最小ターン数
  static const minTurnsForEarlyFinish = 6;

  /// 早期決着に必要な勢い差（50からの絶対偏差）
  static const earlyFinishLead = 30;

  /// ガード：判定リクエストは debating 中かつ最小ターン数以降のみ
  static bool canRequestVerdict({
    required BattlePhase phase,
    required int turnIndex,
  }) =>
      phase == BattlePhase.debating && turnIndex >= minTurnsForVerdict;

  /// ガード：勢い差が大きい場合の早期決着
  static bool shouldEarlyFinish({
    required int turnIndex,
    required double momentum,
  }) =>
      turnIndex >= minTurnsForEarlyFinish &&
      (momentum - 50).abs() >= earlyFinishLead;
}

/// 再生状態（フェーズと直交する小マシン）
enum PlaybackState { playing, paused }

enum PlaybackEvent { pause, resume }

/// 再生マシン。遷移できるのは対戦中（debating）のときだけ。
abstract final class PlaybackMachine {
  static PlaybackState? transition(
    PlaybackState from,
    PlaybackEvent event, {
    required BattlePhase phase,
  }) {
    if (phase != BattlePhase.debating) return null;
    return switch ((from, event)) {
      (PlaybackState.playing, PlaybackEvent.pause) => PlaybackState.paused,
      (PlaybackState.paused, PlaybackEvent.resume) => PlaybackState.playing,
      _ => null,
    };
  }
}
