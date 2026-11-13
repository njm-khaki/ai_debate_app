# ローカルAPKビルド手順（1回で終わらせるチェックリスト）

このVM内ではGradleが起動できないため、APKはあなたのPCで作ります。
所要時間の目安は初回セットアップ込みで30〜60分です。

## 0. 準備（初回のみ）

- Flutter 3.47.9（Dart 3.13.7）をインストールし、`flutter --version` で確認
- Android Studio（Android SDK同梱）をインストール
- zipを展開して `ai_resuba_app` に移動

## 1. ビルド

```bash
cd ai_resuba_app
flutter pub get
flutter build apk --release --dart-define=GEMINI_API_KEY=<あなたのキー>
```

生成物: `build/app/outputs/flutter-apk/app-release.apk`

## 2. 実AIが動いているか確認（新機能）

端末にAPKを転送してインストールし、アプリを開きます。

- お題入力画面に「エンジン: Gemini (gemini-3.8-flash)」と出れば実AI選択OK
  （キーなしビルドだと「ローカルモック」になります）
- 3Rで1バトル回し、対戦画面のジャッジバーに「モックへfallback」が
  出ない（0回）ことを確認。これで実AIが実際に発言を作っています
- fallbackが出る場合はキーかモデル名を確認してください

## 3. キーのローテーション（ビルド直後）

キー（2026-11-10にチャットへ貼られたもの）はこのAPKに埋め込まれます。
ビルドと動作確認が終わったら、AI Studioでそのキーを再発行（Disable → Create new）してください。
次にビルドし直すときは、新しいキーをコマンドにだけ入れてください（チャットには貼らないこと）。

## 注意

- この方式ではキーがAPKから抽出可能なので、APKは自分の端末用に留めてください
- 既定モデルは gemini-3.8-flash です（gemini-2.5-flash は新規キーでは利用不可のため変更済み）
