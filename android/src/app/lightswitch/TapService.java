package app.lightswitch;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.SystemClock;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.provider.Settings;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;

// Triple-tap anywhere on the screen, in any app, opens the quick editor.
//
// Android never shows an app where another app is touched, but a window that
// asks to "watch outside touches" is told *that* a finger went down somewhere
// else (with the position blanked). That is enough to count taps without
// blocking a single one: the window is 1 pixel and passes everything through.
//
// Guards against false triggers, since a touch-down is all we see:
//  - exactly three, each within TAP_GAP_MS of the last, then QUIET_MS of
//    nothing (typing and flicking keep going, so they never pause on three);
//  - never while a keyboard is up (KeyboardWatch), or while Lightswitch
//    itself is on screen.
public final class TapService extends Service {
    private static final String CHANNEL = "edge";
    private static final long TAP_GAP_MS = 320;
    private static final long QUIET_MS = 260;

    static volatile boolean appVisible;

    private WindowManager windows;
    private View watcher;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private int taps;
    private long lastTap;
    private final Runnable fire = this::open;

    static void start(Context context) {
        if (!Settings.canDrawOverlays(context)) return;
        context.startForegroundService(new Intent(context, TapService.class));
    }

    @Override
    public void onCreate() {
        super.onCreate();
        NotificationManager nm = getSystemService(NotificationManager.class);
        NotificationChannel channel = new NotificationChannel(CHANNEL, "Triple tap", NotificationManager.IMPORTANCE_MIN);
        channel.setShowBadge(false);
        nm.createNotificationChannel(channel);

        // Tapping the notification is a second way in.
        PendingIntent open = PendingIntent.getActivity(this, 0,
                new Intent(this, CaptureActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE);
        Notification notification = new Notification.Builder(this, CHANNEL)
                .setSmallIcon(android.R.drawable.ic_menu_edit)
                .setContentTitle("Lightswitch")
                .setContentText("Triple-tap anywhere to dump a thought")
                .setContentIntent(open)
                .setOngoing(true)
                .build();
        if (Build.VERSION.SDK_INT >= 34)
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        else
            startForeground(1, notification);

        addWatcher();
    }

    private void addWatcher() {
        if (!Settings.canDrawOverlays(this)) { stopSelf(); return; }
        windows = getSystemService(WindowManager.class);
        watcher = new View(this);
        WindowManager.LayoutParams params = new WindowManager.LayoutParams(1, 1,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                        | WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                PixelFormat.TRANSLUCENT);
        params.gravity = Gravity.TOP | Gravity.START;
        watcher.setOnTouchListener((v, e) -> {
            if (e.getActionMasked() == MotionEvent.ACTION_OUTSIDE) onTouchDown();
            return false;
        });
        windows.addView(watcher, params);
    }

    private void onTouchDown() {
        handler.removeCallbacks(fire);
        if (appVisible || KeyboardWatch.keyboardVisible) { taps = 0; return; }
        long now = SystemClock.uptimeMillis();
        taps = now - lastTap <= TAP_GAP_MS ? taps + 1 : 1;
        lastTap = now;
        if (taps == 3) handler.postDelayed(fire, QUIET_MS);
    }

    private void open() {
        taps = 0;
        if (appVisible || KeyboardWatch.keyboardVisible) return;
        Vibrator vibrator = getSystemService(Vibrator.class);
        if (vibrator != null) vibrator.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK));
        startActivity(new Intent(this, CaptureActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_NO_ANIMATION));
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        if (watcher != null && windows != null) windows.removeView(watcher);
        super.onDestroy();
    }

    @Override public IBinder onBind(Intent intent) { return null; }
}
