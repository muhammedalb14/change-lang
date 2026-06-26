# LayoutFix — Arabic ⇄ English keyboard-layout fixer

Fixes text typed on the **wrong keyboard layout**. Type Arabic while still on
English (or the reverse) and you get gibberish — LayoutFix re-maps every key to
what it *should* have produced.

```
hkh h;jf fhguvfdi   →   انا اكتب بالعربيه
```

Direction is **detected automatically**. You never switch layouts manually.

## Run it

Just double-click **`LayoutFix.exe`**. A tray icon appears and it works right away.

On first run it **registers itself to start with Windows** automatically (a
shortcut in your Startup folder — no admin needed). Turn this off anytime from
the tray menu → **"Run at Windows startup"**.

> Want to edit the source instead of using the exe? Install
> [AutoHotkey v2.0](https://www.autohotkey.com) (free) and run `LayoutFix.ahk`.

## Use it

Type on the wrong layout, then **tap Shift quickly** — the gibberish is deleted
and the corrected text is typed in its place.

| You want to... | Do this |
|----------------|---------|
| Fix the word you just typed | **Shift × 2** (double-tap) |
| Fix the whole sentence/line you just typed | **Shift × 3** (triple-tap) |
| Fix existing text | **Select it** (e.g. `Ctrl+A`), then **Shift × 2** |
| Flip text back the other way | Repeat the same tap on it |

A new **word** starts after Space/Enter/Tab. A new **sentence** starts after
Enter or Tab (spaces stay part of the sentence).

**Turn on/off:** press **Left+Right Shift** together (or use the tray menu).

Normal typing is never disturbed — a single Shift, or Shift+letter for capitals,
behaves as usual. Only quick, lone Shift taps trigger a conversion.

## Tray menu

Right-click the tray icon for:

- **Layout** — switch the keyboard pair (e.g. *English ⇄ Arabic (101)*). More
  pairs can be added in the source; the menu lists them automatically.
- **Enable / Disable** — master on/off.
- **Run at Windows startup** — toggle auto-start.

Your on/off state and chosen layout are **saved** (in `LayoutFix.ini`) and
restored next time you run it.

## Why a trigger, not fully automatic?

`hkh` typed-as-Arabic and `hkh` as a real English abbreviation are the *exact
same keystrokes* — nothing can tell them apart for certain. The Shift-tap
trigger keeps you in control while still feeling instant.

## Customising

Built for the **US-English** and standard **Arabic (101)** Windows layouts. To
add another keyboard, append an entry to the `LAYOUTS` table in `LayoutFix.ahk`
(an array of the characters each physical key produces, in the same order as
`engKeys`), then recompile — it appears in the tray **Layout** menu
automatically. Conversion timing lives in `DOUBLE_SHIFT_MS`.
