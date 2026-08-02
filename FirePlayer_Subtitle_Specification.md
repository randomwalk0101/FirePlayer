# FirePlayer Subtitle Specification v2

## Core Principle

FirePlayer adopts a **Single Subtitle Architecture**.

For each audio file, only **one** subtitle file is stored:

    Example.mp3
    Example.bi.srt

All other learning modes are generated **in real time** by FirePlayer.

------------------------------------------------------------------------

## 1. Naming Convention

For:

    Example.mp3

Generate only:

    Example.bi.srt

The `.bi.srt` file is the only official subtitle format.

------------------------------------------------------------------------

## 2. Subtitle Format

Each subtitle block must contain exactly two lines:

``` srt
1
00:00:01,000 --> 00:00:03,500
How are you today?
你今天怎么样？
```

Rules:

-   English on the first line.
-   Simplified Chinese on the second line.
-   UTF-8 encoding.
-   Keep original timing.
-   Never merge or split subtitle blocks.

------------------------------------------------------------------------

## 3. Codex Responsibilities

Codex should:

1.  Correct Whisper transcription errors.
2.  Preserve all timestamps.
3.  Translate each English subtitle into natural Simplified Chinese.
4.  Output a single file:

```{=html}
<!-- -->
```
    Example.bi.srt

Do not generate:

    Example.en.srt
    Example.stress.en.srt
    Example.flow.en.srt
    Example.phonetic.en.srt

------------------------------------------------------------------------

## 4. FirePlayer Runtime Modes

FirePlayer reads only `Example.bi.srt` and renders different learning
modes in real time.

### English Mode

Show only the English line.

### Bilingual Mode

Show English + Simplified Chinese.

### Stress Mode

Analyze the English sentence and highlight predicted stress words.

### Flow Mode

Predict linking, weak forms, flapping, elision, and reductions in real
time.

### Pronunciation Mode

Generate learner-friendly pronunciation hints (e.g. wanna, gonna, gotta,
didja, whaddaya) without modifying the stored subtitle.

------------------------------------------------------------------------

## 5. Automatic Matching

When opening:

    Example.mp3

FirePlayer automatically loads:

    Example.bi.srt

No other subtitle files are required.

------------------------------------------------------------------------

## 6. Validation

Every generated subtitle must:

-   Be valid SRT.
-   Use UTF-8 encoding.
-   Preserve subtitle count.
-   Preserve timestamps.
-   Preserve ordering.
-   Contain exactly one English line and one Chinese line per subtitle
    block.

------------------------------------------------------------------------

## Philosophy

**One audio. One subtitle. Infinite learning modes.**
