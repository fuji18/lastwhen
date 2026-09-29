# 設計書: Android リリースビルドの整備(Issue #72)

<!-- status: ready -->

> 決定と理由は `requirements.md`。ここには実装者が手を動かす部分(`android/app/build.gradle.kts`)だけを書く。
> docs(development-guidelines)は司令塔が書く。鍵の作成と実機確認は人手の作業。

## 1. `android/app/build.gradle.kts` の変更

### 1.1 ファイル先頭(`plugins { ... }` の**前**)に import を足す

```kotlin
import java.io.FileInputStream
import java.util.Properties
```

### 1.2 `plugins { ... }` と `android { ... }` の間に、`key.properties` の読み込みを置く

```kotlin
// アップロード鍵の設定。鍵と key.properties はリポジトリの外で管理する
// (docs/development-guidelines.md「リリースビルド(Android)」)。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
```

### 1.3 `android { ... }` の中、`defaultConfig { ... }` と `buildTypes { ... }` の間に `signingConfigs` を置く

```kotlin
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }
```

### 1.4 `buildTypes.release` を置き換える

今の `release { ... }` ブロック(TODO コメント 2 行と `signingConfig = signingConfigs.getByName("debug")`)を、次にまるごと差し替える。

```kotlin
        release {
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    // Play は debug 署名のアップロードを拒否するので、誤って出すことはない。
                    logger.warn("android/key.properties が無いため、release を debug 鍵で署名します")
                    signingConfigs.getByName("debug")
                }
        }
```

- 他の行(`namespace` / `applicationId` / `minSdk` / `targetSdk` / `versionCode` など)は触らない
- `minifyEnabled` / `proguardFiles` は足さない(Flutter の既定に任せる)

## 2. 検証

1. `test -f android/key.properties` が偽であること(無い状態で検証する)
2. `flutter build apk --debug` が成功する
3. `flutter build apk --release` が成功し、ログに `android/key.properties が無いため` の警告が出る
4. `git check-ignore -v android/key.properties android/app/upload-keystore.jks` の 2 行とも無視対象と出る
5. Kotlin スクリプトは Dart ではないので format / analyze の対象外。`flutter test` は CI が回す

結果は `tasklist.md` の末尾に書く。

## 3. エラー時

- Gradle の構文・型のエラーで 2 回直して通らなければ止めて報告する
- `key.properties` を作ってテストしない(鍵を作るのは人手の作業)
