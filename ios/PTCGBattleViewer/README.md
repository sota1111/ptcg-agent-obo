# PTCG Battle Viewer for iPhone

`ptcg-battle-log/v1` のJSONログをiPhone上で読み込み、初期盤面から最終イベントまで移動できる
SwiftUIアプリです。iOS 17以降に対応します。

## Simulator / 実機で起動

1. macOSで `PTCGBattleViewer.xcodeproj` をXcode 16以降で開きます。
2. Scheme `PTCGBattleViewer` とiPhone Simulator（または接続済みiPhone）を選択します。
3. 実機の場合は Target → Signing & Capabilities で自分のTeamと一意なBundle Identifierを設定します。
4. Run（⌘R）し、右上の「ログを開く」から `ptcg-battle-log/v1` JSONを選択します。
5. 先頭・前・次・末尾ボタンまたはスライダーで時点を移動します。
6. 手札・バトル場・ベンチのカードをタップすると、カード種別、説明、技、ダメージ、
   技に必要なエネルギーを確認できます。

手札のカード名と詳細を表示するには、各プレイヤーの盤面に `hand`（`CardState` の配列）を、
ドローイベントに `cards`（ドローした `CardState` の配列）を含めます。従来どおり
`handCount` のみのログも読み込めますが、その場合は非公開の手札として枚数だけを表示します。
カード詳細では任意フィールド `cardType`、`rulesText`、`attacks` を利用し、各技は `name`、
エネルギー種別の `cost` 配列、任意の `damage` と `text` を持ちます。

動作確認用ログにはリポジトリの
`src/__tests__/fixtures/battle-log.valid.json` を利用できます。AirDrop、iCloud Drive、または
Filesアプリ経由でiPhoneへ渡してください。

## テスト

Xcodeで Product → Test（⌘U）、またはmacOSのターミナルで次を実行します。

```bash
swift test --package-path ios/PTCGBattleViewer

xcodebuild test \
  -project ios/PTCGBattleViewer/PTCGBattleViewer.xcodeproj \
  -scheme PTCGBattleViewer \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## TestFlight配信直前まで

1. Release設定のTeam、Bundle Identifier、Version、Buildを確認します。
2. Generic iOS Deviceを選び、Product → Archiveを実行します。
3. OrganizerのValidate Appが成功することを確認します。

依頼者が行う配信作業は、OrganizerのDistribute AppからApp Store Connectへアップロードし、
App Store ConnectでTestFlightビルドを選んでテスターへ公開する工程です。証明書、Provisioning
Profile、App Store Connect上のアプリ登録や法務情報はApple Developerアカウントに紐づくため、
リポジトリには保存しません。
