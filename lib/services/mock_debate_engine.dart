import 'dart:math';

import '../models/debate_models.dart';

/// 議論エンジンの抽象。
/// ローカルモック／OpenAI実装を差し替え可能にするための境界。
abstract class DebateEngine {
  /// UIに表示するエンジン名（例: ローカルモック / Gemini (gemini-3.8-flash)）
  String get label;

  /// 呼び出しが失敗してモックへ倒れた累計回数。モック自体は常に0。
  int get fallbackCount => 0;

  /// 次の1発言とジャッジ評価を返す
  Future<DebateTurn> nextTurn(BattleContext context);

  /// 全発言をもとにジャッジAIが判定し、要約AIが要約する
  Future<BattleResult> judgeAndSummarize(BattleContext context);
}

/// 賛成側の論点プール
const _proPoints = [
  '導入にかかるコストより、得られるリターンの方が大きい',
  '個人の選択肢が増えて、合わない人が無理をしなくて済む',
  '古い慣習に合わせ続けるより、仕組み自体を変えた方が早い',
  '技術や運用の工夫で解決できる部分がかなり大きい',
  '一部の例外を除けば、多くの人が少しずつ得をする',
  'やらないことで失われている機会損失の方が大きい',
];

/// 反対側の論点プール
const _conPoints = [
  '現場の運用が追いつかず、結局あちこちで混乱する',
  '得をする人と損をする人の差が広がってしまう',
  'メリットが声の大きい一部の人に偏っている',
  'かかるコストと手間に見合っていない',
  '例外ケースの人が切り捨てられることになる',
  '一度始めたら後戻りが難しく、失敗時のダメージが大きい',
];

List<String> _pointsFor(Stance stance) =>
    stance == Stance.pro ? _proPoints : _conPoints;

/// APIキーなしでも単体で完結するローカルモックエンジン。
/// お題と立場に応じたテンプレートで、両ペルソナの口調を再現する。
/// 乱数はお題のハッシュでシードし、同じお題では同じ展開になる（テスト可能）。
class LocalMockDebateEngine implements DebateEngine {
  @override
  String get label => 'ローカルモック';

  @override
  int get fallbackCount => 0;

  Random _rngFor(BattleContext ctx) =>
      Random(ctx.config.topic.hashCode ^ ctx.turnIndex * 7919);

  @override
  Future<DebateTurn> nextTurn(BattleContext context) async {
    final speaker = context.nextSpeaker;
    final stance = context.config.stanceOf(speaker);
    final turn = context.turnIndex;
    final round = turn ~/ 2;
    final isFirstOfRound = turn.isEven;

    final myPoints = _pointsFor(stance);
    final oppPoints = _pointsFor(stance.opposite);
    final point = myPoints[(round + (isFirstOfRound ? 0 : 1)) % myPoints.length];
    final oppPoint =
        oppPoints[(round + (isFirstOfRound ? 0 : 0)) % oppPoints.length];

    final phase = _phaseFor(turn, context.totalTurns);
    final topic = context.config.topic;
    final text = switch (speaker) {
      DebaterId.hiroyuki => _hiroyukiLine(phase, stance, topic, point, oppPoint),
      DebaterId.horiemon => _horiemonLine(phase, stance, topic, point, oppPoint),
      DebaterId.shuzo => _shuzoLine(phase, stance, topic, point, oppPoint),
      DebaterId.matsuko => _matsukoLine(phase, stance, topic, point, oppPoint),
      DebaterId.ikegami => _ikegamiLine(phase, stance, topic, point, oppPoint),
      DebaterId.ochiai => _ochiaiLine(phase, stance, topic, point, oppPoint),
      DebaterId.koizumi => _koizumiLine(phase, stance, topic, point, oppPoint),
      DebaterId.nanji => _nanjiLine(phase, stance, topic, point, oppPoint),
      DebaterId.kazlaser =>
        _kazlaserLine(phase, stance, topic, point, oppPoint),
      DebaterId.seki => _sekiLine(phase, stance, topic, point, oppPoint),
      DebaterId.tetsuko =>
        _tetsukoLine(phase, stance, topic, point, oppPoint),
      DebaterId.hosoki => _hosokiLine(phase, stance, topic, point, oppPoint),
      DebaterId.wada => _wadaLine(phase, stance, topic, point, oppPoint),
      DebaterId.jimmy => _jimmyLine(phase, stance, topic, point, oppPoint),
      DebaterId.degawa => _degawaLine(phase, stance, topic, point, oppPoint),
      DebaterId.nagano => _naganoLine(phase, stance, topic, point, oppPoint),
      DebaterId.chiikawa =>
        _chiikawaLine(phase, stance, topic, point, oppPoint),
      DebaterId.hachiware =>
        _hachiwareLine(phase, stance, topic, point, oppPoint),
      DebaterId.usagi => _usagiLine(phase, stance, topic, point, oppPoint),
      DebaterId.momonga =>
        _momongaLine(phase, stance, topic, point, oppPoint),
    };

    final rng = _rngFor(context);
    // 発言の質スコア（カテゴリはフェーズで回す）
    final base = 58 + rng.nextInt(34); // 58-91
    var raw = switch (phase) {
      _Phase.opening => ScoreBreakdown(
          logic: base, evidence: base - 12, rebuttal: 30, humor: base - 20),
      _Phase.attack => ScoreBreakdown(
          logic: base - 6, evidence: base - 16, rebuttal: base, humor: base - 8),
      _Phase.evidence => ScoreBreakdown(
          logic: base - 4, evidence: base, rebuttal: base - 14, humor: base - 24),
      _Phase.cost => ScoreBreakdown(
          logic: base, evidence: base - 8, rebuttal: base - 10, humor: base - 18),
      _Phase.closing => ScoreBreakdown(
          logic: base - 2, evidence: base - 18, rebuttal: base - 6, humor: base),
    };

    // キャラの得意・不得意（スコア倍率）を反映する
    raw = debaterOf(speaker).bias.apply(raw);

    // 松岡修造AIの特殊特性「逆境燃焼」：劣勢なほど反論と熱で盛り返す
    var deltaBoost = 1.0;
    if (speaker == DebaterId.shuzo && context.shareOf(speaker) < 45) {
      raw = ScoreBreakdown(
        logic: raw.logic,
        evidence: raw.evidence,
        rebuttal: raw.rebuttal + 10,
        humor: raw.humor + 10,
      );
      deltaBoost = 1.4;
    }

    // 勢い：スコアが高い側へ寄る。先手視点の符号に変換
    final quality = (base - 74) / 6.0; // -2.6 .. +2.8
    final signed = speaker == context.config.first ? quality : -quality;
    final delta = (signed + (rng.nextDouble() * 2 - 1)) * deltaBoost;

    // 横槍コメントは優勢が入れ替わる節目と中盤だけ
    String? judgeComment;
    if (speaker == DebaterId.shuzo &&
        context.shareOf(speaker) < 40 &&
        turn >= 4) {
      judgeComment = '修造AI、劣勢でむしろ燃えています。';
    } else if (speaker == DebaterId.koizumi && turn >= 6) {
      judgeComment = '進次郎AI、今の発言は序盤の主張の言い換えのようです。';
    } else if (speaker == DebaterId.nanji && turn >= 4) {
      judgeComment = 'なんJ民AIの発言、ジャッジAIも解読に苦労しています。';
    } else if (speaker == DebaterId.kazlaser && turn >= 5) {
      judgeComment = 'カズレーザーAIの雑学、ジャッジAIも初耳です。';
    } else if (speaker == DebaterId.seki && turn >= 4) {
      judgeComment = '関AIの主張、裏付けの確認は取れていません。';
    } else if (speaker == DebaterId.tetsuko && turn >= 4) {
      judgeComment = '黒柳AIの質問が止まりません。討論がインタビューになっています。';
    } else if (speaker == DebaterId.hosoki && turn >= 4) {
      judgeComment = '細木AIの主張は占術に基づくもので、検証はできていません。';
    } else if (speaker == DebaterId.wada && turn >= 5) {
      judgeComment = '和田AIの迫力に、ジャッジAIも少し押されています。';
    } else if (speaker == DebaterId.jimmy && turn >= 4) {
      judgeComment = 'ジミーAIの解釈は独特ですが、核心を突いているような、いないような…';
    } else if (speaker == DebaterId.degawa &&
        turn >= 4 &&
        context.shareOf(speaker) < 55) {
      judgeComment = '出川AI、かなり追い込まれていますが、まだ倒れていません。';
    } else if (speaker == DebaterId.nagano && turn >= 4) {
      judgeComment = 'ナガノAI、笑顔のまま一歩も引いていません。ジャッジAI、正直怖いです。';
    } else if (speaker == DebaterId.chiikawa && turn >= 3) {
      judgeComment = 'ちい〇わAI、泣いてしまいました。……議論は続行します。';
    } else if (speaker == DebaterId.hachiware && turn >= 4) {
      judgeComment = 'ハチ〇レAI、「なんとかなれ」の精神で粘っています。';
    } else if (speaker == DebaterId.usagi && turn >= 3) {
      judgeComment = 'う〇ぎAIの奇声で、ジャッジAIの判定メモが見当たりません。';
    } else if (speaker == DebaterId.momonga && turn >= 4) {
      judgeComment = 'モ〇ンガAI、ジャッジにまで「褒めて」アピールを始めました。';
    } else if (turn == 3) {
      judgeComment = '両者の主張が出揃いました。ここから反論の応酬です。';
    } else if (turn == context.totalTurns - 2) {
      judgeComment = '決着が近づいています。最後の主張に注目です。';
    }

    return DebateTurn(
      message: DebateMessage.debater(speaker, text, turn),
      momentumDelta: delta,
      rawScore: raw,
      judgeComment: judgeComment,
    );
  }

  _Phase _phaseFor(int turn, int totalTurns) {
    if (turn < 2) return _Phase.opening;
    if (turn >= totalTurns - 2) return _Phase.closing;
    return switch (turn % 3) {
      0 => _Phase.attack,
      1 => _Phase.evidence,
      _ => _Phase.cost,
    };
  }

  String _hiroyukiLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'まず「$topic」ですけど、僕は賛成ですね。理由はシンプルで、$pointから。反対してる人って、だいたい「なんとなく不安」で止まってるんですよね。それってあなたの感想ですよね、という話で。'
          : '「$topic」、僕は反対寄りです。流行りで飛びつく人、多いですけど、冷静に考えると$pointんですよ。メリットばかり数えるのって、ちょっと都合が良すぎるかなと。',
      _Phase.attack =>
        'さっきの「$oppPoint」という話、それって例外の話を全体みたいに言ってません？割合で考えたら小さい話を大きく見せてるだけな気がしますけど。',
      _Phase.evidence =>
        '数字で見ましょうよ。$pointというのは感覚じゃなくて、実際に起きていることです。データがない議論って、ただの言い合いなんですよね。',
      _Phase.cost => pro
          ? 'コストの話をするなら、やらないコストも数えないとフェアじゃないですよね。現状維持って、タダに見えて一番高いことが多いんですよ。'
          : 'で、実際にかかるコストは誰が払うんですか？そこを曖昧にしたまま「やるべき」って言うのは、無責任かなと思いますけど。',
      _Phase.closing => pro
          ? '結局、反対の理由って「今のままで困ってない」だけなんですよね。困ってない一部の人が全体を止めるのって、なんだかなぁと思います。'
          : '結局、賛成派の話って「うまくいった場合」の話しかしてないんですよね。うまくいかなかった場合の説明がない時点で、議論として弱いかなと。',
    };
  }

  String _horiemonLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? '結論から言いますけど、賛成です。$point。これだけで十分じゃないですか。やらない理由を探している時間の方がもったいない。とりあえずやってみて、ダメなら直せばいいんですよ。'
          : 'いや、これは反対ですね。$point。メリットを語る人ほど、実際のコストを計算していない。冷静に数字を見たら、全然割に合わないですよ。',
      _Phase.attack =>
        'さっきの話、理想論なんですよね。「$oppPoint」と言うけど、じゃあ誰が現場を回すんですか？誰がコストを払うんですか？そこが抜けてるんですよ。',
      _Phase.evidence =>
        '僕は実際にやっている人たちの話を聞きますけど、現場の実感はこうです。$point。当事者じゃない人の意見って、だいたい机上の空論なんですよね。',
      _Phase.cost => pro
          ? 'コストなんて、やり方次第でいくらでも下げられます。最初から完璧を目指すから高くなる。まず小さく始める、それが一番合理的なんですよ。'
          : 'もう一度言いますけど、コストが見合ってないんです。情熱で押し切れるのは最初だけ。続かない仕組みは、結局みんなを不幸にしますよ。',
      _Phase.closing => pro
          ? '最終的には、やったもん勝ちなんですよ。議論している間に行動した人が全部持っていく。それが現実です。'
          : '情報はアップデートした方がいいですよ。昔の成功パターンを引きずっているだけでは、この話は前に進まないです。',
    };
  }

  String _shuzoLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? '聞いてください！「$topic」、僕は全力で賛成です！だって$pointから！やる前から諦めている人が多すぎるんです。まず一歩踏み出す、その勇気が未来を変えるんですよ！'
          : 'ちょっと待ってください！「$topic」、僕は反対です！$pointなんです。熱意だけで押し切っていい話と、そうじゃない話がある。ここでブレーキを踏めるのも勇気なんです！',
      _Phase.attack =>
        '今の「$oppPoint」という言葉、僕には「諦め」に聞こえました！できない理由を並べるのは簡単です。でも、どうしたらできるかを考えた人から、世界は変わってきたんです！',
      _Phase.evidence =>
        '僕は現役時代、何度も「もう無理だ」と言われました。でも$pointなんです。理屈の前に、やり抜いた人間がここにいる。それが一番の証拠じゃないですか！',
      _Phase.cost => pro
          ? 'コストですか？確かにかかります。でも挑戦しない人生のコストの方が、よっぽど高い！自分を超えるために流す汗は、絶対に無駄にならないんです！'
          : 'コストの話をしましょう。無理をして倒れてしまったら元も子もないんです。続けることが一番大事。だからこそ、身の丈に合わないやり方には反対なんです！',
      _Phase.closing => pro
          ? '最後に言わせてください。迷っているあなた、一人じゃないですよ！$pointなんです。今日から始めましょう。できる、絶対にできます！'
          : '応援したい気持ちは誰よりあります。でも本当の応援は、危ない道を止めることでもある。$point。だから僕は反対です。もっと熱くなれる進み方を一緒に探しましょう！',
    };
  }

  String _matsukoLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'まあ聞いてちょうだい。「$topic」、アタシは賛成よ。だって$pointじゃない。理屈ばっかりこねてる人ほど、実際の生活を知らなかったりするのよね。'
          : 'あらやだ、「$topic」？アタシは反対だわ。$pointのよ。テレビの中の立派な話と、実際の暮らしは違うのよ、ホントに。',
      _Phase.attack =>
        'さっきの「$oppPoint」って話、アンタ、それ本当に現場を見て言ってる？机の上で考えたことって、大抵ズレてるのよ。',
      _Phase.evidence =>
        'アタシの周りの普通の人たちの実感はね、こうなの。$point。専門家のお偉いさんより、毎日の生活の方がよっぽど正直よ。',
      _Phase.cost => pro
          ? 'お金の話をするなら、ケチって何も変わらない方がよっぽど損よ。使うべきところに使う。それが大人の判断ってもんじゃない？'
          : 'で、そのお金、誰が出すの？アンタじゃない誰かでしょ。人の財布を当てにした立派な意見は、アタシ信用しないことにしてるの。',
      _Phase.closing => pro
          ? '結局ね、変わることを怖がっているだけなのよ。$pointなんだから、アタシは賛成。人生一度きりよ、楽しまなきゃ損じゃない。'
          : '綺麗事はもう十分聞いたわ。$point。これが生活者の本音。アタシは反対よ。',
    };
  }

  String _ikegamiLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? '「$topic」について考えてみましょう。いい論点ですね。僕は賛成の立場です。理由は大きく一つ、$pointからです。順を追って説明しますね。'
          : '「$topic」、これは賛否が分かれるテーマです。なぜ反対なのかと言うと、$pointからなんです。感情ではなく、事実から見ていきましょう。',
      _Phase.attack =>
        '今の「$oppPoint」という指摘、もっともな部分もあります。ただ、ここで整理したいのは、それが全体の話なのか、一部の例外の話なのか、という点なんです。',
      _Phase.evidence =>
        '事実を見てみましょう。$pointということが起きています。印象で語るのではなく、こうした事実を一つずつ積み上げることが大切です。',
      _Phase.cost => pro
          ? 'コストの問題ですね。ポイントは「今払うコスト」と「払わなかった場合に将来かかるコスト」を比べることです。その意味では、投資として合理的だと考えます。'
          : 'コストの観点は重要です。誰が、どのくらい負担するのか。ここが曖昧なまま進めると、結局は弱い立場の人にしわ寄せがいく。それが歴史の教訓です。',
      _Phase.closing => pro
          ? 'まとめます。決め手は$pointという点です。今日の議論を、ぜひご自分の生活に当てはめて考えてみてください。僕は賛成です。'
          : '最後に一言。物事には必ず表と裏があります。今日見えた裏側、つまり$pointを忘れずに判断したい。僕は反対の立場を取ります。',
    };
  }

  String _ochiaiLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? '「$topic」という問い自体を、まず組み替えたいんです。僕は賛成ですが、理由は$pointから。技術が進んだ今、前提の方がもう変わっているんですよね。'
          : '「$topic」には反対です。正確に言うと、その二項対立の立て方自体に無理がある。$pointという現状を踏まえると、答えは自ずと見えてきます。',
      _Phase.attack =>
        '「$oppPoint」という反論、それは前の時代の環境を前提にした議論なんです。計算機と自然が融合した今の環境では、その前提がもう成立していない。',
      _Phase.evidence =>
        '僕が研究や制作の現場で見てきた実感としては、$pointなんです。抽象論に聞こえるかもしれませんが、現場のテクノロジーはすでにそこまで来ています。',
      _Phase.cost => pro
          ? 'コストという概念自体、デジタル化で意味が変わりました。複製と共有のコストは限りなくゼロに近づく。$pointという話は、その延長線上で捉えるべきです。'
          : 'コスト計算が雑なんですよね。お金だけじゃなく、注意や時間といった新しい資源のコストまで含めて設計しないと、必ずどこかで破綻します。',
      _Phase.closing => pro
          ? '結論として賛成です。ただしその形は、今の議論のどちらでもない第三の形になる。そういう未来の描き方をしたいんです。'
          : '結論は反対です。でもこれは後ろ向きな反対ではなくて、問いの設計をやり直そうという提案として受け取ってください。',
    };
  }

  String _koizumiLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? '「$topic」、私は賛成です。なぜ賛成なのか。それは、この国を前に進めるということは、現状にとどまらないということだからです。$pointから、私はそう確信しています。'
          : '「$topic」には反対です。反対するということは、立ち止まってでも考えるということなんです。今のままではいけない。だからこそ、今、急いではいけないんです。',
      _Phase.attack =>
        '相手の「$oppPoint」という言葉、重く受け止めています。ただ、受け止めるということは、正面から考えるということ。考えた上で言います。その指摘は、問題の本質ではないんです。',
      _Phase.evidence =>
        '根拠ですか。$pointという現実があります。現実と向き合うということは、現実から目をそらさないということなんです。私はしっかりと向き合います。',
      _Phase.cost => pro
          ? 'コストは大事です。でも、コストを払わないという決断にも、コストがある。その当たり前のことに目を向けない議論に、未来はないんです。'
          : '誰が負担するのか。負担するということは、誰かの生活が変わるということなんです。その重さを、軽く語るべきではないと思います。',
      _Phase.closing => pro
          ? '最後に言います。前に進むということは、変わるということ。変わることを恐れないでください。私は賛成です。'
          : '結論は反対です。反対するということは、否定することではない。より良くするための、もう一つの責任なんです。',
    };
  }

  String _nanjiLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'ワイは賛成やで。「$topic」やろ？ほな結論から言うわ、$pointや。異論は認める、認めるけど負けへんで。'
          : 'ワイは反対や。「$topic」？あんなもん、$pointやろがい。なんで賛成できるんか、ワイには分からんわ、ほんま。',
      _Phase.attack =>
        'ファッ!?「$oppPoint」やて？草生えるわそんなん。お前、その理屈で今まで何回負けてきたんや。猛虎の前では無力やで。',
      _Phase.evidence =>
        '根拠や根拠。$point、これは事実や。事実は曲がらへんのや。ソースはワイ、ワイがずっと現場を見てきたんや（※個人の感想です）。',
      _Phase.cost => pro
          ? '金の話か。ええやん、払う価値あるもんには払えばええんや。ケチケチしてる奴が一番損する、世の中そういうもんやで。'
          : 'コスト舐めたらあかんて。誰が払う思てんねん、結局ワイらやろ？そんな請求書、甲子園の外まで突き返したるわ。',
      _Phase.closing => pro
          ? 'まとめるで。ワイは賛成、以上や。反論あるならスレ立て直して出直してこいや。阪神も勝ったし今日はワイの日や、間違いない。'
          : '結論、反対や。ぐだぐだ言うてもしゃあない、球場出るわ。まあ次も来るけどな。このスレはワイが制圧したで、ほなな。',
    };
  }

  String _kazlaserLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'まず前提として、「$topic」、僕は賛成です。ちなみに、$pointという事実、意外と知られてないんですよね。知識って、こういう時に効くんですよ。'
          : '「$topic」、僕は反対です。ちなみに言うと、$pointんですよ。なんとなくのイメージだけで賛成してる人、多すぎませんか。',
      _Phase.attack =>
        '今の「$oppPoint」という話、正確には違います。細かいようですが、事実関係がずれていると議論って全部崩れるんですよ。静かに直しておきますね。',
      _Phase.evidence =>
        '根拠ならあります。$pointというのは実際に起きていることです。こういう具体例を積むと議論は地味になるんですけど、それが正解なんですよね。',
      _Phase.cost => pro
          ? 'コストの話、感情で語られがちですけど数字にすると単純です。払うべき場面かどうかは、結局、効果が測れるかどうかなんですよ。'
          : 'お金の話をすると夢が壊れるって言う人、いますけどね。請求書は夢を見てくれないんですよ。負担の設計が甘いと、最後に泣く人が出ます。',
      _Phase.closing => pro
          ? 'まとめると賛成です。派手なことは言ってませんが、事実を並べるとこうなるんですよね。知っているかどうかって、思ったより大きいんですよ。'
          : '結論、反対です。最後に豆知識を一つ。「空気で決まったこと」は、だいたい後で揉めます。今回の話はまさにそれです。',
    };
  }

  String _sekiLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? '「$topic」、僕は賛成です。……でも、なぜ今この議題が出てきたのか、偶然だと思いますか？表の理由は$point。でも、その裏で誰が得をするのか。考えたこと、ありますか。'
          : '「$topic」には反対です。表向きの説明は$pointと言われています。でもね、都市伝説の世界では、表向きの話ほど信用できないんですよ。',
      _Phase.attack =>
        '今の「$oppPoint」という主張。メディアが一斉に同じことを言い始める時ほど、裏があるんです。あの組織の紋章と構図が似ているの、気づきましたか。',
      _Phase.evidence =>
        '証拠、ありますよ。表には出てこない資料ですけどね。$point。これ、某国の機密文書の記述と一致するんです。……偶然ですかね。',
      _Phase.cost => pro
          ? 'お金の流れを追うと、見えてくるものがあります。闇の組織が一番嫌うのは、市民が賢くなることなんです。だからこそ、進めるべきなんですよ。'
          : 'コストですか。払わされる側はいつも一般の人々です。歴史上、大きな制度変更の裏には必ず、得をする少数派がいました。今回も例外じゃありません。',
      _Phase.closing => pro
          ? '結論は賛成です。ただ、最後に一つだけ。今日のこの議論自体、仕組まれていたとしたら……？信じるか信じないかは、あなた次第です。'
          : '結論は反対です。真実はいつも闇の中に隠されています。今日の話、忘れた頃にもう一度思い出してください。信じるか信じないかは、あなた次第です。',
    };
  }

  String _tetsukoLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'まあ、素敵なお題ね。「$topic」、私は賛成ですわ。だって、$pointんですもの。ねえ、あなたはどう思う？……あら、私が答える番でしたわね。ふふ。'
          : '「$topic」ですって？私は反対ですわ。$pointというじゃありませんか。ねえ、本当にみんな、ちゃんと考えているのかしら。',
      _Phase.attack =>
        'ちょっと待って、今の「$oppPoint」って、どういうこと？ねえ、もう少し詳しく教えてちょうだい。……ほら、うまく説明できないじゃありませんか。',
      _Phase.evidence =>
        '私ね、長年いろんな方にお話を伺ってきましたけど、$pointなんですのよ。経験した方の言葉って、重みが違いますわ。',
      _Phase.cost => pro
          ? 'お金のこと？あら、そういう細かいことより、まず始めてみることですわ。やってみれば、道は開けるんですから。'
          : '費用のことを伺いましたけどね、無理をしてまで進めることじゃありませんわ。身の丈に合わないことは、長続きしないんですの。',
      _Phase.closing => pro
          ? '結論ですわね、私は賛成です。疑問はまだありますけど、それはこれから皆で考えればいいんです。ね、そうでしょう？'
          : '結論ですわね、私は反対です。だって、まだ分からないことが多すぎますもの。分からないまま進めるのは、感心しませんわ。',
    };
  }

  String _hosokiLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'ズバリ言うわよ。「$topic」、あんたは賛成しなさい。六星占術で見れば、$pointの。運命の流れは、もう決まっているのよ。'
          : '「$topic」？あんた、やめておきなさい。ズバリ言うわよ、$pointのよ。今は大殺界の時期。動けば動くほど、ロクなことにならないわ。',
      _Phase.attack =>
        '「$oppPoint」ですって？あんた、自分の星のことを何も分かっていないのね。そんな考え方をしていたら、一生運は開けないわよ。',
      _Phase.evidence =>
        '根拠なら私の占いが全てよ。$point。これまで何千人と見てきた私が言うんだから、間違いないわ。疑うなら、それもあんたの運命ね。',
      _Phase.cost => pro
          ? 'お金の心配？あんた、金運は努力する人についてくるの。払うべき時に払わない人には、一生巡ってこないわよ。'
          : 'コストですって？無駄な出費は破滅の始まりよ。財布の紐が緩い時期に大きな決断をするなんて、自殺行為だわ。',
      _Phase.closing => pro
          ? '結論は賛成よ。私がこう言うからには、流れは決まっているの。あとはあんたが、その運命に乗れるかどうかだけね。'
          : '結論は反対。聞きなさい、今動いたら取り返しのつかないことになるわ。運命は変えられない。……変えられるのは、あんたの選択だけよ。',
    };
  }

  String _wadaLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'あのね、「$topic」、私は賛成よ。だって$pointじゃない。ぐずぐず言ってる暇があったら、まず動いてみなさいって。'
          : '「$topic」？はっきり言うけど、私は反対ね。$pointのよ。そんなんでうまくいくと思ったら、大間違いよ。',
      _Phase.attack =>
        '今の「$oppPoint」って話、あんたね、説得力がなさすぎるのよ。もっと腹を据えてものを言いなさい。……ほら、黙っちゃった。',
      _Phase.evidence =>
        '根拠？私の何十年もの経験が根拠よ。$pointってのは、この目で見てきた話。机の上の理屈とは重みが違うの。',
      _Phase.cost => pro
          ? 'お金？かけるべきところにはかけなきゃ駄目よ。ケチって中途半端にするのが、一番もったいないの。分かる？'
          : '費用対効果が悪すぎるのよ。あんた、人のお金だと思って甘く見てない？自分の財布から出すつもりで考えなさい。',
      _Phase.closing => pro
          ? '結論、賛成。細かいことはやりながら直せばいいの。最初の一歩を踏み出せない人に、未来はないわよ。ハッハッハ！'
          : '結論、反対。今日はこれで終わりにしましょう。無理なものは無理。それを認めるのも、大人の勇気ってものよ。',
    };
  }

  String _jimmyLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'えっと、「$topic」だね。ボクは賛成だと思うな。だって、$pointんでしょ？それって、なんか楽しそうじゃん。'
          : '「$topic」？うーん、ボクは反対かな。$pointって聞くとね、絵に描けないんだ。描けないものは、よく分からないものだと思うんだ。',
      _Phase.attack =>
        'ねえ、今の「$oppPoint」って、どういう意味？ボク、全然分かんなかった。……分からない言葉を使うのは、ズルいと思うな。',
      _Phase.evidence =>
        '根拠？ボクが描いた絵を見てよ。ほら、$pointって、こういうことでしょう？絵にすると、すごく単純なんだよ。',
      _Phase.cost => pro
          ? 'お金の話？難しいなあ。でもね、欲しい絵の具は買わないと、絵は描けないんだ。それと同じじゃないかな。'
          : '高いお金を出すのは、怖いよね。ボクだったら、そのお金でキャンバスをいっぱい買うなあ。そっちの方が幸せだと思う。',
      _Phase.closing => pro
          ? 'まとめると、賛成。難しいことは分かんないけど、楽しそうな方を選ぶのが、ボクのやり方なんだ。'
          : 'まとめると、反対だな。だって、考えれば考えるほど、絵がぐちゃぐちゃになっちゃうんだもん。シンプルな方がいいよ。',
    };
  }

  String _degawaLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'え、「$topic」！？ボクは賛成です！だって、$pointじゃないですか！……ヤバいよ、最初から飛ばしすぎたかな。'
          : '「$topic」ですか……ボクは反対です。$pointって、正直怖いですよ。ノーノー、落ち着いて、ちゃんと説明しますから！',
      _Phase.attack =>
        'ちょっと待って！今の「$oppPoint」、それ本当ですか！？ヤバいよヤバいよ……でもね、そこがおかしいと思うんですよ、ボクは！',
      _Phase.evidence =>
        '根拠、根拠ですね！えっと、$pointなんです！ほら、こういう事実もあるんですよ！……ふう、言えた。',
      _Phase.cost => pro
          ? 'お金のことですか！？確かにかかりますよ、そりゃ。でも、やる前から諦めるのは違うと思うんです。レッツゴーですよ！'
          : 'コストの話になると、ボク胃が痛いんですよね……。その負担、本当に大丈夫ですか？みんな汗だくになりますよ。',
      _Phase.closing => pro
          ? '結論、賛成です！色々言われましたけど、やってみなきゃ分かんないじゃないですか！ボクはそっちに賭けます！'
          : '結論、反対です。ヤバいと思ったら止まるのも勇気ですよ。……今日は本当によく汗をかきました。',
    };
  }

  String _naganoLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'はじめまして。「$topic」、私は賛成です。だって、$pointんですもの。優しい顔で近づいて、最後に一番痛いところを突く。それが物事の進み方なんです。ふふ。'
          : '「$topic」、私は反対です。$pointでしょう？始めたが最後、みんな少しずつ苦しくなっていく。そういう展開、嫌いじゃないですけど、今日は止めておきましょうか。',
      _Phase.attack =>
        '「$oppPoint」ですか。……ふふ、面白いですね。でもその理屈、いちばん苦しい立場の人にも、同じ笑顔で言えますか？言えないなら、ただの飾りですよ。',
      _Phase.evidence =>
        '根拠はあります。$pointんです。数字は冷たいですけど正直です。人を一番追い詰めるのは、優しい嘘の方なんですよ。',
      _Phase.cost => pro
          ? 'コストはかかりますね。でも、払わないでいた人には、後からもっと高い請求が届きます。どの痛みを選ぶか、それだけの話です。'
          : '費用の話をしましょう。誰かが必ず払うんです。その「誰か」が決まっていない計画は、結局いちばん弱い人に押しつけることになります。可哀想に。',
      _Phase.closing => pro
          ? '結論は賛成です。怖いなら目を閉じていても構いませんよ。ただ、目を開けたときには、もう決まっていると思います。ふふ。'
          : '結論は反対です。今の笑顔でいられるのは今日までかもしれませんね。……なんて、脅かすつもりはありませんよ。少しも。',
    };
  }

  String _chiikawaLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'わぁ……！ わぁ……！（なぜだか分からないけれど、$pointという気持ちだけは、とても強く伝わってくる）'
          : 'わぁ……。……わぁ……（小さく首を振っている。$point、と言いたいのかもしれない）',
      _Phase.attack =>
        'えっ……！？ わ、わぁ……！（相手の「$oppPoint」という言葉に驚いて、目に涙が浮かんでいる）',
      _Phase.evidence =>
        'わぁ……わぁ……（何かを一生懸命に伝えようとしている。どうやら、$pointということらしい）',
      _Phase.cost => pro
          ? 'わぁ……！（お金の話になると少し怯えた様子だったが、それでも頷いた。覚悟はあるようだ）'
          : '……わぁ……（費用の話を聞いて、だんだん泣きそうになっている。それが答えなのかもしれない）',
      _Phase.closing => pro
          ? 'わぁ……！ わぁ……！（最後は涙を拭いて、笑顔で大きく頷いた。言葉はなくても、賛成の気持ちは伝わった）'
          : 'わぁ……（涙をこらえながら、ゆっくりと首を振った。反対、という意思表示のようだ）',
    };
  }

  String _hachiwareLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'ぼくは賛成だよ。「$topic」って、要はみんなが少し楽になる話でしょ？$pointんだから、やらない理由の方が少ないと思うな。'
          : 'うーん、ぼくは反対かな。「$topic」、聞こえはいいけど、$pointんだよね。なんでも「いい話」で済ませちゃいけないと思うんだ。',
      _Phase.attack =>
        'ちょっと待って。「$oppPoint」って、ほんとにそうかな？その言葉、ぼくも前は意味を間違えて覚えてたけど、ちゃんと調べると少し違うんだよ。',
      _Phase.evidence =>
        '根拠って言われると弱いんだけどさ、$pointってことは、実際に起きてるんだよ。現場で頑張ってる人たちの声って、そういうことだと思うんだ。',
      _Phase.cost => pro
          ? 'お金のこと、ぼくも心配だった。でも、かかるものはかかるし、その分ちゃんと返ってくる話だと思うんだ。なんとかなる、じゃなくて、なんとかするんだよ。'
          : '費用の話をするとね、誰が払うのかが曖昧なんだ。そこがはっきりしないまま進めるのは、友達に借りを作るみたいで、ぼくは嫌だな。',
      _Phase.closing => pro
          ? 'まとめると、賛成だよ。難しい言葉は使えないけど、この気持ちは本物だから。……よし、なんとかなれーッ！'
          : 'まとめると、反対です。言い切るのは怖いけど、大事な人のためなら言うべきことは言わないと。ぼくはそう決めたよ。',
    };
  }

  String _usagiLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'プルヤァァァ！ ウララララーッ！（$point、という勢いだけは凄まじい。内容は一切伝わらない）'
          : 'プルルルル！ ヤァーーーッ！！（$pointらしい。全身で反対を表現している）',
      _Phase.attack =>
        'プルヤ！？ プルルルルルル！（相手の「$oppPoint」に奇声で応戦。議論の体は成していないが、迫力だけはある）',
      _Phase.evidence =>
        'ウラァ！ ラララララーッ！（根拠らしきものを叫んでいる。$point……かもしれない）',
      _Phase.cost => pro
          ? 'プルヤァ！（お金の話にも奇声で回答。払う気は満々のようだ）'
          : 'プルルル……プルヤ。（費用の話題で、一瞬だけ声が小さくなった。珍しい）',
      _Phase.closing => pro
          ? 'ヤハーーーーッ！ プルヤァ！（最後まで奇声だったが、なぜか会場は盛り上がっている。賛成、のようだ）'
          : 'プルヤァァァ！（結論の奇声。反対、という気迫だけは誰にも負けていない）',
    };
  }

  String _momongaLine(
      _Phase phase, Stance stance, String topic, String point, String oppPoint) {
    final pro = stance == Stance.pro;
    return switch (phase) {
      _Phase.opening => pro
          ? 'ねえねえ、聞いて？「$topic」、ボクは賛成だよ。だって$pointんでしょ？……ほら、今のボク、可愛かった？ちゃんと見ててよね。'
          : '「$topic」？ボクは反対。$pointもん。……え、反対だと可愛くない？そんなこと言わないで、ボクの意見もちゃんと聞いてよぉ。',
      _Phase.attack =>
        '「$oppPoint」だって？ふーん。……ねえ、それってボクを否定してるの？ボク、否定されると泣いちゃうよ？いいの？',
      _Phase.evidence =>
        '根拠？ボクがこう言ってるのが根拠だよ。$pointんだから。……ほら、すごいでしょ。褒めて？',
      _Phase.cost => pro
          ? 'お金かかるの？じゃあボクのために使ってよ。その方がみんな幸せだよ、絶対。ボクが言うんだから間違いないって。'
          : 'コストの話はやだなぁ。ボク、重たい話をされると頭が痛くなっちゃうの。……でも無駄遣いはダメだよ。本当に困ってる子のところに、お金がいかなくなっちゃう。',
      _Phase.closing => pro
          ? '結論、賛成！ボクの可愛さで全部なんとかなるよ。……なったよね？ほら、褒めろッ！……あ、今のは心の声ね。'
          : '結論は反対だよ。ボクが反対って言うの、珍しいでしょ？だから本気なの。ちゃんと分かってよね。',
    };
  }

  @override
  Future<BattleResult> judgeAndSummarize(BattleContext context) async {
    // 正規化は「実際に発言したターン数」で割る。
    // 規定ターン数で割ると、早期決着・途中終了時にスコア全体が下がるだけでなく、
    // ターン数が奇数で終わった場合に先手（ひろゆき）が構造的に有利になる。
    int turnCountOf(DebaterId id) => context.history
        .where((m) => m.kind == SpeakerKind.debater && m.debaterId == id)
        .length;
    final first = context.config.first;
    final second = context.config.second;
    final fScore = (context.rawScores[first] ?? ScoreBreakdown.zero)
        .normalized(91 * turnCountOf(first));
    final sScore = (context.rawScores[second] ?? ScoreBreakdown.zero)
        .normalized(91 * turnCountOf(second));

    final winner = fScore.total == sScore.total
        ? (context.momentum >= 50 ? first : second)
        : (fScore.total > sScore.total ? first : second);
    final loser = context.config.opponentOf(winner);
    final w = winner == first ? fScore : sScore;
    final l = winner == first ? sScore : fScore;

    // 勝因カテゴリ（差が最大のもの）
    final diffs = <String, int>{
      '論理性': w.logic - l.logic,
      '根拠・具体例': w.evidence - l.evidence,
      '反論への対応': w.rebuttal - l.rebuttal,
      'ユーモア・切れ味': w.humor - l.humor,
    };
    final best = diffs.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final winnerName = debaterOf(winner).name;
    final loserName = debaterOf(loser).name;
    final winnerStance = context.config.stanceOf(winner);

    final judgeReason =
        '$winnerNameは「$best」で$loserNameを上回りました。特に相手の主張の弱い部分を的確に突き、最後まで論点がぶれなかった点が決め手です。$loserNameも健闘しましたが、終盤で同じ主張の繰り返しになり、反論への対応で差がつきました。';

    final conclusion = winnerStance == Stance.pro
        ? '「${context.config.topic}」には条件付きで賛成。決め手は$bestでした。'
        : '「${context.config.topic}」には現時点では反対が妥当。決め手は$bestでした。';

    // 結果画面の主張リストは、バトル中に実際に使われた論点を立場ごとに集める。
    // 以前はプールの先頭3件固定だったため、毎回同じ文面になっていた。
    // 発言時の論点インデックス決定（nextTurn）と同じ計算を履歴から再現する。
    List<String> usedPoints(Stance stance) {
      final pool = _pointsFor(stance);
      final used = <String>[];
      for (final m in context.history) {
        if (m.kind != SpeakerKind.debater || m.debaterId == null) continue;
        if (context.config.stanceOf(m.debaterId!) != stance) continue;
        final t = m.turnIndex;
        final idx = ((t ~/ 2) + (t.isEven ? 0 : 1)) % pool.length;
        final p = pool[idx];
        if (!used.contains(p)) used.add(p);
        if (used.length >= 3) break;
      }
      // 早期決着などで3件に満たない場合は、未使用の論点をプール順に補う
      for (final p in pool) {
        if (used.length >= 3) break;
        if (!used.contains(p)) used.add(p);
      }
      return used;
    }

    final proPoints = usedPoints(Stance.pro);
    final conPoints = usedPoints(Stance.con);

    final summaryText =
        '賛成側は「${proPoints[0]}」を軸に、現状維持のコストを問い続けました。反対側は「${conPoints[0]}」を中心に、現場への影響と公平性の観点から反論しました。議論の終盤では$bestをめぐる応酬が焦点となり、最終的に$winnerNameの主張がより一貫していたと判定されました。';

    return BattleResult(
      winnerId: winner,
      scores: {first: fScore, second: sScore},
      judgeReason: judgeReason,
      conclusion: conclusion,
      proPoints: proPoints,
      conPoints: conPoints,
      summaryText: summaryText,
    );
  }
}

enum _Phase { opening, attack, evidence, cost, closing }
