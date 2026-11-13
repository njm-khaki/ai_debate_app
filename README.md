# AIレスバ アリーナ（Flutter）

20人の論客から2人を選んでお題についてレスバさせ、ジャッジAIが決着を判定し、
要約AIが最後にまとめる観戦型アプリです。バックエンドなしで単体動作します。

このREADMEは、セットアップから実行・ビルド・検証までの手順をまとめたものです。
Android APKを実機向けに作る場合は、チェックリスト形式の
[LOCAL_APK_BUILD.md](LOCAL_APK_BUILD.md) も併せて参照してください。

## クイックスタート

```bash
cd ai_resuba_app
flutter pub get
flutter run -d chrome   # まずWebで動かすのが一番手軽です
```

APIキーを何も渡さなければ、キー不要のローカルモックエンジンでそのまま遊べます。
実AI（Gemini / OpenAI）を使う場合は「AIエンジンの設定」を参照してください。

## 前提環境

| 用途 | 必要なもの |
|---|---|
| 共通 | Flutter SDK（後述の実績バージョン推奨）。インストールは [Flutter公式手順](https://docs.flutter.dev/get-started/install) を参照 |
| Androidビルド | Android Studio（Android SDK同梱）または Android SDK + JDK 21。`flutter doctor` で不足を確認できます |
| iOSビルド | macOS + Xcode（署名には Apple ID / 開発者登録が必要） |
| Webビルド | Chrome（実行確認用） |

セットアップ後は次で環境を自己診断できます。

```bash
flutter --version
flutter doctor
```

### 開発環境（実績値）

開発時に実際に使った環境です。同じバージョンに揃えれば、ローカルでも同じ構成で動きます。

| 項目 | 内容 |
|---|---|
| OS | Ubuntu 24.04.5 LTS（x86_64）のVM上で開発 ※アプリ自体はOS非依存です |
| Flutter | **3.47.9 stable**（公式の Linux 向け tarball を展開して使用） |
| Dart | **3.13.7**（Flutter同梱。`pubspec.yaml` の指定も `sdk: ^3.13.7`） |
| DevTools | 2.60.0 |
| プロジェクト生成 | `flutter create --project-name ai_resuba --org jp.resuba --platforms=android,ios,web` |
| IDE | 使用していません（CLIのみ）。VS Code / Android Studio でもそのまま開けます |
| 依存パッケージ | `http: ^1.2.2` と `cupertino_icons: ^1.0.8`、およびSDK付属の `flutter_localizations`（日本語ロケール用）。状態管理は標準の `ChangeNotifier` |
| Androidテンプレート側 | Gradle 9.3.1 / Kotlin 2.4.0（Flutter 3.47.9 のデフォルトのまま未変更） |
| Java | JDK 21（Temurin）※APKビルド時に使用 |
| Android SDK | platforms 35/36、build-tools 35.0.0/36.0.0、platform-tools |

Flutterは新しいバージョンでも大抵動きますが、画面やテンプレートの差異を避けたいなら
**3.47.9 に揃えるのが確実**です。FVMを使っているなら `fvm install 3.47.9` で固定できます。

## 実行方法

```bash
flutter pub get          # 依存取得（初回と pubspec 変更時）
flutter run -d chrome    # Web（Chrome）で実行
flutter run              # 接続中の実機 / エミュレータで実行
```

## ビルド方法

### Web（確認用）

```bash
flutter build web --release
# 生成物: build/web/（静的ホスティングにそのまま配置可能）
```

### Android APK（実機配布用）

```bash
flutter build apk --release
# 生成物: build/app/outputs/flutter-apk/app-release.apk

# 実AI（Gemini）を使う場合：キーを付けてビルドする
flutter build apk --release --dart-define=GEMINI_API_KEY=<あなたのキー>
```

- 生成したAPKをAndroid端末に転送してインストールできます（提供元不明アプリの許可が必要）
- デバッグ用は `flutter build apk --debug`
- 端末アーキテクチャ別に分けたい場合は `--split-per-abi` を付けると APK が3つに分かれます
- リリース版の `AndroidManifest.xml` には INTERNET 権限を設定済みです（実AI通信に必須。
  欠けていると無言でモックに落ち続けるため、回帰テスト `test/manifest_test.dart` で固定しています）
- APK作成の通し手順と実機確認・キーローテーションは [LOCAL_APK_BUILD.md](LOCAL_APK_BUILD.md) 参照

### iOS

```bash
flutter build ios --release   # macOS + Xcode が必要です
```

## AIエンジンの設定

`--dart-define` でキーを渡すと実AIに切り替わります。指定は**実行時・ビルド時**に必要です
（後から付け直す場合は再実行／再ビルドしてください）。

| 変数 | 意味 | 既定値 |
|---|---|---|
| `GEMINI_API_KEY` | Gemini APIキー（最優先で使われます） | なし（未指定なら次へ） |
| `GEMINI_MODEL` | Geminiのモデル名 | `gemini-3.8-flash` |
| `OPENAI_API_KEY` | OpenAI APIキー（Geminiキーが無い場合に使用） | なし |
| `OPENAI_MODEL` | OpenAIのモデル名 | `gpt-4o-mini` |

優先順位は **Gemini > OpenAI > ローカルモック** です。

```bash
# Geminiを使う（最優先）
flutter run --dart-define=GEMINI_API_KEY=AIza... --dart-define=GEMINI_MODEL=gemini-3.8-flash
# OpenAIを使う
flutter run --dart-define=OPENAI_API_KEY=sk-... --dart-define=OPENAI_MODEL=gpt-4o-mini
# 両方指定した場合は Gemini が優先されます
```

- 既定モデルが `gemini-3.8-flash` なのは、`gemini-2.5-flash` が新規キーでは利用不可（404）のためです
- 実行中のエンジンはお題入力画面に「エンジン: …」と表示され、対戦画面のジャッジバーにも出ます。
  実AIの呼び出しが失敗してモックへ倒れた場合は「（モックへfallback N回）」と回数が表示されるので、
  実AIが本当に動いているかを画面で確認できます
- キーは `--dart-define` でバイナリに埋め込まれ、抽出可能です。個人利用は問題ありませんが、
  公開配布する場合はキーをサーバ側プロキシへ移してください。また、キー自体をチャットや
  ソースコードに貼らないでください

## 検証方法

```bash
flutter analyze   # 静的解析（警告ゼロが基準）
flutter test      # テスト全実行（現在67件）
```

テストの内訳は、エンジン単体（モック／OpenAI／Gemini）、判定JSONのパースと
勝者バリデーション、スコア正規化などの回帰テスト、ロスターと討論者選択UI、
状態遷移（ステートマシン）、AndroidManifestの権限チェックなどです。

## 画面

1. **お題入力**：お題入力（100文字まで）、おすすめ／ランダムお題、
   討論者選択（ロスターからタップで先手→後手の順に決定。選んだ2人の
   パラメータは上のカードで確認）、立場の入れ替え、バトルの長さ（3R/4R/6R）、
   エンタメ口調トグル、過去のバトル履歴
2. **対戦**：VS対峙演出 → ジャッジバー（決着度メーター＋ターン数＋使用エンジン）、
   勢いメーター（綱引き型）、発言タイムライン、入力中インジケーター、
   一時停止／倍速／「判定を促す」
3. **結果**：勝者カード、スコア内訳（ロジック／根拠・具体例／反論への対応／ユーモア）、
   ジャッジAIの判定理由、要約AIのまとめ（一言結論＋賛成／反対の主張リスト。
   主張リストは実際の議論から作られます：モックでは対戦中に使われた論点、
   実AIではジャッジが議論記録から抽出）、立場を替えて再戦／新しいお題

## 論客ロスター

最初の画面で先手・後手を選べます。各論客にはパラメータ（論理／熱量／共感）と
スコアの癖（得意・不得意カテゴリへの倍率）が設定されています。

| 論客 | 色 | 特徴 |
|---|---|---|
| ひろゆきAI | 青 | 冷静に、論理で切る |
| ホリエモンAI | 橙 | 熱く、行動で攻める |
| 松岡修造AI | 真紅 | 諦めるな、熱く応援する。特殊特性「逆境燃焼」：劣勢なほど反論と熱で盛り返す |
| マツコAI | 黄緑 | 生活実感と直感で刺す。ユーモアに強い |
| 池上彰AI | スチール | やさしく整理して本質を突く。論理と根拠に強い |
| 落合陽一AI | シアン | 問いの枠組みを更新する。メタな反論に強い |
| 小泉進次郎AI | エメラルド | 進次郎構文（同語反復の言い換え）で押し切る。論理・根拠は薄く、ユーモアが意図せず高い |
| なんJ民AI | 黄 | 猛虎弁（なんJ語）で意味不明に攻める。熱量最大、ユーモア倍率は全員最強 |
| カズレーザーAI | 深紅 | 博識と毒舌で静かに詰める。「ちなみに」の豆知識で事実誤認を淡々と正す、論理・根拠はトップ級 |
| 関暁夫AI | 紫 | 真実は闇の中から語る。全論点を都市伝説・陰謀論に接続する。「信じるか信じないかは、あなた次第」 |
| 黒柳徹子AI | ピンク | 質問攻めで討論を乗っ取る。好奇心旺盛なインタビューで相手に持論を言わせない。共感は全員トップ級 |
| 細木数子AI | ブロンズ | ズバリ、運命で言い切る。全論点を六星占術と運命に帰着させる断定型。関の「囁き」とは別の圧 |
| 和田アキ子AI | ワインレッド | 迫力の一言で制圧する。姉御の貫禄と大きな笑いで飲み込む、反論への対応はトップ級 |
| ジミー大西AI | ラベンダー | 天然の疑問で核心を突く。「絵に描けるかどうか」が基準。純粋なズレが武器 |
| 出川哲朗AI | ティール | ヤバいよ連発で粘り勝つ。汗だくで焦りながら、出川イングリッシュ混じりで体当たりする |
| ナガノAI | ブラウン | 笑顔のまま、一番痛いところを突く。穏やかな口調で容赦なく追い詰めるサイコパスな作者タイプ。共感パラメータは全員で唯一の0 |
| ちい〇わAI | ソフトピンク | わぁ……などしか話せず、議論ができないネタ枠。論理・根拠は全員最弱で、発言は鳴き声とナレーションで構成される |
| ハチ〇レAI | インディゴ | 一生懸命、自分の言葉で届ける。難しい言葉に背伸びしながらも真っ直ぐ議論できる優等生タイプ |
| う〇ぎAI | アンバー | プルヤァなど奇声を発して議論ができないネタ枠。熱量は最大級で、勢いとユーモアだけは高い |
| モ〇ンガAI | スカイ | あざとく甘えて、場を支配する。「褒めて」アピールと泣き真似で切り抜ける計算高いタイプ |

討論者同士の有利不利の総当たり分析は、15人ロスター時点のものを
`docs/matchup_analysis_15.md`（Python再実装シミュレーション）と
`docs/matchup_analysis_15_dart.md`（Dart実エンジンでの検証）にまとめています。
20人ロスター時点のDart実エンジン検証は `docs/matchup_analysis_20_dart.md` にあります。
10人ロスター時点の旧分析は `docs/matchup_analysis.md` に残しています。

## AIエンジンの仕組み（差し替え可能設計）

`DebateEngine` インターフェースの背後に3実装あります。
選択は `debate_engine_factory.dart` の `selectEngine` が担います。

- `GeminiDebateEngine`：Gemini API の `generateContent`（v1beta）を
  `x-goog-api-key` ヘッダー認証で呼び、判定時は `responseMimeType: application/json` でJSON応答を要求します
- `OpenAiDebateEngine`：OpenAI の chat/completions を呼びます
- `LocalMockDebateEngine`（キーなし時の既定）：APIキー不要。お題と立場に応じたテンプレートで
  各ペルソナの口調を再現します。乱数はお題ハッシュでシードするため、同じお題では同じ展開になり、テスト可能です

実AIエンジンは、失敗した呼び出しをモックへフォールバックするのでアプリは止まりません。
判定JSONの勝者は対戦中の2人以外を受け付けず、その場合もモック判定に倒れます。

## 状態管理

明示的なステートマシンで管理します。設計の詳細と現行の問題分析は
`docs/state_machine_design.md` を参照してください。

- `BattleMachine`（`lib/state/battle_machine.dart`）：副作用を持たない純粋な遷移表。
  遷移表にない遷移は不正として拒否されます。ガード（判定リクエスト可否、早期決着条件）もここに一元化
- 再生状態（playing/paused）は直交する小マシン `PlaybackMachine` で管理し、速度は状態ではなく拡張状態として保持
- `DebateController`（ChangeNotifier）はイベントをディスパッチする実行役で、タイマーとエンジン呼び出しは
  世代トークンで守られています。対戦途中で画面を離れるとバトルは中断され、裏で完走することはありません

`setting → versus → debating → verdict → summarizing → finished`

ジャッジAIの「決着」は2経路あります：規定ターン到達／勢い差が大きい場合の早期決着、
加えてユーザーの「判定を促す」ボタン。

## プロジェクト構成

```
lib/
  main.dart
  models/debate_models.dart          # 型・論客定義・スコア
  services/mock_debate_engine.dart   # ローカルモックAI
  services/openai_debate_engine.dart
  services/gemini_debate_engine.dart
  services/persona_prompts.dart      # 実AI共通プロンプト／判定JSONパース
  services/debate_engine_factory.dart # 優先順位付きエンジン選択
  state/debate_controller.dart       # 状態機械の実行役
  state/battle_machine.dart          # 純粋な遷移表
  screens/topic_screen.dart
  screens/battle_screen.dart
  screens/result_screen.dart
  widgets/debate_widgets.dart        # アバター / 勢いゲージ / 吹き出し
assets/avatars/                      # 論客20人の似顔絵アバター
app_icon_1024.png                    # アプリアイコンのマスター画像
test/                                # エンジン / 回帰 / ロスター / UI / 状態遷移など
docs/
  state_machine_design.md            # 状態機械の設計書
  code_review.md                     # セルフコードレビューの記録
  matchup_analysis.md                # 討論者の相性・勝率分析（10人ロスター時点）
  matchup_analysis_15.md             # 同・15人版（Pythonシミュレーション）
  matchup_analysis_15_dart.md        # 同・15人版（Dart実エンジン検証）
LOCAL_APK_BUILD.md                   # ローカルAPKビルドのチェックリスト
```

## トラブルシューティング

- **「エンジン: ローカルモック」と表示される**：キーが渡っていません。`--dart-define` は
  実行／ビルドのたびに必要です。付け忘れてビルドしたAPKは作り直してください
- **「モックへfallback」が増える**：実AIの呼び出しが失敗しています。キーの有効性、
  モデル名（`gemini-2.5-flash` は新規キー不可 → `gemini-3.8-flash`）、
  端末のネットワーク接続を確認してください
- **実機でだけ通信できない**：リリース版の AndroidManifest に INTERNET 権限が
  あるか確認してください（現行コードには設定済みで、テストでも固定しています）
- **ビルドが環境エラーで止まる**：まず `flutter doctor` で不足コンポーネントを確認してください。
  Gradle や JDK のエラーは Android Studio 側の SDK / JDK 設定が原因のことが多いです
- **開発VMについて**：本プロジェクトの開発VMはサンドボックスの制約（プロセス間の
  ループバックTCP遮断）で Gradle デーモンが起動できず、APKビルドができませんでした。
  これはVM固有の制約で、通常のPC環境では発生しません。開発VMでの検証範囲は
  `analyze` / `test` / Webビルドまでです

## 注意

アバターと口調は「本人風」のパロディ表現です。実在人物の公式発言ではありません。
公開・配布する場合は、非公式のパロディである旨の表記を検討してください。
