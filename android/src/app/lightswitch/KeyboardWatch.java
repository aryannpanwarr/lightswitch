package app.lightswitch;

import android.accessibilityservice.AccessibilityService;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityWindowInfo;

// Only tells the tap counter whether a keyboard is on screen, so fast typing
// never opens the editor. It reads window types, never their content.
public final class KeyboardWatch extends AccessibilityService {
    static volatile boolean keyboardVisible;

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        boolean ime = false;
        for (AccessibilityWindowInfo w : getWindows())
            if (w.getType() == AccessibilityWindowInfo.TYPE_INPUT_METHOD) { ime = true; break; }
        keyboardVisible = ime;
    }

    @Override public void onInterrupt() {}

    @Override public void onDestroy() {
        keyboardVisible = false;
        super.onDestroy();
    }
}
