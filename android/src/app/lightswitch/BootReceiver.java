package app.lightswitch;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

// Brings the edge strip back after a reboot or an app update.
public final class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        TapService.start(context);
    }
}
