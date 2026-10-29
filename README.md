# Saunamanager2

サウナ施設向けの **入退館・会計確認アプリ**（iOS / SwiftUI）。
NFCタグ（ロッカーごと）のスキャンで入退館を記録し、利用内容を Google スプレッドシートへ自動で記録します。

## 主な機能

- **NFCによる入退館**：ロッカーのNFCタグ（`saunamanager2://checkin?locker=N001`）をスキャンすると、未入館なら入館登録、在館中なら退館処理と会計確認を表示
- **入館登録**：通常利用／ランステ／その他の3カテゴリのプラン選択、レンタル品・割引・荷物預かり・購入・備考の入力。手動入館にも同じUIを用意
- **朝活・ナイトサウナ・雨割の切り替え**：朝活（7:29〜10:00）・ナイトサウナ（17:59〜22:05）は時刻で自動ON/OFF、雨割は手動
- **退館時の会計確認**：滞在時間・性別・平日/休日・割引から、プラン名（30分／60分／90分／120分／無制限／休日・平日ナイトサウナなど）を自動判定。レンタル品は最安になるようセット（A/B/C）または単品にまとめて表示
- **ランステ＋通常利用**：ランニング開始後にNFCを再スキャン（または手動）でサウナ利用開始を記録。ランニング中の利用者は在館人数に含めない
- **在館中一覧／ロッカーマップ／履歴**：在館状況の確認、スワイプでの削除、同じロッカーの二重入館防止
- **スプレッドシート連携**：Google Apps Script のウェブアプリへ入館・退館・更新・削除を送信

## 技術

- Swift / SwiftUI（iOS 26 以降）、MVVM 風の構成（`GuestStore` が状態管理、`UserDefaults` で永続化）
- Google Apps Script（スプレッドシートへの記録）
- NFC は URL スキーム経由（タグに URL を書き込んでおく）

## ディレクトリ構成

```
Saunamanager2/
├── Models/        GuestRecord（入退館の記録・会計ロジック）
├── Services/      GuestStore（状態管理）、SheetsService（スプレッドシート送信）
├── Views/         在館中一覧・入館登録・退館・履歴・ロッカーマップ・設定 など
└── Config.swift   ローカル設定（Git管理外。Config.example.swift から作成）
apps-script/
└── Code.gs        スプレッドシート側の Google Apps Script
```

## セットアップ

1. `Config.example.swift` を `Saunamanager2/Config.swift` にコピーする
2. `Config.swift` の `sheetsWebAppURL` を、自分の Google Apps Script ウェブアプリのURLに書き換える
3. Xcode で `Saunamanager2.xcodeproj` を開き、Signing & Capabilities の Team を自分のものに設定して実行する（Team ID はリポジトリでは空にしてあります）

スプレッドシートに記録しない場合は、URLがダミーのままでもアプリ自体は動作します（送信は失敗し、ログにエラーが出るだけです）。

## Apps Script（スプレッドシート側）

[`apps-script/Code.gs`](apps-script/Code.gs) をスプレッドシートの Apps Script に貼り付け、「ウェブアプリ」としてデプロイします（手順はファイル冒頭のコメント参照）。
アプリは次の `action` を POST（JSON）で送ります。日付名のシート（`yyyy/MM/dd`）に1行ずつ記録します。

| action | 内容 |
| --- | --- |
| `checkin` | 入館を1行追加 |
| `checkout` | 退館時刻・最終プラン名・レンタル品を更新 |
| `update` | 記録の編集内容を反映 |
| `delete` | 記録を削除 |
| `saunaStart` | 「ランステ＋通常利用」のサウナ利用開始をプラン欄に反映 |

シートの列：番号／日にち／曜日／入り／出／滞在時間／プラン／性別／水着／レンタル／割引／荷物預かり／メモ

## 補足

- 料金計算ロジックは `GuestRecord.swift` に集約しています（プラン判定・水着の無料条件・レンタルセットの最安計算）。
- 店舗固有のルール（時間帯・料金体系）はコード内に直接書かれています。
