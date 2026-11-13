import 'dart:math';

import 'package:flutter/material.dart';

import '../models/debate_models.dart';
import '../state/debate_controller.dart';
import '../widgets/debate_widgets.dart';
import 'battle_screen.dart';

const _sampleTopics = [
  '週休3日制は日本で実現すべきか',
  'きのこの山 vs たけのこの里、買うならどっち',
  'リモートワークは今後も主流になるか',
  '現金はもう要らないか',
  '生成AIは学校教育に導入すべきか',
  '持ち家 vs 賃貸、結局どっちが得か',
];

class TopicScreen extends StatefulWidget {
  final DebateController controller;

  const TopicScreen({super.key, required this.controller});

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  final _textController = TextEditingController();

  /// 選択中のペア（先手／後手）と、ロスタータップの割当先スロット（0=先手, 1=後手）
  /// 初期値は先手：まず先手を決めるのが直感的なため
  DebaterId _first = DebaterId.hiroyuki;
  DebaterId _second = DebaterId.horiemon;
  int _activeSlot = 0;
  Stance _firstStance = Stance.pro;
  int _rounds = 4; // 短い3 / 普通4 / 長い6
  bool _entertainment = true;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// ロスターの論客をアクティブなスロットへ割り当てる。
  /// もう一方のスロットにいる論客なら入れ替えにする（同一人物の重複選択を防ぐ）。
  void _assign(DebaterId id) {
    setState(() {
      if (_activeSlot == 0) {
        if (id == _second) {
          _second = _first;
        }
        _first = id;
        _activeSlot = 1;
      } else {
        if (id == _first) {
          _first = _second;
        }
        _second = id;
        _activeSlot = 0;
      }
    });
  }

  void _start() {
    final topic = _textController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('お題を入力してください')),
      );
      return;
    }
    final cfg = BattleConfig(
      topic: topic,
      first: _first,
      second: _second,
      firstStance: _firstStance,
      maxRounds: _rounds,
      entertainmentTone: _entertainment,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BattleScreen(controller: widget.controller, config: cfg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIレスバ アリーナ'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
        children: [
          const Text(
            'お題を投げたら、AI同士のレスバを観戦。',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, height: 1.3),
          ),
          const SizedBox(height: 4),
          const Text(
            'ジャッジAIが決着と判断した瞬間、バトル終了。要約AIが最後にまとめます。',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('ディベートのお題',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              const Icon(Icons.smart_toy_outlined,
                  size: 12, color: Colors.white54),
              const SizedBox(width: 4),
              Text('エンジン: ${widget.controller.engineLabel}',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _textController,
            maxLines: 2,
            // 実AI時にプロンプトへそのまま入るため、極端な長文を防ぐ
            maxLength: 100,
            decoration: InputDecoration(
              counterText: '',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              hintText: '例：リモートワークは今後も主流になるか？',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              suffixIcon: IconButton(
                tooltip: 'ランダムお題',
                icon: const Icon(Icons.casino_outlined),
                onPressed: () {
                  final t = _sampleTopics[Random().nextInt(_sampleTopics.length)];
                  _textController.text = t;
                  setState(() {});
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text('おすすめお題', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          // 縦の占有を抑えるため、チップは横スクロールの1行にする
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _sampleTopics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ActionChip(
                label:
                    Text(_sampleTopics[i], style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  _textController.text = _sampleTopics[i];
                  setState(() {});
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('討論者を2人選ぶ',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text('ロスターをタップすると先手→後手の順に決まります。上のカードをタップすると変更先を切り替えられます。',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                  child: _slotCard(debaterOf(_first), _firstStance, 0, '先手')),
              IconButton(
                tooltip: '立場を入れ替える',
                icon: const Icon(Icons.swap_horiz, color: Colors.white70),
                onPressed: () =>
                    setState(() => _firstStance = _firstStance.opposite),
              ),
              Expanded(
                  child: _slotCard(
                      debaterOf(_second), _firstStance.opposite, 1, '後手')),
            ],
          ),
          const SizedBox(height: 6),
          // 全員をスクロールなしで見渡せるよう、コンパクトなアイコングリッドにする。
          // パラメータや肩書きの詳細は上のスロットカード側に表示する。
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.96,
            ),
            itemCount: allDebaters.length,
            itemBuilder: (context, i) => _rosterCard(allDebaters[i]),
          ),
          const SizedBox(height: 12),
          const Text('バトルの長さ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 3, label: Text('短い・3R')),
              ButtonSegment(value: 4, label: Text('普通・4R')),
              ButtonSegment(value: 6, label: Text('長い・6R')),
            ],
            selected: {_rounds},
            onSelectionChanged: (s) => setState(() => _rounds = s.first),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('エンタメ寄りの口調にする'),
            subtitle: const Text('オフにすると少し真面目な議論になります（モックでは口調の強さに反映）',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            value: _entertainment,
            onChanged: (v) => setState(() => _entertainment = v),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.bolt),
              label: const Text('バトル開始',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5484D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              if (widget.controller.historyResults.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  const Text('過去のバトル',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...List.generate(
                    widget.controller.historyResults.length,
                    (i) {
                      final r = widget.controller.historyResults[i];
                      final w = debaterOf(r.winnerId);
                      return Card(
                        color: Colors.white.withValues(alpha: 0.05),
                        child: ListTile(
                          leading: DebaterAvatar(debater: w, size: 36),
                          title: Text(widget.controller.historyTopics[i],
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${w.name} の勝利'),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 選択中ペアのカード。タップでロスター割当先スロットを切り替える。
  Widget _slotCard(Debater d, Stance stance, int slot, String slotLabel) {
    final active = _activeSlot == slot;
    return GestureDetector(
      onTap: () => setState(() => _activeSlot = slot),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: d.color.withValues(alpha: 0.10),
          border: Border.all(
            color: active ? d.color : d.color.withValues(alpha: 0.5),
            width: active ? 2.2 : 1.0,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(slotLabel,
                    style: TextStyle(
                        color: active ? d.color : Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                if (active) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.edit, size: 11, color: d.color),
                ],
              ],
            ),
            const SizedBox(height: 4),
            DebaterAvatar(debater: d, size: 36),
            const SizedBox(height: 4),
            Text(d.name,
                style: TextStyle(color: d.color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('${stance.label}派',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            Text(d.catchPhrase,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            // パラメータは縦3段だと場所を取るため、1行に3つ並べる
            Row(
              children: [
                _paramBar('論理', d.paramLogic, d.color),
                const SizedBox(width: 6),
                _paramBar('熱量', d.paramHeat, d.color),
                const SizedBox(width: 6),
                _paramBar('共感', d.paramEmpathy, d.color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ロスターの1人分セル（コンパクト）。選択中なら色枠と先手/後手ラベルを出す。
  /// 名前が長い論客は FittedBox で1行に収める。
  Widget _rosterCard(Debater d) {
    final slotLabel =
        d.id == _first ? '先手' : (d.id == _second ? '後手' : null);
    final selected = slotLabel != null;
    return GestureDetector(
      onTap: () => _assign(d.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        decoration: BoxDecoration(
          color: selected
              ? d.color.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected ? d.color : Colors.white.withValues(alpha: 0.12),
            width: selected ? 1.8 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DebaterAvatar(debater: d, size: 23),
            const SizedBox(height: 0.5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(d.name,
                  maxLines: 1,
                  style: TextStyle(
                      color: selected ? d.color : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 10)),
            ),
            // 未選択でも高さを予約し、グリッドの行高を揃える
            Text(slotLabel ?? '',
                style: TextStyle(
                    color: d.color, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  /// スロットカード内のパラメータ表示（ラベル＋数値の下に細いバー）。
  /// 3つ横並びで使うため Expanded 前提のコンパクトな形にしている。
  Widget _paramBar(String label, int value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label $value',
              style: const TextStyle(color: Colors.white54, fontSize: 9)),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (value / 5).clamp(0, 1),
              minHeight: 4,
              backgroundColor: Colors.white12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
