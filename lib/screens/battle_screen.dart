import 'package:flutter/material.dart';

import '../models/debate_models.dart';
import '../state/debate_controller.dart';
import '../widgets/debate_widgets.dart';
import 'result_screen.dart';

class BattleScreen extends StatefulWidget {
  final DebateController controller;
  final BattleConfig config;

  const BattleScreen({super.key, required this.controller, required this.config});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  final _scrollController = ScrollController();
  bool _navigatedToResult = false;
  bool _userScrolledUp = false;

  DebateController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onUpdate);
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      _userScrolledUp = pos.maxScrollExtent - pos.pixels > 120;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      c.startBattle(widget.config);
    });
  }

  @override
  void dispose() {
    c.removeListener(_onUpdate);
    // 対戦途中で画面を離れたら、裏でループが完走しないよう中断する
    // （結果画面への遷移時は phase が finished なので何も起きない）
    c.cancelCurrentBattle();
    _scrollController.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted) return;
    // 新着が来たら、読み返し中以外は最下部へ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && !_userScrolledUp) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
    if (c.phase == BattlePhase.finished && !_navigatedToResult) {
      _navigatedToResult = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(controller: c),
        ),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    return Scaffold(
      appBar: AppBar(
        title: Text(cfg.topic,
            style: const TextStyle(fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _judgeBar(),
              _vsHeader(cfg),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                  itemCount:
                      c.messages.length + (c.typingDebater != null ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= c.messages.length) {
                      return TypingIndicator(
                          debater: debaterOf(c.typingDebater!),
                          isLeft: c.typingDebater == cfg.first);
                    }
                    return MessageBubble(message: c.messages[i], config: cfg);
                  },
                ),
              ),
              _controls(),
            ],
          ),
          if (c.phase == BattlePhase.versus) _versusOverlay(cfg),
          if (c.phase == BattlePhase.verdict) _centerOverlay('決着！', 'ジャッジAIが判定中…'),
          if (c.phase == BattlePhase.summarizing)
            _centerOverlay('判定完了', '要約AIがまとめています…'),
        ],
      ),
    );
  }

  Widget _judgeBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      color: const Color(0xFFF5C542).withValues(alpha: 0.07),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gavel, size: 16, color: Color(0xFFF5C542)),
              const SizedBox(width: 6),
              Text(
                c.phase == BattlePhase.debating ? 'ジャッジAI 監視中' : 'ジャッジAI',
                style: const TextStyle(
                    color: Color(0xFFF5C542), fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Text('TURN ${c.turnIndex} / ${widget.config.maxRounds * 2}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            c.fallbackInCurrentBattle > 0
                ? '${c.engineLabel}（モックへfallback ${c.fallbackInCurrentBattle}回）'
                : c.engineLabel,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('決着度',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: c.settleProgress,
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFFF5C542),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(c.settleProgress * 100).round()}%',
                  style: const TextStyle(
                      color: Color(0xFFF5C542),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vsHeader(BattleConfig cfg) {
    Widget side(Debater d) {
      final speaking = c.typingDebater == d.id;
      final stance = cfg.stanceOf(d.id);
      return Column(
        children: [
          DebaterAvatar(debater: d, size: 62, speaking: speaking),
          const SizedBox(height: 4),
          Text(d.name,
              style: TextStyle(
                  color: d.color, fontWeight: FontWeight.bold, fontSize: 13)),
          Text('${stance.label}派',
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              side(debaterOf(cfg.first)),
              const Text('VS',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              side(debaterOf(cfg.second)),
            ],
          ),
          const SizedBox(height: 10),
          MomentumGauge(
              value: c.momentum,
              first: debaterOf(cfg.first),
              second: debaterOf(cfg.second)),
        ],
      ),
    );
  }

  Widget _controls() {
    final canVerdict = c.canRequestVerdictNow;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: c.paused ? '再開' : '一時停止',
              icon: Icon(c.paused ? Icons.play_arrow : Icons.pause),
              onPressed: c.togglePause,
            ),
            TextButton.icon(
              onPressed: c.toggleSpeed,
              icon: const Icon(Icons.fast_forward, size: 18),
              label: Text('${c.speed.toStringAsFixed(0)}x'),
            ),
            ElevatedButton.icon(
              onPressed: canVerdict
                  ? () {
                      c.requestVerdict();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('ジャッジAIに判定を促しました。このラウンドで決着します。')));
                    }
                  : null,
              icon: const Icon(Icons.gavel, size: 18),
              label: const Text('判定を促す'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5C542),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _versusOverlay(BattleConfig cfg) {
    Widget sideOf(DebaterId id) {
      final d = debaterOf(id);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DebaterAvatar(debater: d, size: 110),
          const SizedBox(height: 10),
          Text(d.name,
              style: TextStyle(
                  color: d.color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${cfg.stanceOf(id).label}派',
              style: const TextStyle(color: Colors.white70)),
        ],
      );
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            sideOf(cfg.first),
            const Text('VS',
                style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            sideOf(cfg.second),
          ],
        ),
      ),
    );
  }

  Widget _centerOverlay(String title, String sub) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gavel, color: Color(0xFFF5C542), size: 44),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text(sub, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
