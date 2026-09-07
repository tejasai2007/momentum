# Changes — getting "tickoff_clone" to build & run

Record of all configuration changes made to fix the Android build after
setting up the project on this machine (Ubuntu, Flutter 3.47.2, snap install).

## Project changes (in flutter_app/)

### 1. `android/local.properties` — NEW (required, was gitignored/missing)
Created with machine-specific paths:
```
sdk.dir=/home/agentranger/Android/Sdk
flutter.sdk=/home/agentranger/snap/flutter/common/flutter
flutter.versionName=1.0.0
flutter.versionCode=1
```
(`flutter.buildMode=debug` is auto-added by Flutter during builds.)

### 2. `android/gradle/wrapper/gradle-wrapper.properties` — MODIFIED
- Gradle `8.4.0` → `8.14` (Flutter 3.47 requires ≥ 8.14)

### 3. `android/build.gradle` — MODIFIED
- AGP `com.android.tools.build:gradle` `8.3.0` → `8.11.1` (Flutter requires ≥ 8.11.1)
- Kotlin `ext.kotlin_version` `1.9.22` → `2.2.20` (Flutter requires ≥ 2.2.20)

### 4. `android/settings.gradle` — MODIFIED
- AGP `com.android.application` `8.3.0` → `8.11.1`
- Kotlin `org.jetbrains.kotlin.android` `2.0.21` → `2.2.20`

### 5. `android/app/build.gradle` — MODIFIED
- `compileSdk 34` → `36` (plugin dependencies — app_links, image_picker,
  shared_preferences, etc. — require ≥ 36 for AAR metadata check)

## Machine-level changes (outside the repo)

### 6. Java 25 → JDK 17
- Bundled Android Studio JDK is Java 25, incompatible with Gradle 8.x.
- Downloaded portable Temurin JDK 17 to `~/.jdks/jdk-17.0.20.1+1/`
- Configured Flutter to use it: `flutter config --jdk-dir=/home/agentranger/.jdks/jdk-17.0.20.1+1`

### 7. Android SDK setup (`/home/agentranger/Android/Sdk`)
- Installed **cmdline-tools** (`sdkmanager`/`avdmanager`) — was missing
- Accepted all Android SDK licenses
- Installed system image `system-images;android-36;google_apis;x86_64`
- Created AVD **`tickoff_avd`** (Pixel 7, API 36)
- CMake 3.22.1 installed (auto, for plugin builds)

### 8. `~/.bashrc` — environment variables added
```
export ANDROID_HOME=/home/agentranger/Android/Sdk
export ANDROID_SDK_ROOT=/home/agentranger/Android/Sdk
export JAVA_HOME=/snap/android-studio/242/jbr/   # note: builds use JDK 17 via flutter config
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
```

### 9. Run / build
- `flutter pub get` (all dependencies installed)
- Build verified: `flutter build apk --debug` ✓
- APK installed + launched on device `V2303` (Android 15)
- Run args used:
  `--dart-define=SUPABASE_URL=https://txicualwxgmowzygzwtu.supabase.co
   --dart-define=SUPABASE_ANON_KEY=sb_publishable_layR7vy1PRklfKul6kEdnQ_VFRR62mP`

## Remaining warnings (non-blocking)
- Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20 → "support will soon be dropped",
  Flutter suggests Gradle ≥ 9.1.0, AGP ≥ 9.0.1, Kotlin ≥ 2.3.20 (skip for now —
  AGP 9 changes the Gradle DSL and may require further edits)
- `targetSdk` still 34 (intentional; compileSdk is what matters for building)