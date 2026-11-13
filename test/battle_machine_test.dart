import 'dart:async';

import 'package:ai_resuba/models/debate_models.dart';
import 'package:ai_resuba/state/battle_machine.dart';
import 'package:ai_resuba/state/debate_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _config = BattleConfig(
  topic: 'テストお題',
  first: DebaterId.hiroyuki,
      second: DebaterId.horiemon,
      firstStance: Stance.pro,
  maxRounds: 3,
  entertainmentTone: true,
);

void main() {
  group('BattleMachine 遷移表', () {
    test('正常系の遷移がすべて通る', () {
      expect(BattleMachine.transition(BattlePhase.setting, BattleEvent.start),
          BattlePhase.versus);
      expect(
          BattleMachine.transition(
              BattlePhase.versus, BattleEvent.versusElapsed),
          BattlePhase.debating);
      expect(
          BattleMachine.transition(
              BattlePhase.debating, BattleEvent.debateFinished),
          BattlePhase.verdict);
      expect(
          BattleMachine.transition(
              BattlePhase.verdict, BattleEvent.verdictShown),
          BattlePhase.summarizing);
      expect(
          BattleMachine.transition(
              BattlePhase.summarizing, BattleEvent.summaryCompleted),
          BattlePhase.finished);
      // 再戦
      expect(BattleMachine.transition(BattlePhase.finished, BattleEvent.start),
          BattlePhase.versus);
    });

    test('不正な遷移はすべて拒否される（reset以外）', () {
      const valid = {
        (BattlePhase.setting, BattleEvent.start),
        (BattlePhase.versus, BattleEvent.versusElapsed),
        (BattlePhase.debating, BattleEvent.debateFinished),
        (BattlePhase.verdict, BattleEvent.verdictShown),
        (BattlePhase.summarizing, BattleEvent.summaryCompleted),
        (BattlePhase.finished, BattleEvent.start),
      };
      for (final from in BattlePhase.values) {
        for (final event in BattleEvent.values) {
          if (event == BattleEvent.reset) continue;
          final result = BattleMachine.transition(from, event);
          if (valid.contains((from, event))) {
            expect(result, isNotNull, reason: '$from + $event は許可されるべき');
          } else {
            expect(result, isNull, reason: '$from + $event は拒否されるべき');
          }
        }
      }
    });

    test('reset は全状態から setting へ戻る', () {
      for (final from in BattlePhase.values) {
        expect(BattleMachine.transition(from, BattleEvent.reset),
            BattlePhase.setting);
      }
    });
  });

  group('ガード', () {
    test('canRequestVerdict の境界（debating かつ 4ターン以降）', () {
      expect(
          BattleMachine.canRequestVerdict(
              phase: BattlePhase.debating, turnIndex: 3),
          isFalse);
      expect(
          BattleMachine.canRequestVerdict(
              phase: BattlePhase.debating, turnIndex: 4),
          isTrue);
      expect(
          BattleMachine.canRequestVerdict(
              phase: BattlePhase.versus, turnIndex: 10),
          isFalse);
    });

    test('shouldEarlyFinish の境界（6ターン以降 かつ 勢い差30以上）', () {
      expect(
          BattleMachine.shouldEarlyFinish(turnIndex: 5, momentum: 90), isFalse);
      expect(
          BattleMachine.shouldEarlyFinish(turnIndex: 6, momentum: 79), isFalse);
      expect(
          BattleMachine.shouldEarlyFinish(turnIndex: 6, momentum: 80), isTrue);
      expect(
          BattleMachine.shouldEarlyFinish(turnIndex: 6, momentum: 20), isTrue);
    });
  });

  group('PlaybackMachine', () {
    test('debating 中だけ pause/resume できる', () {
      expect(
          PlaybackMachine.transition(PlaybackState.playing, PlaybackEvent.pause,
              phase: BattlePhase.debating),
          PlaybackState.paused);
      expect(
          PlaybackMachine.transition(PlaybackState.paused, PlaybackEvent.resume,
              phase: BattlePhase.debating),
          PlaybackState.playing);
      expect(
          PlaybackMachine.transition(PlaybackState.playing, PlaybackEvent.pause,
              phase: BattlePhase.finished),
          isNull);
      expect(
          PlaybackMachine.transition(PlaybackState.playing, PlaybackEvent.resume,
              phase: BattlePhase.debating),
          isNull);
    });
  });

  group('DebateController 統合', () {
    testWidgets('バトルが状態遷移どおりに完走する', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final c = DebateController();
      unawaited(c.startBattle(_config));
      expect(c.phase, BattlePhase.versus);
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(c.phase, BattlePhase.finished);
      expect(c.result, isNotNull);
      expect(c.historyTopics, contains('テストお題'));
    });

    testWidgets('二重起動は拒否され、開始メッセージが重複しない', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final c = DebateController();
      unawaited(c.startBattle(_config));
      unawaited(c.startBattle(_config)); // versus 中の start は不正遷移
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      final openingCount = c.messages
          .where((m) => m.text.contains('討論を開始します'))
          .length;
      expect(openingCount, 1);
      c.cancelCurrentBattle();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    });

    testWidgets('対戦中のキャンセル後は状態が進まず、結果も作られない', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final c = DebateController();
      unawaited(c.startBattle(_config));
      // debating に入って数ターン進める
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(c.phase, BattlePhase.debating);
      final messagesAtCancel = c.messages.length;
      expect(messagesAtCancel, greaterThan(1));

      c.cancelCurrentBattle();
      expect(c.phase, BattlePhase.setting);

      // 十分に時間を進めても、裏でループが完走しないこと
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(c.phase, BattlePhase.setting);
      expect(c.messages.length, messagesAtCancel);
      expect(c.result, isNull);
      expect(c.historyTopics, isEmpty);
    });

    testWidgets('finished での cancel は結果を壊さない', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final c = DebateController();
      unawaited(c.startBattle(_config));
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(c.phase, BattlePhase.finished);
      c.cancelCurrentBattle();
      expect(c.phase, BattlePhase.finished);
      expect(c.result, isNotNull);
    });
  });
}
