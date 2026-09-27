# subsc_management

契約しているサブスクリプション（アプリ / Webサービス）を一元管理し、毎月いくらかかっているかをひと目で把握するための Flutter アプリです。

## 主な機能

- **サービスマスタからの登録**
  アプリ内に「アプリ / Webサービス名」と、それに紐づく「プラン（複数）」「金額」をマスタデータとして保持します。
  登録時はサービスを選択 → プランを選択するだけで、金額などの情報が自動で入力されます。
- **契約中サブスクの一覧表示**
  登録したサブスクを一覧で閲覧できます。サービス名・プラン・金額・支払いサイクルを表示します。
- **金額の手動編集**
  サービス側の価格改定やキャンペーン等で金額が変わることを想定し、登録済みサブスクの金額を手動で書き換えられます。
  書き換えた金額が一覧や合計の表示に反映されます（マスタの金額は変更しません）。
- **契約形態の表示と月 / 年の切り替え**
  各サブスクを自分がどう契約しているか（月額 / 年額）を表示します。
  月表示では月額換算（年額 ÷ 12）、年表示では年間の金額（月額 × 12）で一覧と合計を表示します。
- **ドル建てサービスの円換算**
  ドル建てのプランは為替レートで円に換算して表示・合算します。レートは手入力で、登録されている中で最新のレートを使います。
- **月ごとの金額履歴**
  契約中サブスクの金額を毎月記録し、サブスクごとの金額推移や月ごとの合計の推移を見られます。
  記録にはその月の金額・契約形態・為替レートを保存するため、後から金額やレートが変わっても過去の記録は変わりません。

## デザイン / UI・UX コンセプト

- **ダークモードを基本**とし、長時間見ても疲れにくい配色にする
- 背景とカードのコントラストを確保し、**金額・サービス名が最も目立つ**情報設計にする
- 月額合計は画面上部に大きく表示し、「今いくら払っているか」を**開いた瞬間にわかる**ようにする
- 登録は「サービス選択 → プラン選択 → 確認」の最小ステップで完了できるようにし、入力の手間を減らす
- 金額の編集は一覧からすぐに行える導線にする

## データ保存

デフォルトでは端末内のストレージ（**SQLite**）にデータを保存します。外部サーバーへの送信は行いません。

### データ構成

DDL は [`docs/db/schema.sql`](docs/db/schema.sql)、主なクエリは [`docs/db/queries.sql`](docs/db/queries.sql)、動作確認用データは [`docs/db/seed_sample.sql`](docs/db/seed_sample.sql) にあります。

| テーブル / ビュー | 役割 | 主な項目 |
| --- | --- | --- |
| `currencies` | 通貨マスタ | code（JPY / USD）, symbol, minor_unit_factor |
| `exchange_rates` | 円換算レート | currency_code, rate_to_jpy, rate_date |
| `services` | アプリ / Webサービスのマスタ | name, service_type, category, icon, url |
| `plans` | サービスに紐づくプランのマスタ（1サービスに複数） | service_id, name, currency_code, price, billing_interval_months（1: 月額 / 12: 年額） |
| `subscriptions` | ユーザーが契約中のサブスク | plan_id, custom_price（手動で書き換えた金額）, start_date, billing_day, status, memo |
| `subscription_monthly_records` | 月ごとの金額記録（履歴） | subscription_id, year_month, price, rate_to_jpy, price_jpy, monthly_cost_jpy |
| `v_subscriptions` | 一覧・集計用ビュー | contract_label, effective_price, monthly_cost_jpy, yearly_cost_jpy |
| `v_monthly_totals` | 月ごとの合計推移 | year_month, monthly_total_jpy |

- 表示・集計に使う金額は、`custom_price` が設定されていればその値、なければプランの `price` を使います。
- 金額は通貨の最小単位の整数で保存します（円は 1 円単位、ドルはセント単位）。
- 月次記録はアプリ起動時と金額編集時に当月分を記録（同じ月は上書き）します。
- アプリを開かなかった月は、次に開いたときに現在の金額・レートで埋めます。

## 動作環境

- Flutter 3.47.5（stable）/ Dart 3.13.4
- 対応プラットフォーム: Android / iOS（Web・デスクトップはプロジェクトとして生成済み）

## 起動方法

### 1. 依存パッケージの取得

```bash
flutter pub get
```

### 2. 接続デバイス / エミュレーターの確認

```bash
flutter devices
flutter emulators
```

### 3. Android エミュレーターで起動

```bash
# エミュレーターを起動（例: Pixel_6_API_31）
flutter emulators --launch Pixel_6_API_31

# アプリを起動
flutter run -d emulator-5554
```

デバイスが 1 台だけ接続されている場合は `flutter run` のみで起動できます。

### 4. iOS シミュレーターで起動

Xcode のセットアップ（`flutter doctor` で確認）が完了している必要があります。

```bash
open -a Simulator
flutter run
```

### 実行中の操作

| キー | 動作 |
| --- | --- |
| `r` | ホットリロード |
| `R` | ホットリスタート |
| `q` | アプリ終了 |

## 開発用コマンド

```bash
flutter analyze   # 静的解析
flutter test      # テスト実行
```
