package app.lightswitch;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.util.TypedValue;
import android.view.GestureDetector;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

// The quick editor: drops over whatever is open with the keyboard already up.
// Enter starts the next note; Enter twice, or a double tap anywhere, saves
// and closes. Back or leaving keeps the draft.
public final class CaptureActivity extends Activity {
    private Notes notes;
    private EditText input;
    private boolean finished;
    private GestureDetector taps;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        notes = new Notes(this);
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE
                | WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);

        FrameLayout root = new FrameLayout(this);
        root.setOnClickListener(v -> {});  // Taps outside the card don't dismiss it by accident.

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(20), dp(18), dp(20), dp(14));
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(0xFF18181C);
        bg.setCornerRadius(dp(18));
        bg.setStroke(dp(1), 0xFF2A2A30);
        card.setBackground(bg);
        FrameLayout.LayoutParams cardParams = new FrameLayout.LayoutParams(-1, -2, Gravity.TOP);
        cardParams.setMargins(dp(12), dp(48), dp(12), 0);
        root.addView(card, cardParams);

        input = new EditText(this);
        input.setBackground(null);
        input.setPadding(0, 0, 0, 0);
        input.setTextColor(0xFFECECEC);
        input.setHintTextColor(0xFF5A5A60);
        input.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
        input.setHint("Dump it. Double-tap to save.");
        input.setMinLines(3);
        input.setGravity(Gravity.TOP | Gravity.START);
        input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE
                | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        input.setText(notes.draft());
        input.setSelection(input.length());
        card.addView(input, new LinearLayout.LayoutParams(-1, -2));

        LinearLayout footer = new LinearLayout(this);
        footer.setGravity(Gravity.CENTER_VERTICAL);
        footer.setPadding(0, dp(12), 0, 0);
        TextView hint = new TextView(this);
        hint.setText("Enter twice or double-tap to save");
        hint.setTextColor(0xFF5A5A60);
        hint.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        footer.addView(hint, new LinearLayout.LayoutParams(0, -2, 1));
        TextView all = new TextView(this);
        int open = notes.openCount();
        all.setText(open > 0 ? open + " notes  →" : "Notes  →");
        all.setTextColor(0xFFFFD60A);
        all.setTypeface(Typeface.DEFAULT_BOLD);
        all.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        all.setPadding(dp(12), dp(8), 0, dp(8));
        all.setOnClickListener(v -> {
            release();
            startActivity(new Intent(this, NotesActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        });
        footer.addView(all);
        card.addView(footer);

        setContentView(root);

        // A newline typed right after another newline (or at the very start)
        // is the second Enter: save everything.
        input.addTextChangedListener(new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                if (count != 1 || before != 0 || s.charAt(start) != '\n') return;
                if (start == 0 || s.charAt(start - 1) == '\n') input.post(() -> commit());
            }
            public void afterTextChanged(Editable s) {}
        });

        taps = new GestureDetector(this, new GestureDetector.SimpleOnGestureListener() {
            @Override public boolean onDoubleTap(MotionEvent e) { commit(); return true; }
        });

        input.requestFocus();
    }

    // Watch every touch for a double tap, then let it through as usual.
    @Override
    public boolean dispatchTouchEvent(MotionEvent event) {
        if (taps != null && taps.onTouchEvent(event)) return true;
        return super.dispatchTouchEvent(event);
    }

    private void commit() {
        if (finished) return;
        String text = input.getText().toString();
        if (!text.trim().isEmpty()) {
            if (notes.capture(text) < 0) { input.setError("Couldn't save"); return; }
            input.performHapticFeedback(HapticFeedbackConstants.CONFIRM);
        }
        notes.setDraft("");
        finished = true;
        close();
    }

    private void release() {
        if (finished) return;
        notes.setDraft(input.getText().toString());
        finished = true;
        close();
    }

    private void close() {
        finish();
        overridePendingTransition(0, 0);
    }

    @Override public void onBackPressed() { release(); }

    // Switching apps or turning the screen off counts as letting go.
    @Override protected void onResume() {
        super.onResume();
        TapService.appVisible = true;
    }

    @Override protected void onPause() {
        super.onPause();
        TapService.appVisible = false;
        if (!finished) release();
    }

    private int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }
}
