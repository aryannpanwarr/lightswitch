# Lightswitch for Android

Triple-tap the thin strip on the right edge of the screen, from any app, and
the quick editor drops in with the keyboard up (about 65 ms). Enter twice, or
double-tap anywhere, saves and closes. Back keeps the draft.

The app icon opens the notes as cards, two columns, like Keep. Tap a card to
edit it, mark it done, or delete it.

Notes are the same Markdown checklist as the desktop app, kept in the app's
private storage (`files/lightswitch.md`).

## Build and install

```sh
./build.sh                                  # build/lightswitch.apk, no Gradle
adb install -r build/lightswitch.apk
adb shell appops set app.lightswitch SYSTEM_ALERT_WINDOW allow   # or tap Allow in the app
adb shell dumpsys deviceidle whitelist +app.lightswitch          # keep the strip alive
```
