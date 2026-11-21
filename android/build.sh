#!/bin/sh
# Builds build/lightswitch.apk with the bare SDK tools: no Gradle, no
# libraries, so the app stays tiny and starts fast.
set -eu
cd "$(dirname "$0")"
SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
BT="$SDK/build-tools/36.0.0"
JAR="$SDK/platforms/android-36/android.jar"
KEY="$HOME/.android/lightswitch.keystore"

rm -rf build && mkdir -p build/res build/classes build/dex
"$BT/aapt2" compile --dir res -o build/res/
"$BT/aapt2" link -I "$JAR" --manifest AndroidManifest.xml -o build/base.apk build/res/*.flat --java build/gen
javac -source 11 -target 11 -nowarn -Xlint:none -classpath "$JAR" -d build/classes $(find src build/gen -name '*.java') 2>&1 | grep -v "^warning\|^Note\|^1 warning" || true
"$BT/d8" --min-api 26 --release --lib "$JAR" --output build/dex $(find build/classes -name '*.class')
cp build/base.apk build/unsigned.apk
(cd build/dex && zip -q -j ../unsigned.apk classes.dex)
"$BT/zipalign" -f 4 build/unsigned.apk build/aligned.apk
[ -f "$KEY" ] || keytool -genkeypair -keystore "$KEY" -storepass lightswitch -keypass lightswitch \
    -alias lightswitch -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Lightswitch" >/dev/null 2>&1
"$BT/apksigner" sign --ks "$KEY" --ks-pass pass:lightswitch --out build/lightswitch.apk build/aligned.apk
ls -la build/lightswitch.apk
