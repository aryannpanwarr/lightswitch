package app.lightswitch;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.text.TextUtils;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;

// What the app icon opens: every note as a card, two columns, like Keep.
// Tap a card to edit it; done and delete are in there too.
public final class NotesActivity extends Activity {
    private static final int INK = 0xFFE8E8EA, DIM = 0xFF7A7A80, CARD = 0xFF18181C, EDGE = 0xFF2A2A30, ACCENT = 0xFFFFD60A;

    private Notes notes;
    private LinearLayout left, right, setup;
    private TextView empty, toast;
    private EditText search;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable hideToast = () -> toast.setVisibility(View.GONE);

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        notes = new Notes(this);

        FrameLayout root = new FrameLayout(this);
        root.setFitsSystemWindows(true);

        ScrollView scroll = new ScrollView(this);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(14), dp(14), dp(14), dp(110));
        scroll.addView(page);
        root.addView(scroll);

        // Search
        search = field("Search your notes");
        search.setSingleLine(true);
        search.setBackground(rounded(0xFF17171B, 0, 24));
        search.setPadding(dp(20), dp(13), dp(20), dp(13));
        search.addTextChangedListener(new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int a, int b, int c) {}
            public void onTextChanged(CharSequence s, int a, int b, int c) { render(); }
            public void afterTextChanged(Editable s) {}
        });
        page.addView(search, new LinearLayout.LayoutParams(-1, -2));

        // Setup card, only until the edge tap is allowed
        setup = new LinearLayout(this);
        setup.setOrientation(LinearLayout.VERTICAL);
        setup.setPadding(dp(18), dp(16), dp(18), dp(16));
        setup.setBackground(rounded(0xFF22200F, 0xFF5C4F0A, 14));
        TextView setupText = text("Turn on triple-tap: allow Lightswitch to display over other apps. Then triple-tap anywhere on the screen, in any app.", 14, INK);
        setup.addView(setupText);
        TextView setupButton = text("Allow", 15, ACCENT);
        setupButton.setTypeface(Typeface.DEFAULT_BOLD);
        setupButton.setPadding(0, dp(12), 0, 0);
        setup.addView(setupButton);
        setup.setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:" + getPackageName()))));
        LinearLayout.LayoutParams setupParams = new LinearLayout.LayoutParams(-1, -2);
        setupParams.topMargin = dp(14);
        page.addView(setup, setupParams);

        // Take a note…
        EditText take = field("Take a note…");
        take.setBackground(rounded(CARD, EDGE, 12));
        take.setPadding(dp(18), dp(15), dp(18), dp(15));
        take.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        take.setImeOptions(EditorInfo.IME_ACTION_DONE);
        take.setOnEditorActionListener((v, action, event) -> {
            String t = take.getText().toString();
            if (!t.trim().isEmpty()) { notes.capture(t); take.setText(""); render(); }
            return true;
        });
        LinearLayout.LayoutParams takeParams = new LinearLayout.LayoutParams(-1, -2);
        takeParams.topMargin = dp(14);
        takeParams.bottomMargin = dp(16);
        page.addView(take, takeParams);

        // Two columns of cards
        LinearLayout grid = new LinearLayout(this);
        left = column();
        right = column();
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, -2, 1);
        lp.rightMargin = dp(5);
        LinearLayout.LayoutParams rp = new LinearLayout.LayoutParams(0, -2, 1);
        rp.leftMargin = dp(5);
        grid.addView(left, lp);
        grid.addView(right, rp);
        page.addView(grid);

        empty = text("Notes you dump appear here\n\nTriple-tap anywhere, in any app", 15, DIM);
        empty.setGravity(Gravity.CENTER);
        empty.setPadding(0, dp(80), 0, 0);
        page.addView(empty, new LinearLayout.LayoutParams(-1, -2));

        // New note button
        TextView fab = text("+", 30, 0xFF0E0E10);
        fab.setGravity(Gravity.CENTER);
        fab.setBackground(rounded(ACCENT, 0, 18));
        fab.setElevation(dp(6));
        fab.setOnClickListener(v -> startActivity(new Intent(this, CaptureActivity.class)));
        FrameLayout.LayoutParams fp = new FrameLayout.LayoutParams(dp(60), dp(60), Gravity.BOTTOM | Gravity.END);
        fp.setMargins(0, 0, dp(20), dp(24));
        root.addView(fab, fp);

        // Undo bar
        toast = text("", 14, INK);
        toast.setBackground(rounded(0xFF2A2A30, 0, 8));
        toast.setPadding(dp(18), dp(14), dp(18), dp(14));
        toast.setVisibility(View.GONE);
        toast.setOnClickListener(v -> { notes.undo(); toast.setVisibility(View.GONE); render(); });
        FrameLayout.LayoutParams tp = new FrameLayout.LayoutParams(-2, -2, Gravity.BOTTOM | Gravity.START);
        tp.setMargins(dp(16), 0, 0, dp(30));
        root.addView(toast, tp);

        setContentView(root);

        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1);
    }

    @Override
    protected void onResume() {
        super.onResume();
        TapService.appVisible = true;
        boolean allowed = Settings.canDrawOverlays(this);
        setup.setVisibility(allowed ? View.GONE : View.VISIBLE);
        TapService.start(this);
        render();
    }

    @Override
    protected void onPause() {
        super.onPause();
        TapService.appVisible = false;
    }

    private void render() {
        left.removeAllViews();
        right.removeAllViews();
        String q = search.getText().toString().trim().toLowerCase(Locale.ROOT);
        List<Notes.Item> items = notes.items();
        int shown = 0, leftWeight = 0, rightWeight = 0;
        for (Notes.Item item : items) {
            if (item.done) continue;
            if (!q.isEmpty() && !item.text.toLowerCase(Locale.ROOT).contains(q)) continue;
            // Masonry: each card goes to the shorter column.
            int weight = 3 + item.text.length() / 18;
            if (leftWeight <= rightWeight) { left.addView(card(item)); leftWeight += weight; }
            else { right.addView(card(item)); rightWeight += weight; }
            shown++;
        }
        empty.setVisibility(shown == 0 ? View.VISIBLE : View.GONE);
        empty.setText(q.isEmpty() ? "Notes you dump appear here\n\nTriple-tap anywhere, in any app" : "No matching notes");
    }

    private View card(Notes.Item item) {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(16), dp(14), dp(16), dp(12));
        card.setBackground(rounded(CARD, EDGE, 12));
        TextView body = text(item.text, 15, INK);
        body.setMaxLines(10);
        body.setEllipsize(TextUtils.TruncateAt.END);
        body.setLineSpacing(0, 1.1f);
        card.addView(body);
        TextView when = text(label(item.stamp), 11, 0xFF6A6A70);
        when.setPadding(0, dp(10), 0, 0);
        card.addView(when);
        card.setOnClickListener(v -> edit(item));
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(-1, -2);
        p.bottomMargin = dp(10);
        card.setLayoutParams(p);
        return card;
    }

    private void edit(Notes.Item item) {
        EditText editor = field("");
        editor.setText(item.text);
        editor.setSelection(editor.length());
        editor.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        editor.setBackground(null);
        editor.setPadding(dp(22), dp(18), dp(22), dp(8));
        editor.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        AlertDialog dialog = new AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
                .setView(editor)
                .setPositiveButton("Save", (d, w) -> {
                    if (!editor.getText().toString().equals(item.text)) { notes.edit(item, editor.getText().toString()); render(); }
                })
                .setNeutralButton("Delete", (d, w) -> { notes.remove(item); render(); say("Note deleted"); })
                .setNegativeButton("Done ✓", (d, w) -> { notes.setDone(item, true); render(); say("Marked done"); })
                .create();
        dialog.getWindow().setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE);
        dialog.show();
    }

    private void say(String message) {
        toast.setText(message + "     UNDO");
        toast.setVisibility(View.VISIBLE);
        handler.removeCallbacks(hideToast);
        handler.postDelayed(hideToast, 4000);
    }

    private static final SimpleDateFormat STAMP = new SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US);

    private String label(String stamp) {
        try {
            Date d = STAMP.parse(stamp);
            String day = new SimpleDateFormat("yyyy-MM-dd", Locale.US).format(d);
            String today = new SimpleDateFormat("yyyy-MM-dd", Locale.US).format(new Date());
            String yesterday = new SimpleDateFormat("yyyy-MM-dd", Locale.US).format(new Date(System.currentTimeMillis() - 86400000L));
            String time = android.text.format.DateFormat.getTimeFormat(this).format(d);
            if (day.equals(today)) return "Today · " + time;
            if (day.equals(yesterday)) return "Yesterday · " + time;
            return new SimpleDateFormat("EEE, d MMM", Locale.getDefault()).format(d) + " · " + time;
        } catch (Exception e) {
            return stamp;
        }
    }

    private LinearLayout column() {
        LinearLayout c = new LinearLayout(this);
        c.setOrientation(LinearLayout.VERTICAL);
        return c;
    }

    private EditText field(String hint) {
        EditText e = new EditText(this);
        e.setHint(hint);
        e.setTextColor(INK);
        e.setHintTextColor(DIM);
        e.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        return e;
    }

    private TextView text(String s, int sp, int color) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, sp);
        t.setTextColor(color);
        return t;
    }

    private GradientDrawable rounded(int fill, int stroke, int radiusDp) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(fill);
        g.setCornerRadius(dp(radiusDp));
        if (stroke != 0) g.setStroke(dp(1), stroke);
        return g;
    }

    private int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }
}
