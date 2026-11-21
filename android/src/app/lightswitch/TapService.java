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
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.IBinder;
import android.os.SystemClock;
import android.provider.Settings;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.WindowManager;

// Keeps a thin strip on the right edge of the screen, over every app.
// Three quick taps on it open the quick editor. It runs as a foreground
// service so Android keeps it (and the warm process) alive, which is also
// what makes the editor open instantly.
public final class TapService extends Service {
    private static final String CHANNEL = "edge";
    private static final long TAP_GAP_MS = 400;

    private WindowManager windows;
    private View strip;
    private int taps;
    private long lastTap;
    private float downX, downY;

    static void start(Context context) {
        if (!Settings.canDrawOverlays(context)) return;
        context.startForegroundService(new Intent(context, TapService.class));
    }

    @Override
    public void onCreate() {
        super.onCreate();
        NotificationManager nm = getSystemService(NotificationManager.class);
        NotificationChannel channel = new NotificationChannel(CHANNEL, "Edge tap", NotificationManager.IMPORTANCE_MIN);
        channel.setShowBadge(false);
        nm.createNotificationChannel(channel);

        // Tapping the notification is a second way in.
        PendingIntent open = PendingIntent.getActivity(this, 0,
                new Intent(this, CaptureActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE);
        Notification notification = new Notification.Builder(this, CHANNEL)
                .setSmallIcon(android.R.drawable.ic_menu_edit)
                .setContentTitle("Lightswitch")
                .setContentText("Triple-tap the right edge to dump a thought")
                .setContentIntent(open)
                .setOngoing(true)
                .build();
        if (Build.VERSION.SDK_INT >= 34)
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        else
            startForeground(1, notification);

        addStrip();
    }

    private void addStrip() {
        if (!Settings.canDrawOverlays(this)) { stopSelf(); return; }
        windows = getSystemService(WindowManager.class);
        float density = getResources().getDisplayMetrics().density;
        int height = getResources().getDisplayMetrics().heightPixels;

        strip = new View(this);
        // A faint line so you can find it; the touch area is wider than what shows.
        GradientDrawable line = new GradientDrawable();
        line.setColor(0x33FFD60A);
        line.setCornerRadius(4 * density);
        strip.setBackground(new android.graphics.drawable.InsetDrawable(line, Math.round(14 * density), 0, Math.round(2 * density), 0));

        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                Math.round(20 * density), Math.round(height * 0.28f),
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT);
        params.gravity = Gravity.END | Gravity.CENTER_VERTICAL;

        final int slop = ViewConfiguration.get(this).getScaledTouchSlop();
        strip.setOnTouchListener((v, e) -> {
            switch (e.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    downX = e.getRawX(); downY = e.getRawY();
                    return true;
                case MotionEvent.ACTION_UP:
                    if (Math.abs(e.getRawX() - downX) > slop * 2 || Math.abs(e.getRawY() - downY) > slop * 2) {
                        taps = 0;
                        return true;
                    }
                    long now = SystemClock.uptimeMillis();
                    taps = now - lastTap <= TAP_GAP_MS ? taps + 1 : 1;
                    lastTap = now;
                    if (taps >= 3) {
                        taps = 0;
                        v.performHapticFeedback(HapticFeedbackConstants.CONFIRM);
                        startActivity(new Intent(this, CaptureActivity.class)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_NO_ANIMATION));
                    }
                    return true;
            }
            return true;
        });
        windows.addView(strip, params);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        if (strip != null && windows != null) windows.removeView(strip);
        super.onDestroy();
    }

    @Override public IBinder onBind(Intent intent) { return null; }
}
