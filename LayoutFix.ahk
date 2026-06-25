#Requires AutoHotkey v2.0
#SingleInstance Force
;==============================================================================
;  LayoutFix  —  Arabic <-> English keyboard-layout fixer for Windows
;------------------------------------------------------------------------------
;  Fixes text typed on the wrong keyboard layout, e.g.
;       hkh h;jf fhguvfdi   ->   انا اكتب بالعربيه
;  ...and the reverse direction too.
;
;  HOW IT WORKS
;    The script runs always-on in the system tray and quietly remembers the
;    last run of characters you typed (the "type buffer"). Conversion fires on
;    a HOTKEY so it never corrupts text you typed correctly:
;
;      Ctrl+Alt+X   Convert the LAST WORD/PHRASE you just typed (real-time feel).
;      Ctrl+Alt+S   Convert the CURRENTLY SELECTED text (for older text).
;
;    Direction is auto-detected: if the text looks like mistyped Arabic it is
;    converted EN-keys -> Arabic; if it looks like mistyped English it is
;    converted AR-keys -> English.
;
;  REQUIREMENTS
;    AutoHotkey v2.0  (https://www.autohotkey.com) — free.
;    Built for the standard US-English layout and the standard Arabic (101)
;    Windows layout. If your physical keyboard differs, edit the maps below.
;==============================================================================

;------------------------------------------------------------------------------
;  1) KEY MAPS  — physical key  ->  character it produces in each layout.
;     Index N in engKeys corresponds to index N in araKeys (same physical key).
;     Sourced from the standard Windows US (00000409) and Arabic 101 (00000401)
;     layouts. Includes letters, shifted letters, and shared punctuation keys.
;------------------------------------------------------------------------------

global engKeys := [
;   row of letters (unshifted)
    "q","w","e","r","t","y","u","i","o","p",
    "a","s","d","f","g","h","j","k","l",
    "z","x","c","v","b","n","m",
;   punctuation / symbol keys shared between the two layouts
    "`;", "'", ",", ".", "/", "[", "]",
;   top-row backtick key (unshifted and shifted) — gives ذ / shadda on Arabic
    "``", "~"
]

global araKeys := [
;   row of letters (unshifted Arabic 101)
    "ض","ص","ث","ق","ف","غ","ع","ه","خ","ح",
    "ش","س","ي","ب","ل","ا","ت","ن","م",
    "ئ","ء","ؤ","ر","لا","ى","ة",
;   punctuation / symbol keys (Arabic 101 positions)
    "ك","ط","و","ز","ظ","ج","د",
;   backtick key on Arabic 101: unshifted = ذ , shifted = shadda ( ّ )
    "ذ","ّ"
]

;------------------------------------------------------------------------------
;  2) Build fast lookup maps in both directions.
;------------------------------------------------------------------------------
global engToAra := Map()
global araToEng := Map()

InitMaps() {
    Loop engKeys.Length {
        e := engKeys[A_Index]
        a := araKeys[A_Index]
        if !engToAra.Has(e)
            engToAra[e] := a
        if !araToEng.Has(a)
            araToEng[a] := e
    }
}
InitMaps()

;------------------------------------------------------------------------------
;  3) Type buffer — remembers the last run of characters typed.
;     Reset by space/enter/navigation so Ctrl+Alt+X targets the last word/phrase.
;------------------------------------------------------------------------------
global typeBuffer := ""
; While we type a fix programmatically, suspend capture so the InputHook does
; not echo the converted characters back into the buffer. After the fix we set
; the buffer ourselves to the converted text, so a SECOND double-shift flips
; the same word back the other way (round-trip toggle).
global suspendCapture := false

; Capture printable keystrokes (letters, digits, common symbols).
~*vk20:: typeBuffer := ""          ; Space resets the buffer (start of new word group)
~*Enter:: typeBuffer := ""
~*Tab:: typeBuffer := ""

; Ctrl+A (select all) clears the buffer so double-Shift fixes the SELECTION,
; not the last typed word. Mouse selections aren't intercepted, but typically
; come after a word boundary that already cleared the buffer.
~^a:: typeBuffer := ""

; Hook printable characters via InputHook for reliability across layouts.
ih := InputHook("V I1")            ; Visible, no end-on-printable, intercept off
ih.KeyOpt("{All}", "N")            ; notify for all keys
ih.OnChar := CaptureChar
ih.OnKeyDown := CaptureKeyDown
ih.Start()

CaptureChar(hook, char) {
    global typeBuffer, suspendCapture
    if (suspendCapture)            ; ignore our own programmatic typing
        return
    if (char = " " || char = "`t" || char = "`r" || char = "`n")
        typeBuffer := ""
    else
        typeBuffer .= char
}

CaptureKeyDown(hook, vk, sc) {
    global typeBuffer, suspendCapture
    if (suspendCapture)            ; ignore our own programmatic typing
        return
    if (vk = 8) {                  ; Backspace trims the buffer
        if (StrLen(typeBuffer) > 0)
            typeBuffer := SubStr(typeBuffer, 1, -1)
    } else if (vk = 13 || vk = 9) {
        typeBuffer := ""
    }
}

;------------------------------------------------------------------------------
;  4) Conversion engine.
;------------------------------------------------------------------------------

; Decide direction & convert. Returns "" if nothing convertible.
ConvertText(text) {
    if (text = "")
        return ""

    ; Count direction evidence using ONLY unambiguous, script-specific letters.
    ; Punctuation like [ ] / ; lives in BOTH maps, so it must NOT vote on
    ; direction — counting it caused e.g. "][h[" (meant دجاج) to be read as
    ; Arabic-layout output and mangled. Decide on real script characters only.
    araHits := 0, engHits := 0
    Loop Parse text {
        ch := A_LoopField
        if RegExMatch(ch, "[\x{0600}-\x{06FF}]")     ; actual Arabic-script char
            araHits++
        else if RegExMatch(ch, "[a-zA-Z]")            ; actual Latin letter
            engHits++
    }

    ; More Arabic-script letters  -> text was typed on the Arabic layout,
    ;                                convert AR-keys -> English.
    ; More Latin letters (or only punctuation) -> convert EN-keys -> Arabic.
    if (araHits > engHits)
        return MapString(text, araToEng)
    else
        return MapString(text, engToAra)
}

MapString(text, lookup) {
    out := ""
    Loop Parse text {
        ch := A_LoopField
        if lookup.Has(ch) {
            out .= lookup[ch]
        } else {
            ; A capital English letter (Q, W, F...) has no direct entry — the
            ; shifted-key entries were removed on purpose because they produced
            ; junk diacritics. Map it like its lowercase key instead, so
            ; Shift+letter gives the normal Arabic letter (Q -> ض, like q).
            low := StrLower(ch)
            out .= lookup.Has(low) ? lookup[low] : ch
        }
    }
    return out
}

;------------------------------------------------------------------------------
;  5) TRIGGER: Double-Shift  (press Shift twice quickly, with no key between).
;     - If text is SELECTED  -> convert the selection (e.g. after Ctrl+A).
;     - Otherwise            -> convert the LAST WORD you just typed.
;     A single Shift, or Shift held with another key, behaves normally
;     (capital letters etc.) — only two quick lone taps trigger conversion.
;------------------------------------------------------------------------------
global DOUBLE_SHIFT_MS := 350         ; max gap between the two taps (ms)
global lastShiftTick := 0
global toolEnabled := true            ; master on/off (toggled by Left+Right Shift)

ShiftTapped() {
    global lastShiftTick, DOUBLE_SHIFT_MS, toolEnabled
    if (!toolEnabled)                 ; tool is off -> ignore the fix trigger
        return
    ; If BOTH shifts are down, this is the on/off toggle, not a fix. Ignore.
    if (GetKeyState("LShift", "P") && GetKeyState("RShift", "P"))
        return
    now := A_TickCount
    if (now - lastShiftTick <= DOUBLE_SHIFT_MS) {
        lastShiftTick := 0            ; consume, so a 3rd tap doesn't re-fire
        DoFix()
    } else {
        lastShiftTick := now
    }
}

; IMPORTANT: we use the "~" prefix and plain key names ONLY. We must NOT use the
; "LShift & RShift" combo syntax — that turns Shift into a prefix key and breaks
; normal Shift+letter capitalization. Instead we detect the toggle by checking,
; on each Shift release, whether BOTH shifts were involved.
;
; "~" = let Windows still process the Shift normally (capitals keep working).
; We only fire our logic on the key-UP of a Shift.

~LShift Up:: {
    ; Both shifts pressed together -> on/off toggle (not a fix, not a tap).
    if (GetKeyState("RShift", "P")) {
        ToggleTool()
        return
    }
    ; Released on its own (no other key in between) -> counts as a tap.
    if (A_PriorKey = "LShift")
        ShiftTapped()
}
~RShift Up:: {
    if (GetKeyState("LShift", "P")) {
        ToggleTool()
        return
    }
    if (A_PriorKey = "RShift")
        ShiftTapped()
}

global lastToggleTick := 0

ToggleTool() {
    global toolEnabled, lastShiftTick, lastToggleTick
    ; Both shifts release one after the other, so this fires twice. Ignore the
    ; second call within a short window so the tool toggles exactly once.
    now := A_TickCount
    if (now - lastToggleTick < 500)
        return
    lastToggleTick := now
    toolEnabled := !toolEnabled
    lastShiftTick := 0                ; don't let the combo seed a double-tap
    if (toolEnabled) {
        TraySetIcon("shell32.dll", 222)   ; normal icon
        Notify("LayoutFix: ON")
    } else {
        TraySetIcon("shell32.dll", 132)   ; dimmed/different icon = off
        Notify("LayoutFix: OFF  (Left+Right Shift to turn on)")
    }
}

; Unified fix. A real selection always wins (checked first via a short
; clipboard probe); if nothing is selected, fix the last word you typed.
DoFix() {
    global typeBuffer

    ; 1) SELECTION PATH FIRST — a real selection must always win over the
    ;    buffered last word. (Putting the buffer first regressed Ctrl+A: it
    ;    would fix only the last word and never look at the selection.)
    ;    We copy the selection; if anything comes back, that is what to fix.
    saved := ClipboardAll()
    A_Clipboard := ""
    Send("^c")
    ; Short wait: a real selection returns almost instantly; with no selection
    ; the clipboard stays empty and we fall through quickly to the word fix.
    if (ClipWait(0.15) && A_Clipboard != "") {
        sel := A_Clipboard
        converted := ConvertText(sel)        ; flip whole selection one direction
        if (converted != "" && converted != sel) {
            A_Clipboard := converted
            Send("^v")
            Sleep(80)
            A_Clipboard := saved
            typeBuffer := ""
            return
        }
        A_Clipboard := saved                 ; selection existed but not fixable
    } else {
        A_Clipboard := saved                 ; nothing selected
    }

    ; 2) NO USABLE SELECTION — fix the last word you just typed.
    src := typeBuffer
    if (src != "") {
        converted := ConvertText(src)
        if (converted != "" && converted != src) {
            global suspendCapture
            suspendCapture := true            ; don't echo our own typing
            Send("{BS " StrLen(src) "}")
            SendText(converted)
            Sleep(20)                          ; let the InputHook drain
            ; Keep the converted word in the buffer so pressing double-shift
            ; AGAIN flips the SAME word back the other way (round-trip toggle).
            typeBuffer := converted
            suspendCapture := false
            return
        }
    }
    Notify(src != "" ? "Couldn't detect a wrong-layout word."
                     : "Nothing to convert — type something or select text first.")
}

Notify(msg) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -1500)
}

;------------------------------------------------------------------------------
;  7) Tray menu.
;------------------------------------------------------------------------------
A_TrayMenu.Delete()
A_TrayMenu.Add("LayoutFix — Arabic <-> English", (*) => "")
A_TrayMenu.Disable("LayoutFix — Arabic <-> English")
A_TrayMenu.Add()
A_TrayMenu.Add("Double-Shift = fix last word / selection", (*) => "")
A_TrayMenu.Disable("Double-Shift = fix last word / selection")
A_TrayMenu.Add("(select text first to fix a selection)", (*) => "")
A_TrayMenu.Disable("(select text first to fix a selection)")
A_TrayMenu.Add("Left+Right Shift = turn ON/OFF", (*) => "")
A_TrayMenu.Disable("Left+Right Shift = turn ON/OFF")
A_TrayMenu.Add()
A_TrayMenu.Add("Enable / Disable", (*) => ToggleTool())
A_TrayMenu.Add("Reload", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())
TrayTip("LayoutFix is running", "Shift TWICE = fix word/selection.`nLeft+Right Shift = turn on/off.", 1)
