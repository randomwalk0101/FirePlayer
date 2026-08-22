package com.fireplace.fireplayer;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.graphics.Color;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.OpenableColumns;
import android.database.Cursor;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class MainActivity extends Activity {
    private static final int REQ_AUDIO = 1001;
    private static final int REQ_SRT = 1002;

    private final List<Track> playlist = new ArrayList<>();
    private final Map<String, Uri> subtitleByStem = new HashMap<>();
    private final List<SubtitleItem> subtitles = new ArrayList<>();
    private final Handler handler = new Handler(Looper.getMainLooper());

    private MediaPlayer player;
    private int currentTrackIndex = -1;
    private int currentSubtitleIndex = -1;
    private float playbackSpeed = 1.0f;
    private int subtitleSize = 54;
    private boolean showingPlaylist = true;

    private LinearLayout root;
    private LinearLayout playlistPane;
    private LinearLayout playlistList;
    private TextView englishText;
    private TextView translationText;
    private TextView timeText;
    private TextView fontSizeText;
    private SeekBar seekBar;
    private Button playButton;
    private Button togglePlaylistButton;
    private Button speedButton;
    private final Runnable ticker = new Runnable() {
        @Override public void run() {
            updateProgress();
            handler.postDelayed(this, 200);
        }
    };

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
        buildUi();
        handler.post(ticker);
    }

    private void buildUi() {
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.HORIZONTAL);
        root.setBackgroundColor(Color.rgb(16, 16, 16));
        setContentView(root);

        playlistPane = new LinearLayout(this);
        playlistPane.setOrientation(LinearLayout.VERTICAL);
        playlistPane.setPadding(dp(10), dp(12), dp(10), dp(10));
        playlistPane.setBackgroundColor(Color.rgb(25, 25, 25));
        root.addView(playlistPane, new LinearLayout.LayoutParams(dp(290), LinearLayout.LayoutParams.MATCH_PARENT));

        LinearLayout playlistHeader = row();
        Button addAudio = button("加入音频");
        Button addSrt = button("加入字幕");
        Button clear = button("清空");
        playlistHeader.addView(addAudio, weightParam());
        playlistHeader.addView(addSrt, weightParam());
        playlistHeader.addView(clear, weightParam());
        playlistPane.addView(playlistHeader);

        ScrollView scrollView = new ScrollView(this);
        playlistList = new LinearLayout(this);
        playlistList.setOrientation(LinearLayout.VERTICAL);
        scrollView.addView(playlistList);
        playlistPane.addView(scrollView, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1));

        LinearLayout playerPane = new LinearLayout(this);
        playerPane.setOrientation(LinearLayout.VERTICAL);
        playerPane.setPadding(dp(22), dp(20), dp(22), dp(14));
        root.addView(playerPane, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1));

        LinearLayout subtitleStage = new LinearLayout(this);
        subtitleStage.setOrientation(LinearLayout.VERTICAL);
        subtitleStage.setGravity(Gravity.CENTER);
        subtitleStage.setClickable(true);
        subtitleStage.setOnClickListener(v -> togglePlay());
        playerPane.addView(subtitleStage, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1));

        englishText = new TextView(this);
        englishText.setText("打开音频后，将在这里显示当前字幕");
        englishText.setTextColor(Color.rgb(255, 232, 92));
        englishText.setTextSize(subtitleSize);
        englishText.setGravity(Gravity.CENTER);
        englishText.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        englishText.setMaxLines(4);
        englishText.setEllipsize(TextUtils.TruncateAt.END);
        subtitleStage.addView(englishText, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        translationText = new TextView(this);
        translationText.setTextColor(Color.WHITE);
        translationText.setAlpha(0.9f);
        translationText.setTextSize(Math.max(18, subtitleSize * 0.58f));
        translationText.setGravity(Gravity.CENTER);
        translationText.setPadding(0, dp(18), 0, 0);
        translationText.setMaxLines(2);
        subtitleStage.addView(translationText, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        LinearLayout seekRow = row();
        seekBar = new SeekBar(this);
        timeText = label("00:00 / 00:00", 14, Color.LTGRAY);
        seekRow.addView(seekBar, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));
        seekRow.addView(timeText, new LinearLayout.LayoutParams(dp(132), LinearLayout.LayoutParams.WRAP_CONTENT));
        playerPane.addView(seekRow);

        LinearLayout controls1 = centeredRow();
        Button previousTrack = button("上一首");
        playButton = button("播放");
        Button nextTrack = button("下一首");
        controls1.addView(previousTrack, fixedButtonParam());
        controls1.addView(playButton, fixedButtonParam());
        controls1.addView(nextTrack, fixedButtonParam());
        playerPane.addView(controls1);

        LinearLayout controls2 = centeredRow();
        togglePlaylistButton = button("隐藏清单");
        Button previousSentence = button("上一句");
        Button nextSentence = button("下一句");
        Button smaller = button("A-");
        fontSizeText = label("字号 " + subtitleSize, 14, Color.WHITE);
        Button larger = button("A+");
        speedButton = button("1.0x");
        controls2.addView(togglePlaylistButton, fixedButtonParam());
        controls2.addView(previousSentence, fixedButtonParam());
        controls2.addView(nextSentence, fixedButtonParam());
        controls2.addView(smaller, fixedButtonParam());
        controls2.addView(fontSizeText, new LinearLayout.LayoutParams(dp(90), LinearLayout.LayoutParams.WRAP_CONTENT));
        controls2.addView(larger, fixedButtonParam());
        controls2.addView(speedButton, fixedButtonParam());
        playerPane.addView(controls2);

        addAudio.setOnClickListener(v -> openAudioPicker());
        addSrt.setOnClickListener(v -> openSubtitlePicker());
        clear.setOnClickListener(v -> clearPlaylist());
        previousTrack.setOnClickListener(v -> previousTrack());
        playButton.setOnClickListener(v -> togglePlay());
        nextTrack.setOnClickListener(v -> nextTrack());
        previousSentence.setOnClickListener(v -> previousSubtitle());
        nextSentence.setOnClickListener(v -> nextSubtitle());
        smaller.setOnClickListener(v -> changeSubtitleSize(-4));
        larger.setOnClickListener(v -> changeSubtitleSize(4));
        speedButton.setOnClickListener(v -> cycleSpeed());
        togglePlaylistButton.setOnClickListener(v -> togglePlaylist());
        seekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                if (fromUser && player != null) {
                    player.seekTo(progress);
                    updateSubtitle(true);
                }
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });
        renderPlaylist();
    }

    private void openAudioPicker() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.setType("audio/*");
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        startActivityForResult(intent, REQ_AUDIO);
    }

    private void openSubtitlePicker() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.setType("*/*");
        intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"application/x-subrip", "text/plain", "application/octet-stream"});
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        startActivityForResult(intent, REQ_SRT);
    }

    @Override protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode != RESULT_OK || data == null) return;
        List<Uri> uris = collectUris(data);
        for (Uri uri : uris) {
            try {
                getContentResolver().takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            } catch (SecurityException ignored) {}
            String name = displayName(uri);
            if (requestCode == REQ_AUDIO) {
                playlist.add(new Track(name, uri));
            } else if (requestCode == REQ_SRT && name.toLowerCase(Locale.ROOT).endsWith(".srt")) {
                subtitleByStem.put(normalizedStem(stem(name)), uri);
            }
        }
        if (requestCode == REQ_AUDIO && currentTrackIndex < 0 && !playlist.isEmpty()) loadTrack(0, false);
        if (requestCode == REQ_SRT && currentTrackIndex >= 0) loadSubtitlesFor(playlist.get(currentTrackIndex));
        renderPlaylist();
    }

    private List<Uri> collectUris(Intent data) {
        List<Uri> result = new ArrayList<>();
        if (data.getClipData() != null) {
            for (int i = 0; i < data.getClipData().getItemCount(); i++) result.add(data.getClipData().getItemAt(i).getUri());
        } else if (data.getData() != null) {
            result.add(data.getData());
        }
        return result;
    }

    private void loadTrack(int index, boolean autoplay) {
        if (index < 0 || index >= playlist.size()) return;
        releasePlayer();
        currentTrackIndex = index;
        currentSubtitleIndex = -1;
        Track track = playlist.get(index);
        try {
            player = new MediaPlayer();
            player.setDataSource(this, track.uri);
            player.setOnPreparedListener(mp -> {
                seekBar.setMax(mp.getDuration());
                applySpeed();
                if (autoplay) mp.start();
                updateButtons();
                updateProgress();
            });
            player.setOnCompletionListener(mp -> {
                if (currentTrackIndex + 1 < playlist.size()) nextTrack();
                else {
                    mp.seekTo(0);
                    updateButtons();
                }
            });
            player.prepareAsync();
            loadSubtitlesFor(track);
        } catch (Exception e) {
            Toast.makeText(this, "无法播放：" + e.getMessage(), Toast.LENGTH_LONG).show();
        }
        renderPlaylist();
    }

    private void loadSubtitlesFor(Track track) {
        subtitles.clear();
        currentSubtitleIndex = -1;
        Uri subtitleUri = subtitleByStem.get(normalizedStem(stem(track.name)));
        if (subtitleUri == null) {
            setSubtitleText("未找到同名 SRT 字幕\n请点“加入字幕”选择字幕文件", "");
            return;
        }
        try {
            subtitles.addAll(parseSrt(readText(subtitleUri)));
            updateSubtitle(true);
        } catch (Exception e) {
            setSubtitleText("字幕读取失败", e.getMessage());
        }
    }

    private List<SubtitleItem> parseSrt(String content) {
        String normalized = content.replace("\r\n", "\n").replace("\r", "\n");
        String[] blocks = normalized.split("\\n\\s*\\n");
        List<SubtitleItem> result = new ArrayList<>();
        for (String block : blocks) {
            String[] rawLines = block.split("\\n");
            List<String> lines = new ArrayList<>();
            for (String line : rawLines) {
                String clean = line.trim();
                if (!clean.isEmpty()) lines.add(clean);
            }
            if (lines.size() < 2) continue;
            int cursor = lines.get(0).matches("\\d+") ? 1 : 0;
            if (cursor >= lines.size() || !lines.get(cursor).contains("-->")) continue;
            String[] parts = lines.get(cursor).split("-->");
            if (parts.length != 2) continue;
            long start = parseSrtTime(parts[0]);
            long end = parseSrtTime(parts[1]);
            cursor++;
            StringBuilder text = new StringBuilder();
            while (cursor < lines.size()) {
                if (text.length() > 0) text.append('\n');
                text.append(lines.get(cursor).replaceAll("<[^>]+>", ""));
                cursor++;
            }
            if (start >= 0 && end >= 0 && text.length() > 0) result.add(new SubtitleItem(start, end, text.toString()));
        }
        Collections.sort(result, Comparator.comparingLong(item -> item.startMs));
        return result;
    }

    private long parseSrtTime(String raw) {
        String[] hms = raw.trim().replace(",", ".").split(":");
        if (hms.length != 3) return -1;
        try {
            double seconds = Double.parseDouble(hms[2]);
            return (long) ((Integer.parseInt(hms[0]) * 3600 + Integer.parseInt(hms[1]) * 60 + seconds) * 1000);
        } catch (NumberFormatException e) {
            return -1;
        }
    }

    private void updateSubtitle(boolean force) {
        if (player == null || subtitles.isEmpty()) return;
        int position = player.getCurrentPosition();
        int found = -1;
        for (int i = 0; i < subtitles.size(); i++) {
            SubtitleItem item = subtitles.get(i);
            if (item.startMs <= position && position <= item.endMs) {
                found = i;
                break;
            }
            if (item.startMs <= position) found = i;
        }
        if (found < 0) found = 0;
        if (!force && found == currentSubtitleIndex) return;
        currentSubtitleIndex = found;
        String[] parts = splitBilingual(subtitles.get(found).text);
        setSubtitleText(parts[0], parts[1]);
    }

    private String[] splitBilingual(String text) {
        String[] lines = text.replace("\\N", "\n").split("\\n");
        StringBuilder english = new StringBuilder();
        StringBuilder translation = new StringBuilder();
        for (String line : lines) {
            String clean = line.trim();
            if (clean.isEmpty()) continue;
            StringBuilder target = containsCjk(clean) ? translation : english;
            if (target.length() > 0) target.append('\n');
            target.append(clean);
        }
        if (english.length() == 0) english.append(text.trim());
        return new String[]{english.toString(), translation.toString()};
    }

    private boolean containsCjk(String text) {
        for (int i = 0; i < text.length(); i++) {
            Character.UnicodeBlock block = Character.UnicodeBlock.of(text.charAt(i));
            if (block == Character.UnicodeBlock.CJK_UNIFIED_IDEOGRAPHS ||
                block == Character.UnicodeBlock.CJK_COMPATIBILITY_IDEOGRAPHS ||
                block == Character.UnicodeBlock.HIRAGANA ||
                block == Character.UnicodeBlock.KATAKANA ||
                block == Character.UnicodeBlock.HANGUL_SYLLABLES) return true;
        }
        return false;
    }

    private void setSubtitleText(String english, String translation) {
        englishText.setText(english == null ? "" : english);
        translationText.setText(translation == null ? "" : translation);
    }

    private void updateProgress() {
        if (player == null) return;
        seekBar.setProgress(player.getCurrentPosition());
        timeText.setText(formatTime(player.getCurrentPosition()) + " / " + formatTime(player.getDuration()));
        updateSubtitle(false);
        updateButtons();
    }

    private void togglePlay() {
        if (player == null) return;
        if (player.isPlaying()) player.pause();
        else player.start();
        updateButtons();
    }

    private void previousTrack() {
        if (playlist.isEmpty()) return;
        loadTrack(currentTrackIndex > 0 ? currentTrackIndex - 1 : playlist.size() - 1, true);
    }

    private void nextTrack() {
        if (playlist.isEmpty()) return;
        loadTrack(currentTrackIndex + 1 < playlist.size() ? currentTrackIndex + 1 : 0, true);
    }

    private void previousSubtitle() {
        if (player == null || subtitles.isEmpty()) return;
        currentSubtitleIndex = Math.max(0, currentSubtitleIndex - 1);
        player.seekTo((int) subtitles.get(currentSubtitleIndex).startMs + 10);
        updateSubtitle(true);
    }

    private void nextSubtitle() {
        if (player == null || subtitles.isEmpty()) return;
        currentSubtitleIndex = Math.min(subtitles.size() - 1, Math.max(0, currentSubtitleIndex + 1));
        player.seekTo((int) subtitles.get(currentSubtitleIndex).startMs + 10);
        updateSubtitle(true);
    }

    private void changeSubtitleSize(int delta) {
        subtitleSize = Math.max(24, Math.min(96, subtitleSize + delta));
        englishText.setTextSize(subtitleSize);
        translationText.setTextSize(Math.max(18, subtitleSize * 0.58f));
        fontSizeText.setText("字号 " + subtitleSize);
    }

    private void cycleSpeed() {
        float[] speeds = new float[]{0.75f, 0.9f, 1.0f, 1.1f, 1.25f, 1.5f};
        int index = 0;
        for (int i = 0; i < speeds.length; i++) if (Math.abs(speeds[i] - playbackSpeed) < 0.01f) index = i;
        playbackSpeed = speeds[(index + 1) % speeds.length];
        speedButton.setText(String.format(Locale.US, "%.2fx", playbackSpeed).replace(".00", ".0"));
        applySpeed();
    }

    private void applySpeed() {
        if (player == null || android.os.Build.VERSION.SDK_INT < 23) return;
        try {
            player.setPlaybackParams(player.getPlaybackParams().setSpeed(playbackSpeed));
        } catch (Exception ignored) {}
    }

    private void togglePlaylist() {
        showingPlaylist = !showingPlaylist;
        playlistPane.setVisibility(showingPlaylist ? View.VISIBLE : View.GONE);
        togglePlaylistButton.setText(showingPlaylist ? "隐藏清单" : "显示清单");
    }

    private void clearPlaylist() {
        releasePlayer();
        playlist.clear();
        subtitles.clear();
        currentTrackIndex = -1;
        currentSubtitleIndex = -1;
        seekBar.setProgress(0);
        seekBar.setMax(1);
        timeText.setText("00:00 / 00:00");
        setSubtitleText("打开音频后，将在这里显示当前字幕", "");
        renderPlaylist();
        updateButtons();
    }

    private void renderPlaylist() {
        playlistList.removeAllViews();
        if (playlist.isEmpty()) {
            TextView empty = label("尚未添加音频\n点“加入音频”选择文件", 16, Color.LTGRAY);
            empty.setGravity(Gravity.CENTER);
            playlistList.addView(empty, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(120)));
            return;
        }
        for (int i = 0; i < playlist.size(); i++) {
            final int index = i;
            TextView item = label("♫  " + playlist.get(i).name, 15, Color.WHITE);
            item.setSingleLine(true);
            item.setEllipsize(TextUtils.TruncateAt.MIDDLE);
            item.setPadding(dp(12), 0, dp(8), 0);
            item.setGravity(Gravity.CENTER_VERTICAL);
            item.setBackgroundColor(i == currentTrackIndex ? Color.rgb(75, 75, 75) : Color.TRANSPARENT);
            item.setOnClickListener(v -> loadTrack(index, false));
            playlistList.addView(item, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(48)));
        }
    }

    private String readText(Uri uri) throws Exception {
        StringBuilder builder = new StringBuilder();
        try (InputStream input = getContentResolver().openInputStream(uri);
             BufferedReader reader = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) builder.append(line).append('\n');
        }
        return builder.toString();
    }

    private String displayName(Uri uri) {
        try (Cursor cursor = getContentResolver().query(uri, null, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (index >= 0) return cursor.getString(index);
            }
        } catch (Exception ignored) {}
        return uri.getLastPathSegment() == null ? "audio" : uri.getLastPathSegment();
    }

    private String stem(String name) {
        int dot = name.lastIndexOf('.');
        return dot > 0 ? name.substring(0, dot) : name;
    }

    private String normalizedStem(String name) {
        return name.toLowerCase(Locale.ROOT).replace(" ", "").replace("_", "").replace("-", "").replace(".", "");
    }

    private String formatTime(int ms) {
        int total = Math.max(0, ms / 1000);
        int h = total / 3600;
        int m = (total % 3600) / 60;
        int s = total % 60;
        return h > 0
            ? String.format(Locale.US, "%02d:%02d:%02d", h, m, s)
            : String.format(Locale.US, "%02d:%02d", m, s);
    }

    private void updateButtons() {
        playButton.setText(player != null && player.isPlaying() ? "暂停" : "播放");
    }

    private LinearLayout row() {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        return row;
    }

    private LinearLayout centeredRow() {
        LinearLayout row = row();
        row.setGravity(Gravity.CENTER);
        row.setPadding(0, dp(6), 0, 0);
        return row;
    }

    private TextView label(String text, int sp, int color) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(sp);
        view.setTextColor(color);
        return view;
    }

    private Button button(String title) {
        Button button = new Button(this);
        button.setText(title);
        button.setTextSize(14);
        button.setAllCaps(false);
        return button;
    }

    private LinearLayout.LayoutParams weightParam() {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(0, dp(42), 1);
        params.setMargins(dp(3), dp(3), dp(3), dp(3));
        return params;
    }

    private LinearLayout.LayoutParams fixedButtonParam() {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(dp(108), dp(42));
        params.setMargins(dp(4), dp(3), dp(4), dp(3));
        return params;
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }

    private void releasePlayer() {
        if (player != null) {
            player.release();
            player = null;
        }
    }

    @Override protected void onDestroy() {
        super.onDestroy();
        handler.removeCallbacks(ticker);
        releasePlayer();
    }

    private static final class Track {
        final String name;
        final Uri uri;
        Track(String name, Uri uri) {
            this.name = name;
            this.uri = uri;
        }
    }

    private static final class SubtitleItem {
        final long startMs;
        final long endMs;
        final String text;
        SubtitleItem(long startMs, long endMs, String text) {
            this.startMs = startMs;
            this.endMs = endMs;
            this.text = text;
        }
    }
}
