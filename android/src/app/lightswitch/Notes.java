package app.lightswitch;

import android.content.Context;
import android.content.SharedPreferences;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

// The same plain Markdown file as the desktop app, one checklist item per note:
//   - [ ] 2026-11-22 14:03 · call the bank
// Lines the app did not write are kept as they are.
final class Notes {
    static final class Item {
        final int line;
        final boolean done;
        final String stamp;
        final String text;
        Item(int line, boolean done, String stamp, String text) {
            this.line = line; this.done = done; this.stamp = stamp; this.text = text;
        }
    }

    private static final Pattern ITEM = Pattern.compile("^- \\[( |x|X)\\] (\\d{4}-\\d\\d-\\d\\d \\d\\d:\\d\\d) · (.*)$");
    private static final SimpleDateFormat STAMP = new SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US);

    private final File file;
    private final SharedPreferences prefs;
    private List<String> undo;

    Notes(Context context) {
        file = new File(context.getFilesDir(), "lightswitch.md");
        prefs = context.getSharedPreferences("lightswitch", Context.MODE_PRIVATE);
    }

    String draft() { return prefs.getString("draft", ""); }
    void setDraft(String draft) { prefs.edit().putString("draft", draft).apply(); }

    List<String> lines() {
        try {
            if (!file.exists()) return new ArrayList<>();
            String all = new String(Files.readAllBytes(file.toPath()), StandardCharsets.UTF_8);
            List<String> lines = new ArrayList<>(Arrays.asList(all.split("\n", -1)));
            if (!lines.isEmpty() && lines.get(lines.size() - 1).isEmpty()) lines.remove(lines.size() - 1);
            return lines;
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    // Written beside the file and renamed over it, so a crash never leaves
    // half a file.
    private boolean write(List<String> lines) {
        File tmp = new File(file.getPath() + ".tmp");
        try (FileOutputStream out = new FileOutputStream(tmp)) {
            out.write((String.join("\n", lines) + "\n").getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
        } catch (Exception e) {
            return false;
        }
        return tmp.renameTo(file);
    }

    // Newest first.
    List<Item> items() {
        List<String> lines = lines();
        List<Item> items = new ArrayList<>();
        for (int i = lines.size() - 1; i >= 0; i--) {
            Matcher m = ITEM.matcher(lines.get(i));
            if (m.matches()) items.add(new Item(i, !m.group(1).equals(" "), m.group(2), m.group(3)));
        }
        return items;
    }

    int openCount() {
        int n = 0;
        for (Item item : items()) if (!item.done) n++;
        return n;
    }

    // Every non-empty line becomes its own note. Returns how many were saved.
    int capture(String text) {
        String stamp = STAMP.format(new Date());
        List<String> lines = lines();
        if (lines.isEmpty()) { lines.add("# Lightswitch"); lines.add(""); }
        int saved = 0;
        for (String line : text.split("\n")) {
            String t = line.trim();
            if (t.isEmpty()) continue;
            lines.add("- [ ] " + stamp + " · " + t);
            saved++;
        }
        if (saved == 0) return 0;
        return write(lines) ? saved : -1;
    }

    private boolean change(int line, String replacement) {
        List<String> lines = lines();
        if (line < 0 || line >= lines.size() || !ITEM.matcher(lines.get(line)).matches()) return false;
        List<String> before = new ArrayList<>(lines);
        if (replacement == null) lines.remove(line); else lines.set(line, replacement);
        if (!write(lines)) return false;
        undo = before;
        return true;
    }

    boolean setDone(Item item, boolean done) {
        return change(item.line, "- [" + (done ? "x" : " ") + "] " + item.stamp + " · " + item.text);
    }

    boolean edit(Item item, String text) {
        String t = text.replace('\n', ' ').trim();
        if (t.isEmpty()) return remove(item);
        return change(item.line, "- [" + (item.done ? "x" : " ") + "] " + item.stamp + " · " + t);
    }

    boolean remove(Item item) { return change(item.line, null); }

    boolean undo() {
        if (undo == null) return false;
        boolean ok = write(undo);
        undo = null;
        return ok;
    }
}
