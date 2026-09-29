# Google Play データセーフティの回答案

Play Console「アプリのコンテンツ > データ セーフティ」に入力する内容と、その根拠。
**依存か権限を足したら、この文書の「根拠の確かめ方」を回し直して回答を見直す。**

- プライバシーポリシーの URL: <https://fuji18.github.io/lastwhen/privacy-policy/>(原稿は `site/privacy-policy/index.html`)
- 決めた Issue: #70(2026-09-29)

## 回答

| 設問 | 回答 |
| --- | --- |
| 必須のユーザーデータの種類のうち、アプリで収集または共有するものはありますか | **いいえ** |

「いいえ」と答えると、データの種類・暗号化・削除リクエストの設問は出ない。
ストアページには「データは収集されません」「第三者と共有されるデータはありません」と表示される。

## 根拠

Google の定義では、**収集**は「アプリが端末から送信すること」(組み込んだライブラリ・SDK による送信を含む)。
端末の中だけで処理するデータは申告の対象外。

| 観点 | 実態 | 確かめた場所 |
| --- | --- | --- |
| ネットワーク | release に `INTERNET` 権限が無い。通信する依存が無い(`timezone` は推移的に `http` に依存するが、アプリのコードから import しないのでビルドに入らない) | release のマージ済みマニフェスト / functional-design「セキュリティ考慮事項」 |
| 権限 | `POST_NOTIFICATIONS`(通知)/ `RECEIVE_BOOT_COMPLETED`(再起動後に通知の予約を戻す)/ `VIBRATE`(通知の振動)/ `<applicationId>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`(AndroidX が足すアプリ内部用) | 同上 |
| 解析・広告・クラッシュ収集 | 組み込んでいない | `pubspec.yaml` |
| アカウント | 無い | PRD「セキュリティ / プライバシー」 |

### 判断が要ったもの

| 事柄 | 判断 | 理由 |
| --- | --- | --- |
| OS の自動バックアップ(Android Auto Backup) | **収集に当たらない** | 送信するのは OS で、アプリではない。開発者はバックアップの中身を読めない。Play のヘルプはこの件に触れていないので、ここに判断を残す。ポリシーには明記してある(architecture「セキュリティ制約」) |
| データの書き出し(F26 / #68) | **共有に当たらない** | 利用者が自分で共有先を選ぶ操作によってだけ端末の外へ出る。Google の定義では、利用者の明示的な操作による送信で、利用者が送信を予期しているものは「共有」の申告の対象外 |

## 根拠の確かめ方

release のマージ済みマニフェストで、権限を一覧する(`flutter build apk --release` の後):

```bash
grep -n "uses-permission" \
  build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml
```

`INTERNET` が出たら、上の回答は成り立たない。依存を足した PR で止めて見直す。
