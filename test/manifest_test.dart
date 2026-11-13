// リリース用 AndroidManifest の必須権限を守る回帰テスト。
// INTERNET 権限がないと、実AIエンジン（Gemini/OpenAI）の通信が全て失敗し、
// 無言でモックへフォールバックしてしまう（過去に実際に欠けていた）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main の AndroidManifest に INTERNET 権限が宣言されている', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      manifest,
      contains('android.permission.INTERNET'),
      reason: '実AIエンジンの HTTPS 通信に INTERNET 権限が必須',
    );
  });
}
