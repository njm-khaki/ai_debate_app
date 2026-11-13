import 'package:flutter/material.dart';

import '../models/debate_models.dart';

/// 論客アバター。発言中はリングが光り、少し拡大する。
class DebaterAvatar extends StatelessWidget {
  final Debater debater;
  final double size;
  final bool speaking;
  final bool dimmed;

  const DebaterAvatar({
    super.key,
    required this.debater,
    this.size = 64,
    this.speaking = false,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: speaking ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: AnimatedOpacity(
        opacity: dimmed ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: debater.color,
              width: speaking ? 3.5 : 2,
            ),
            boxShadow: speaking
                ? [
                    BoxShadow(
                      color: debater.color.withValues(alpha: 0.55),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: ClipOval(
            child: Image.asset(debater.avatarAsset, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

/// 勢いゲージ（綱引き型）。value = 先手側シェア 0-100
class MomentumGauge extends StatelessWidget {
  final double value;
  final Debater first;
  final Debater second;

  const MomentumGauge({
    super.key,
    required this.value,
    required this.first,
    required this.second,
  });

  @override
  Widget build(BuildContext context) {
    final f = value.round();
    final s = 100 - f;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$f%',
                style: TextStyle(
                    color: first.color, fontWeight: FontWeight.bold)),
            const Text('勢いメーター',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            Text('$s%',
                style: TextStyle(
                    color: second.color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final firstWidth =
                (constraints.maxWidth * (value.clamp(0, 100) / 100));
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Container(height: 12, color: second.color),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    width: firstWidth,
                    height: 12,
                    color: first.color,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          value >= 55
              ? '${first.name} $f% 優勢'
              : value <= 45
                  ? '${second.name} $s% 優勢'
                  : '互角の展開',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

/// 発言吹き出し
class MessageBubble extends StatelessWidget {
  final DebateMessage message;
  final BattleConfig config;

  const MessageBubble({super.key, required this.message, required this.config});

  @override
  Widget build(BuildContext context) {
    if (message.kind == SpeakerKind.judge) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5C542).withValues(alpha: 0.14),
              border: Border.all(
                  color: const Color(0xFFF5C542).withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFF5C542), fontSize: 12.5, height: 1.4),
            ),
          ),
        ),
      );
    }

    final debater = debaterOf(message.debaterId!);
    final isLeft = message.debaterId == config.first;
    final stance = config.stanceOf(message.debaterId!);

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 290),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: debater.color.withValues(alpha: 0.20),
        border: Border.all(color: debater.color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(isLeft ? 2 : 14),
          bottomRight: Radius.circular(isLeft ? 14 : 2),
        ),
      ),
      child: Text(message.text,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
    );

    final nameRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(debater.name,
            style: TextStyle(
                color: debater.color,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: debater.color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(stance.label,
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLeft) ...[
            DebaterAvatar(debater: debater, size: 34),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [nameRow, const SizedBox(height: 4), bubble],
            ),
          ),
          if (!isLeft) ...[
            const SizedBox(width: 8),
            DebaterAvatar(debater: debater, size: 34),
          ],
        ],
      ),
    );
  }
}

/// 入力中インジケーター
class TypingIndicator extends StatelessWidget {
  final Debater debater;
  final bool isLeft;

  const TypingIndicator(
      {super.key, required this.debater, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isLeft) ...[
            DebaterAvatar(debater: debater, size: 34, speaking: true),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('${debater.name}が入力中…',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ),
          if (!isLeft) ...[
            const SizedBox(width: 8),
            DebaterAvatar(debater: debater, size: 34, speaking: true),
          ],
        ],
      ),
    );
  }
}
