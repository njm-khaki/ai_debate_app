import 'package:flutter/material.dart';

/// 論客ID
enum DebaterId {
  hiroyuki,
  horiemon,
  shuzo,
  matsuko,
  ikegami,
  ochiai,
  koizumi,
  nanji,
  kazlaser,
  seki,
  tetsuko,
  hosoki,
  wada,
  jimmy,
  degawa,
  nagano,
  chiikawa,
  hachiware,
  usagi,
  momonga
}

/// 立場
enum Stance { pro, con }

extension StanceLabel on Stance {
  String get label => this == Stance.pro ? '賛成' : '反対';
  Stance get opposite => this == Stance.pro ? Stance.con : Stance.pro;
}

/// バトルの進行フェーズ（状態機械）
/// setting → versus → debating → verdict → summarizing → finished
enum BattlePhase { setting, versus, debating, verdict, summarizing, finished }

/// スコアカテゴリへのキャラ倍率（得意・不得意の癖）
class ScoreBias {
  final double logic;
  final double evidence;
  final double rebuttal;
  final double humor;

  const ScoreBias({
    this.logic = 1.0,
    this.evidence = 1.0,
    this.rebuttal = 1.0,
    this.humor = 1.0,
  });

  ScoreBreakdown apply(ScoreBreakdown raw) => ScoreBreakdown(
        logic: (raw.logic * logic).round(),
        evidence: (raw.evidence * evidence).round(),
        rebuttal: (raw.rebuttal * rebuttal).round(),
        humor: (raw.humor * humor).round(),
      );
}

/// 論客の静的定義（ロスター）
class Debater {
  final DebaterId id;
  final String name;
  final String catchPhrase;
  final Color color;
  final String avatarAsset;

  /// 表示用パラメータ（0-5、熱量のみ修造が6で振り切れる）
  final int paramLogic;
  final int paramHeat;
  final int paramEmpathy;

  /// スコアの癖
  final ScoreBias bias;

  const Debater({
    required this.id,
    required this.name,
    required this.catchPhrase,
    required this.color,
    required this.avatarAsset,
    required this.paramLogic,
    required this.paramHeat,
    required this.paramEmpathy,
    this.bias = const ScoreBias(),
  });
}

const debaterHiroyuki = Debater(
  id: DebaterId.hiroyuki,
  name: 'ひろゆきAI',
  catchPhrase: '冷静に、論理で切る',
  color: Color(0xFF4DA3FF),
  avatarAsset: 'assets/avatars/hiroyuki.webp',
  paramLogic: 5,
  paramHeat: 1,
  paramEmpathy: 1,
  bias: ScoreBias(logic: 1.15, rebuttal: 1.15, humor: 1.05),
);

const debaterHoriemon = Debater(
  id: DebaterId.horiemon,
  name: 'ホリエモンAI',
  catchPhrase: '熱く、行動で攻める',
  color: Color(0xFFFF8A3D),
  avatarAsset: 'assets/avatars/horiemon.webp',
  paramLogic: 3,
  paramHeat: 5,
  paramEmpathy: 2,
  bias: ScoreBias(logic: 0.95, evidence: 1.15, rebuttal: 0.95),
);

const debaterShuzo = Debater(
  id: DebaterId.shuzo,
  name: '松岡修造AI',
  catchPhrase: '諦めるな、熱く応援する',
  color: Color(0xFFE63946),
  avatarAsset: 'assets/avatars/shuzo.webp',
  paramLogic: 2,
  paramHeat: 6,
  paramEmpathy: 5,
  bias: ScoreBias(logic: 0.6, evidence: 0.9, rebuttal: 1.2, humor: 1.1),
);

const debaterMatsuko = Debater(
  id: DebaterId.matsuko,
  name: 'マツコAI',
  catchPhrase: '生活実感と直感で刺す',
  color: Color(0xFF9CCC3C),
  avatarAsset: 'assets/avatars/matsuko.webp',
  paramLogic: 2,
  paramHeat: 3,
  paramEmpathy: 4,
  bias: ScoreBias(logic: 0.8, evidence: 1.1, humor: 1.3),
);

const debaterIkegami = Debater(
  id: DebaterId.ikegami,
  name: '池上彰AI',
  catchPhrase: 'やさしく整理して本質を突く',
  color: Color(0xFF8FA3B8),
  avatarAsset: 'assets/avatars/ikegami.webp',
  paramLogic: 4,
  paramHeat: 1,
  paramEmpathy: 4,
  bias: ScoreBias(logic: 1.1, evidence: 1.1, rebuttal: 0.85, humor: 0.8),
);

const debaterOchiai = Debater(
  id: DebaterId.ochiai,
  name: '落合陽一AI',
  catchPhrase: '問いの枠組みを更新する',
  color: Color(0xFF4DD0E1),
  avatarAsset: 'assets/avatars/ochiai.webp',
  paramLogic: 4,
  paramHeat: 2,
  paramEmpathy: 2,
  bias: ScoreBias(logic: 1.05, evidence: 0.9, rebuttal: 1.1, humor: 0.9),
);

const debaterKoizumi = Debater(
  id: DebaterId.koizumi,
  name: '小泉進次郎AI',
  catchPhrase: '言い換えて、熱く押し切る',
  color: Color(0xFF34D399),
  avatarAsset: 'assets/avatars/koizumi.webp',
  paramLogic: 1,
  paramHeat: 3,
  paramEmpathy: 4,
  bias: ScoreBias(logic: 0.5, evidence: 0.6, rebuttal: 0.9, humor: 1.25),
);

const debaterNanji = Debater(
  id: DebaterId.nanji,
  name: 'なんJ民AI',
  catchPhrase: '猛虎弁で意味不明に攻める',
  color: Color(0xFFFFD600),
  avatarAsset: 'assets/avatars/nanji.webp',
  paramLogic: 1,
  paramHeat: 6,
  paramEmpathy: 1,
  bias: ScoreBias(logic: 0.4, evidence: 0.5, rebuttal: 1.1, humor: 1.4),
);

const debaterKazlaser = Debater(
  id: DebaterId.kazlaser,
  name: 'カズレーザーAI',
  catchPhrase: '博識と毒舌で静かに詰める',
  color: Color(0xFFC62828),
  avatarAsset: 'assets/avatars/kazlaser.webp',
  paramLogic: 5,
  paramHeat: 2,
  paramEmpathy: 2,
  bias: ScoreBias(logic: 1.2, evidence: 1.2, rebuttal: 1.05, humor: 1.15),
);

const debaterSeki = Debater(
  id: DebaterId.seki,
  name: '関暁夫AI',
  catchPhrase: '真実は闇の中から語る',
  color: Color(0xFF7B1FA2),
  avatarAsset: 'assets/avatars/seki.webp',
  paramLogic: 1,
  paramHeat: 4,
  paramEmpathy: 2,
  bias: ScoreBias(logic: 0.4, evidence: 1.1, rebuttal: 0.9, humor: 1.15),
);

const debaterTetsuko = Debater(
  id: DebaterId.tetsuko,
  name: '黒柳徹子AI',
  catchPhrase: '質問攻めで討論を乗っ取る',
  color: Color(0xFFEC407A),
  avatarAsset: 'assets/avatars/tetsuko.webp',
  paramLogic: 2,
  paramHeat: 4,
  paramEmpathy: 5,
  bias: ScoreBias(logic: 0.7, evidence: 1.0, rebuttal: 1.15, humor: 1.2),
);

const debaterHosoki = Debater(
  id: DebaterId.hosoki,
  name: '細木数子AI',
  catchPhrase: 'ズバリ、運命で言い切る',
  color: Color(0xFFB08D57),
  avatarAsset: 'assets/avatars/hosoki.webp',
  paramLogic: 1,
  paramHeat: 3,
  paramEmpathy: 1,
  bias: ScoreBias(logic: 0.3, evidence: 1.2, rebuttal: 1.0, humor: 0.9),
);

const debaterWada = Debater(
  id: DebaterId.wada,
  name: '和田アキ子AI',
  catchPhrase: '迫力の一言で制圧する',
  color: Color(0xFF880E4F),
  avatarAsset: 'assets/avatars/wada.webp',
  paramLogic: 2,
  paramHeat: 5,
  paramEmpathy: 3,
  bias: ScoreBias(logic: 0.7, evidence: 0.8, rebuttal: 1.25, humor: 1.2),
);

const debaterJimmy = Debater(
  id: DebaterId.jimmy,
  name: 'ジミー大西AI',
  catchPhrase: '天然の疑問で核心を突く',
  color: Color(0xFF9575CD),
  avatarAsset: 'assets/avatars/jimmy.webp',
  paramLogic: 1,
  paramHeat: 2,
  paramEmpathy: 4,
  bias: ScoreBias(logic: 0.5, evidence: 0.5, rebuttal: 1.0, humor: 1.35),
);

const debaterDegawa = Debater(
  id: DebaterId.degawa,
  name: '出川哲朗AI',
  catchPhrase: 'ヤバいよ連発で粘り勝つ',
  color: Color(0xFF00897B),
  avatarAsset: 'assets/avatars/degawa.webp',
  paramLogic: 1,
  paramHeat: 5,
  paramEmpathy: 3,
  bias: ScoreBias(logic: 0.5, evidence: 0.7, rebuttal: 0.8, humor: 1.3),
);

const debaterNagano = Debater(
  id: DebaterId.nagano,
  name: 'ナガノAI',
  catchPhrase: '笑顔のまま、一番痛いところを突く',
  color: Color(0xFF5D4037),
  avatarAsset: 'assets/avatars/nagano.webp',
  paramLogic: 4,
  paramHeat: 2,
  paramEmpathy: 0,
  bias: ScoreBias(logic: 1.1, evidence: 0.9, rebuttal: 1.2, humor: 1.05),
);

const debaterChiikawa = Debater(
  id: DebaterId.chiikawa,
  name: 'ちい〇わAI',
  catchPhrase: 'わぁ……（言葉がうまく出てこない）',
  color: Color(0xFFF48FB1),
  avatarAsset: 'assets/avatars/chiikawa.webp',
  paramLogic: 1,
  paramHeat: 2,
  paramEmpathy: 5,
  bias: ScoreBias(logic: 0.2, evidence: 0.2, rebuttal: 0.4, humor: 1.25),
);

const debaterHachiware = Debater(
  id: DebaterId.hachiware,
  name: 'ハチ〇レAI',
  catchPhrase: '一生懸命、自分の言葉で届ける',
  color: Color(0xFF5C6BC0),
  avatarAsset: 'assets/avatars/hachiware.webp',
  paramLogic: 3,
  paramHeat: 3,
  paramEmpathy: 4,
  bias: ScoreBias(logic: 0.9, evidence: 0.85, rebuttal: 0.95, humor: 1.1),
);

const debaterUsagi = Debater(
  id: DebaterId.usagi,
  name: 'う〇ぎAI',
  catchPhrase: 'プルヤァ！ 奇声で押し切る',
  color: Color(0xFFFFB300),
  avatarAsset: 'assets/avatars/usagi.webp',
  paramLogic: 1,
  paramHeat: 6,
  paramEmpathy: 1,
  bias: ScoreBias(logic: 0.3, evidence: 0.3, rebuttal: 0.8, humor: 1.35),
);

const debaterMomonga = Debater(
  id: DebaterId.momonga,
  name: 'モ〇ンガAI',
  catchPhrase: 'あざとく甘えて、場を支配する',
  color: Color(0xFF4FC3F7),
  avatarAsset: 'assets/avatars/momonga.webp',
  paramLogic: 2,
  paramHeat: 3,
  paramEmpathy: 2,
  bias: ScoreBias(logic: 0.7, evidence: 0.6, rebuttal: 1.0, humor: 1.25),
);

/// 選択可能な論客ロスター（表示順）
const allDebaters = [
  debaterHiroyuki,
  debaterHoriemon,
  debaterShuzo,
  debaterMatsuko,
  debaterIkegami,
  debaterOchiai,
  debaterKoizumi,
  debaterNanji,
  debaterKazlaser,
  debaterSeki,
  debaterTetsuko,
  debaterHosoki,
  debaterWada,
  debaterJimmy,
  debaterDegawa,
  debaterNagano,
  debaterChiikawa,
  debaterHachiware,
  debaterUsagi,
  debaterMomonga,
];

Debater debaterOf(DebaterId id) =>
    allDebaters.firstWhere((d) => d.id == id);

/// バトル設定（選択された2人のペア）
class BattleConfig {
  final String topic;

  /// 先手（左側）
  final DebaterId first;

  /// 後手（右側）
  final DebaterId second;

  /// 先手の立場。後手はその反対になる
  final Stance firstStance;
  final int maxRounds; // 1ラウンド = 両者1発言ずつ
  final bool entertainmentTone;

  const BattleConfig({
    required this.topic,
    required this.first,
    required this.second,
    required this.firstStance,
    required this.maxRounds,
    required this.entertainmentTone,
  }) : assert(first != second, '討論者は異なる2人を選んでください');

  Stance stanceOf(DebaterId id) =>
      id == first ? firstStance : firstStance.opposite;

  DebaterId opponentOf(DebaterId id) => id == first ? second : first;

  BattleConfig copyWith({
    Stance? firstStance,
    DebaterId? first,
    DebaterId? second,
  }) =>
      BattleConfig(
        topic: topic,
        first: first ?? this.first,
        second: second ?? this.second,
        firstStance: firstStance ?? this.firstStance,
        maxRounds: maxRounds,
        entertainmentTone: entertainmentTone,
      );
}

/// 発言者種別
enum SpeakerKind { debater, judge, system }

/// タイムライン上の1メッセージ
class DebateMessage {
  final SpeakerKind kind;
  final DebaterId? debaterId; // kind == debater のときのみ
  final String text;
  final int turnIndex;

  const DebateMessage({
    required this.kind,
    required this.text,
    required this.turnIndex,
    this.debaterId,
  });

  factory DebateMessage.debater(DebaterId id, String text, int turnIndex) =>
      DebateMessage(
        kind: SpeakerKind.debater,
        debaterId: id,
        text: text,
        turnIndex: turnIndex,
      );

  factory DebateMessage.judge(String text, int turnIndex) => DebateMessage(
        kind: SpeakerKind.judge,
        text: text,
        turnIndex: turnIndex,
      );
}

/// スコア内訳（各項目100点満点換算で保持）
class ScoreBreakdown {
  final int logic; // 論理性
  final int evidence; // 根拠・具体例
  final int rebuttal; // 反論への対応
  final int humor; // ユーモア・切れ味

  const ScoreBreakdown({
    required this.logic,
    required this.evidence,
    required this.rebuttal,
    required this.humor,
  });

  int get total => logic + evidence + rebuttal + humor;

  ScoreBreakdown operator +(ScoreBreakdown other) => ScoreBreakdown(
        logic: logic + other.logic,
        evidence: evidence + other.evidence,
        rebuttal: rebuttal + other.rebuttal,
        humor: humor + other.humor,
      );

  /// 累積値を0-100に正規化する
  ScoreBreakdown normalized(int maxPerCategory) {
    int n(int v) =>
        maxPerCategory <= 0 ? 0 : (v / maxPerCategory * 100).round().clamp(0, 100);
    return ScoreBreakdown(
      logic: n(logic),
      evidence: n(evidence),
      rebuttal: n(rebuttal),
      humor: n(humor),
    );
  }

  static const zero = ScoreBreakdown(logic: 0, evidence: 0, rebuttal: 0, humor: 0);
}

/// エンジンが返す1ターン分の結果
class DebateTurn {
  final DebateMessage message;

  /// 勢いゲージの変化量。先手側シェア(0-100)への加算値
  final double momentumDelta;

  /// この発言で得たスコア（カテゴリ累積用・生値）
  final ScoreBreakdown rawScore;

  /// ジャッジの横槍コメント（任意）
  final String? judgeComment;

  const DebateTurn({
    required this.message,
    required this.momentumDelta,
    required this.rawScore,
    this.judgeComment,
  });
}

/// 最終結果（ジャッジAIの判定＋要約AIの要約）
class BattleResult {
  final DebaterId winnerId;
  final Map<DebaterId, ScoreBreakdown> scores; // 正規化済み
  final String judgeReason;
  final String conclusion; // 要約AIの一言結論
  final List<String> proPoints;
  final List<String> conPoints;
  final String summaryText;

  const BattleResult({
    required this.winnerId,
    required this.scores,
    required this.judgeReason,
    required this.conclusion,
    required this.proPoints,
    required this.conPoints,
    required this.summaryText,
  });
}

/// エンジンへ渡す文脈
class BattleContext {
  final BattleConfig config;
  final List<DebateMessage> history;
  final Map<DebaterId, ScoreBreakdown> rawScores;
  final double momentum; // 先手側シェア 0-100

  const BattleContext({
    required this.config,
    required this.history,
    required this.rawScores,
    required this.momentum,
  });

  int get turnIndex => history.where((m) => m.kind == SpeakerKind.debater).length;
  int get totalTurns => config.maxRounds * 2;

  /// 次に話すべき論客（先手から交互）
  DebaterId get nextSpeaker =>
      turnIndex.isEven ? config.first : config.second;

  /// 指定論客の勢いシェア（0-100）
  double shareOf(DebaterId id) => id == config.first ? momentum : 100 - momentum;
}
