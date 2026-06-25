# LayoutFix — Arabic ⇄ English keyboard-layout fixer

Fixes text typed on the **wrong keyboard layout**. When you forget to switch
layouts and type Arabic words while still on English (or vice-versa), you get
gibberish. LayoutFix re-maps every key to what it *should* have produced.

```
hkh h;jf fhguvfdi   →   انا اكتب بالعربيه
hello (typed on AR) →   اثممخ  →  hello
```

Direction is **detected automatically**: Arabic-script gibberish converts to
English, Latin gibberish converts to Arabic.

## Install (one time)

1. Install **AutoHotkey v2.0** (free): https://www.autohotkey.com
   *(This script needs v2, not the older v1.)*
2. Double-click **`LayoutFix.ahk`**. A green **H** icon appears in your system tray.
   It now runs in the background and starts working immediately.
3. *(Optional)* To start it automatically with Windows, press `Win+R`, type
   `shell:startup`, and drop a shortcut to `LayoutFix.ahk` in that folder.

## Use

The tool always runs in the tray and quietly remembers the last word you typed.
There is **one trigger: press Shift twice quickly (double-Shift).**

| Action | What double-Shift does |
|--------|------------------------|
| Just finished typing a wrong-layout word | Press **Shift Shift** → it deletes the gibberish and types the corrected text in place. |
| Want to fix existing text | **Select it** (e.g. `Ctrl+A` to select all), then press **Shift Shift** → the selection is replaced with the corrected version. |

Logic: if text is selected, double-Shift fixes the **selection**; otherwise it
fixes the **last word you typed**. Direction (Arabic ⇄ English) is detected
automatically — you never switch layouts manually.

A new word starts after you press **Space**, **Enter**, or **Tab**.

### Double-Shift won't disturb normal typing
A *single* Shift, or Shift held together with a letter (capital letters), works
exactly as normal. Only **two quick, lone Shift taps** (within ~0.35 s, with no
other key pressed in between) trigger a conversion. You can change the timing by
editing `DOUBLE_SHIFT_MS` near the top of the hotkey section.

## Why a trigger instead of fully automatic?

`hkh` typed-as-Arabic and `hkh` as a real English abbreviation are the *exact
same keystrokes* — nothing can tell them apart with 100% certainty. A fully
silent auto-rewrite would sometimes corrupt text you typed correctly. The
double-Shift trigger keeps you in control while still giving the instant feel.

## Customising the layout

The script is built for the **US-English** layout and the standard
**Arabic (101)** Windows layout. If your physical keyboard differs, edit the
`engKeys` / `araKeys` arrays at the top of `LayoutFix.ahk` — index *N* in one
array maps to index *N* in the other.

## Verified

The exact example `hkh h;jf fhguvfdi` → `انا اكتب بالعربيه`, and the reverse
direction, were tested against the standard layout maps and round-trip cleanly.
