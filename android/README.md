# Lightswitch for Android

Triple-tap anywhere on the screen, in any app, and the quick editor drops in
with the keyboard up (about 65 ms). The taps still reach the app underneath,
so tap somewhere empty. It never fires while a keyboard is up (a small
accessibility service checks only that) or on four or more taps. Enter twice, or
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
adb shell dumpsys deviceidle whitelist +app.lightswitch          # keep the tap watcher alive
# typing guard: append app.lightswitch/app.lightswitch.KeyboardWatch to secure enabled_accessibility_services
```
