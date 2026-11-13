import 'package:flutter/material.dart';

import '../models/debate_models.dart';
import '../state/debate_controller.dart';
import '../widgets/debate_widgets.dart';
import 'battle_screen.dart';

class ResultScreen extends StatelessWidget {
  final DebateController controller;

  const ResultScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final result = controller.result!;
    final cfg = controller.config!;
    final winner = debaterOf(result.winnerId);
    final loser = debaterOf(cfg.opponentOf(result.winnerId));
    final proDebater = debaterOf(cfg.stanceOf(cfg.first) == Stance.pro
        ? cfg.first
        : cfg.second);
    final conDebater = debaterOf(cfg.opponentOf(proDebater.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('勝敗結果'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // 勝者カード
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: winner.color.withValues(alpha: 0.10),
              border: Border.all(color: winner.color.withValues(alpha: 0.55)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events,
                    color: Color(0xFFF5C542), size: 34),
                const SizedBox(height: 10),
                DebaterAvatar(debater: winner, size: 96),
                const SizedBox(height: 10),
                Text('${winner.name} 勝利！',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: winner.color)),
                Text('お題：${cfg.topic}',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // スコア内訳
          const Text('スコア内訳',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _scoreRow('ロジック', (s) => s.logic),
          _scoreRow('根拠・具体例', (s) => s.evidence),
          _scoreRow('反論への対応', (s) => s.rebuttal),
          _scoreRow('ユーモア', (s) => s.humor),
          _scoreRow('合計', (s) => s.total, bold: true, maxValue: 400),
          const SizedBox(height: 22),

          // 判定理由（ジャッジAI）
          _sectionCard(
            icon: Icons.gavel,
            color: const Color(0xFFF5C542),
            title: 'ジャッジAIの判定理由',
            body: result.judgeReason,
          ),
          const SizedBox(height: 14),

          // 要約（要約AI）
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.summarize, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text('要約AIのまとめ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(result.conclusion,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, height: 1.5)),
                ),
                const SizedBox(height: 12),
                Text(result.summaryText,
                    style: const TextStyle(height: 1.6, color: Colors.white70)),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _pointColumn(
                        '賛成側の主張', result.proPoints, proDebater.color)),
                    const SizedBox(width: 12),
                    Expanded(child: _pointColumn(
                        '反対側の主張', result.conPoints, conDebater.color)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),

          // アクション
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final swapped =
                        cfg.copyWith(firstStance: cfg.firstStance.opposite);
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => BattleScreen(
                          controller: controller, config: swapped),
                    ));
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('立場を替えて再戦'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    controller.resetToSetting();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  icon: const Icon(Icons.edit_note),
                  label: const Text('新しいお題'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5484D),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('敗者：${loser.name}も健闘しました',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _scoreRow(String label, int Function(ScoreBreakdown) pick,
      {bool bold = false, int maxValue = 100}) {
    final cfg = controller.config!;
    final result = controller.result!;
    final firstDebater = debaterOf(cfg.first);
    final secondDebater = debaterOf(cfg.second);
    final firstValue = pick(result.scores[cfg.first]!);
    final secondValue = pick(result.scores[cfg.second]!);

    Widget bar(int v, Color color, bool alignRight) {
      return Expanded(
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: (v / maxValue).clamp(0.05, 1.0),
            child: Container(
              height: bold ? 10 : 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
              width: 36,
              child: Text('$firstValue',
                  style: TextStyle(
                      color: firstDebater.color, fontWeight: FontWeight.bold))),
          bar(firstValue, firstDebater.color, true),
          SizedBox(
            width: 92,
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ),
          bar(secondValue, secondDebater.color, false),
          SizedBox(
              width: 36,
              child: Text('$secondValue',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: secondDebater.color,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(height: 1.6)),
        ],
      ),
    );
  }

  Widget _pointColumn(String title, List<String> points, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        ...points.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('・', style: TextStyle(color: color)),
                  Expanded(
                      child: Text(p,
                          style: const TextStyle(
                              fontSize: 12, height: 1.45, color: Colors.white70))),
                ],
              ),
            )),
      ],
    );
  }
}
