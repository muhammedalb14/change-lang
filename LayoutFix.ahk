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
;  0) SETTINGS FILE — persist on/off state and the chosen layout pair so they
;     survive restarts and reloads. Stored next to the script as LayoutFix.ini.
;------------------------------------------------------------------------------
global INI_FILE := A_ScriptDir "\LayoutFix.ini"

LoadSetting(key, default) {
    global INI_FILE
    return IniRead(INI_FILE, "Settings", key, default)
}
SaveSetting(key, value) {
    global INI_FILE
    try IniWrite(value, INI_FILE, "Settings", key)
}

;------------------------------------------------------------------------------
;  1) KEY MAPS  — physical key  ->  character it produces in each layout.
;     Index N in the "eng" array corresponds to index N in the second-layout
;     array (same physical key). Each entry in LAYOUTS is a switchable pair.
;     Sourced from standard Windows layouts. Add more pairs here and they show
;     up automatically in the tray "Layout" submenu.
;------------------------------------------------------------------------------

; Physical key order shared by every layout's "base" array below.
global engKeys := [
;   row of letters (unshifted)
    "q","w","e","r","t","y","u","i","o","p",
    "a","s","d","f","g","h","j","k","l",
    "z","x","c","v","b","n","m",
;   punctuation / symbol keys shared between layouts
    "`;", "'", ",", ".", "/", "[", "]",
;   top-row backtick key (unshifted and shifted)
    "``", "~"
]

; LAYOUTS: name -> array of "other layout" characters, same physical-key order
; as engKeys above. To add a layout (e.g. Russian, French), append an entry
; with the characters each physical key produces on that layout.
global LAYOUTS := Map(
    "Arabic (101)", [
    ;   row of letters (unshifted Arabic 101)
        "ض","ص","ث","ق","ف","غ","ع","ه","خ","ح",
        "ش","س","ي","ب","ل","ا","ت","ن","م",
        "ئ","ء","ؤ","ر","لا","ى","ة",
    ;   punctuation / symbol keys (Arabic 101 positions)
        "ك","ط","و","ز","ظ","ج","د",
    ;   backtick key on Arabic 101: unshifted = ذ , shifted = shadda ( ّ )
        "ذ","ّ"
    ]
)

; Currently selected layout pair (persisted). Falls back to the first defined
; layout if the saved name no longer exists.
global currentLayout := LoadSetting("Layout", "Arabic (101)")
if !LAYOUTS.Has(currentLayout) {
    for name, _ in LAYOUTS {
        currentLayout := name
        break
    }
}

;------------------------------------------------------------------------------
;  2) Build fast lookup maps in both directions for the current layout.
;------------------------------------------------------------------------------
global engToAra := Map()
global araToEng := Map()

InitMaps() {
    global engKeys, LAYOUTS, currentLayout, engToAra, araToEng
    engToAra := Map()
    araToEng := Map()
    otherKeys := LAYOUTS[currentLayout]
    Loop engKeys.Length {
        e := engKeys[A_Index]
        a := otherKeys[A_Index]
        if !engToAra.Has(e)
            engToAra[e] := a
        if !araToEng.Has(a)
            araToEng[a] := e
    }
}
InitMaps()

;------------------------------------------------------------------------------
;  2b) RUN AT STARTUP — register a shortcut in the user's Startup folder so
;      LayoutFix launches automatically when Windows starts.
;
;      Done on first run automatically (idempotent: it only writes the shortcut
;      if it's missing or points at the wrong location, so moving the exe and
;      relaunching self-heals the link). The shortcut targets whatever this
;      program currently is — A_IsCompiled means use the .exe path; otherwise
;      launch the .ahk through the AutoHotkey interpreter.
;------------------------------------------------------------------------------
global STARTUP_LNK := A_Startup "\LayoutFix.lnk"

; Returns the target + args that should be in the startup shortcut.
GetRunTarget() {
    if (A_IsCompiled)
        return { target: A_ScriptFullPath, args: "" }
    ; Running as a raw .ahk: start it via the AutoHotkey interpreter so the
    ; shortcut works even when .ahk isn't associated with AutoHotkey.
    return { target: A_AhkPath, args: '"' A_ScriptFullPath '"' }
}

; True if a correct startup shortcut already exists (right target + args).
IsStartupEnabled() {
    global STARTUP_LNK
    if !FileExist(STARTUP_LNK)
        return false
    try {
        FileGetShortcut(STARTUP_LNK, &outTarget, , &outArgs)
        t := GetRunTarget()
        return (outTarget = t.target) && (outArgs = t.args)
    }
    return false
}

EnableStartup() {
    global STARTUP_LNK
    t := GetRunTarget()
    try {
        FileCreateShortcut(t.target, STARTUP_LNK, A_ScriptDir, t.args,
            "LayoutFix — Arabic <-> English keyboard-layout fixer")
        return true
    } catch as e {
        return false
    }
}

DisableStartup() {
    global STARTUP_LNK
    try {
        if FileExist(STARTUP_LNK)
            FileDelete(STARTUP_LNK)
    }
}

; Toggle from the tray menu, with a refreshing checkmark.
ToggleStartup(*) {
    if IsStartupEnabled() {
        DisableStartup()
        Notify("LayoutFix: will NO LONGER start with Windows.")
    } else {
        if EnableStartup()
            Notify("LayoutFix: will now start with Windows.")
        else
            Notify("Couldn't write the startup shortcut.")
    }
    RefreshStartupMenu()
}

RefreshStartupMenu() {
    if IsStartupEnabled()
        A_TrayMenu.Check("Run at Windows startup")
    else
        A_TrayMenu.Uncheck("Run at Windows startup")
}

; First-run convenience: if no startup entry exists yet, create one so the
; user gets auto-start out of the box. They can turn it off from the tray.
if !IsStartupEnabled()
    EnableStartup()

;------------------------------------------------------------------------------
;  3) Type buffers — two rolling captures of what you typed:
;       typeBuffer     = the LAST WORD (reset on every Space/Enter/Tab).
;       sentenceBuffer = the LAST LINE/SENTENCE (spaces are KEPT; only cleared
;                        by Enter/Tab or once it grows past a sane cap).
;     Double-Shift fixes the word; Triple-Shift fixes the whole sentence.
;------------------------------------------------------------------------------
global typeBuffer := ""
global sentenceBuffer := ""
global SENTENCE_MAX := 400         ; safety cap so the line buffer can't grow forever
; While we type a fix programmatically, suspend capture so the InputHook does
; not echo the converted characters back into the buffers. After the fix we set
; the buffers ourselves to the converted text, so a SECOND trigger flips the
; same text back the other way (round-trip toggle).
global suspendCapture := false

; Space ends a word but continues the sentence.
~*vk20:: {
    global typeBuffer, sentenceBuffer, suspendCapture
    if (suspendCapture)
        return
    typeBuffer := ""
    if (sentenceBuffer != "")      ; don't start a sentence with a leading space
        sentenceBuffer .= " "
}
; Enter / Tab end both the word AND the sentence.
~*Enter:: ResetBuffers()
~*Tab:: ResetBuffers()

ResetBuffers() {
    global typeBuffer, sentenceBuffer
    typeBuffer := ""
    sentenceBuffer := ""
}

; Ctrl+A (select all) clears the buffers so the trigger fixes the SELECTION,
; not the last typed text. Mouse selections aren't intercepted, but typically
; come after a word boundary that already cleared the word buffer.
~^a:: ResetBuffers()

; Hook printable characters via InputHook for reliability across layouts.
ih := InputHook("V I1")            ; Visible, no end-on-printable, intercept off
ih.KeyOpt("{All}", "N")            ; notify for all keys
ih.OnChar := CaptureChar
ih.OnKeyDown := CaptureKeyDown
ih.Start()

CaptureChar(hook, char) {
    global typeBuffer, sentenceBuffer, suspendCapture, SENTENCE_MAX
    if (suspendCapture)            ; ignore our own programmatic typing
        return
    if (char = " " || char = "`t" || char = "`r" || char = "`n") {
        typeBuffer := ""
        if (char = " " && sentenceBuffer != "")
            sentenceBuffer .= " "
        else if (char != " ")
            sentenceBuffer := ""   ; tab/newline end the sentence
        return
    }
    typeBuffer .= char
    sentenceBuffer .= char
    ; Keep the sentence buffer bounded.
    if (StrLen(sentenceBuffer) > SENTENCE_MAX)
        sentenceBuffer := SubStr(sentenceBuffer, -SENTENCE_MAX)
}

CaptureKeyDown(hook, vk, sc) {
    global typeBuffer, sentenceBuffer, suspendCapture
    if (suspendCapture)            ; ignore our own programmatic typing
        return
    if (vk = 8) {                  ; Backspace trims both buffers
        if (StrLen(typeBuffer) > 0)
            typeBuffer := SubStr(typeBuffer, 1, -1)
        if (StrLen(sentenceBuffer) > 0)
            sentenceBuffer := SubStr(sentenceBuffer, 1, -1)
    } else if (vk = 13 || vk = 9) {
        ResetBuffers()
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
;  5) TRIGGER: Shift taps  (press Shift quickly, with no other key between).
;       Double-Shift  -> fix the SELECTION if any, else the LAST WORD.
;       Triple-Shift  -> fix the whole LAST SENTENCE / LINE you just typed.
;     A single Shift, or Shift held with another key, behaves normally
;     (capital letters etc.) — only quick lone taps count.
;------------------------------------------------------------------------------
global DOUBLE_SHIFT_MS := 350         ; max gap between consecutive taps (ms)
global lastShiftTick := 0
global shiftTapCount := 0             ; consecutive lone Shift taps in the window
global toolEnabled := (LoadSetting("Enabled", "1") = "1")  ; persisted on/off

ShiftTapped() {
    global lastShiftTick, shiftTapCount, DOUBLE_SHIFT_MS, toolEnabled
    if (!toolEnabled)                 ; tool is off -> ignore the fix trigger
        return
    ; If BOTH shifts are down, this is the on/off toggle, not a fix. Ignore.
    if (GetKeyState("LShift", "P") && GetKeyState("RShift", "P"))
        return
    now := A_TickCount
    ; Continue the current tap run if within the window, else start a new run.
    if (now - lastShiftTick <= DOUBLE_SHIFT_MS)
        shiftTapCount += 1
    else
        shiftTapCount := 1
    lastShiftTick := now
    ; Defer the decision briefly so a 3rd tap can upgrade double -> triple.
    ; The timer fires once tapping pauses; it reads the final count.
    SetTimer(ResolveShiftTaps, -(DOUBLE_SHIFT_MS + 20))
}

; Called after tapping pauses. 2 taps -> word/selection fix, 3+ -> sentence fix.
ResolveShiftTaps() {
    global shiftTapCount, lastShiftTick
    count := shiftTapCount
    shiftTapCount := 0
    lastShiftTick := 0
    if (count >= 3)
        DoFixSentence()
    else if (count = 2)
        DoFix()
    ; a single lone tap does nothing
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
    SaveSetting("Enabled", toolEnabled ? "1" : "0")   ; remember across restarts
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
    global typeBuffer, sentenceBuffer, suspendCapture

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
            sentenceBuffer := ""
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
            ReplaceTyped(src, converted)
            ; Keep BOTH buffers in sync with what's now on screen so a repeat
            ; flips the same word back (round-trip toggle) and the sentence
            ; buffer's tail stays accurate.
            typeBuffer := converted
            sentenceBuffer := ReplaceTail(sentenceBuffer, src, converted)
            return
        }
    }
    Notify(src != "" ? "Couldn't detect a wrong-layout word — `"" src "`""
                     : "Nothing to convert — type something or select text first.")
}

; Triple-Shift: fix the whole last sentence/line you typed, in place.
DoFixSentence() {
    global sentenceBuffer, typeBuffer
    src := sentenceBuffer
    if (src = "") {
        Notify("Nothing to convert — type a sentence first.")
        return
    }
    converted := ConvertText(src)
    if (converted = "" || converted = src) {
        Notify("Couldn't detect a wrong-layout sentence.")
        return
    }
    ReplaceTyped(src, converted)
    ; Sync buffers so a repeat triple-Shift round-trips the same sentence, and
    ; the word buffer reflects the (converted) last word.
    sentenceBuffer := converted
    typeBuffer := LastWord(converted)
    Notify("Fixed sentence → " (StrLen(converted) > 40
        ? SubStr(converted, 1, 40) "…" : converted))
}

; Backspace `oldText` and type `newText` in its place, without echoing into
; our own capture buffers.
ReplaceTyped(oldText, newText) {
    global suspendCapture
    suspendCapture := true
    Send("{BS " StrLen(oldText) "}")
    SendText(newText)
    Sleep(20)                          ; let the InputHook drain
    suspendCapture := false
}

; If `buffer` ends with `oldTail`, swap that tail for `newTail`; else return
; `newTail` (best effort — keeps the sentence buffer consistent after a fix).
ReplaceTail(buffer, oldTail, newTail) {
    if (SubStr(buffer, -StrLen(oldTail)) = oldTail)
        return SubStr(buffer, 1, StrLen(buffer) - StrLen(oldTail)) newTail
    return newTail
}

; Last whitespace-separated word of a string (for buffer sync after a fix).
LastWord(text) {
    parts := StrSplit(Trim(text), " ")
    return parts.Length ? parts[parts.Length] : text
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
A_TrayMenu.Add("Double-Shift = fix word / selection", (*) => "")
A_TrayMenu.Disable("Double-Shift = fix word / selection")
A_TrayMenu.Add("Triple-Shift = fix the whole sentence", (*) => "")
A_TrayMenu.Disable("Triple-Shift = fix the whole sentence")
A_TrayMenu.Add("Left+Right Shift = turn ON/OFF", (*) => "")
A_TrayMenu.Disable("Left+Right Shift = turn ON/OFF")
A_TrayMenu.Add()

; Layout submenu — one radio-style entry per pair defined in LAYOUTS.
global layoutMenu := Menu()
BuildLayoutMenu()
A_TrayMenu.Add("Layout", layoutMenu)

A_TrayMenu.Add()
A_TrayMenu.Add("Enable / Disable", (*) => ToggleTool())
A_TrayMenu.Add("Run at Windows startup", ToggleStartup)
RefreshStartupMenu()
A_TrayMenu.Add("Reload", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())
TrayTip("LayoutFix is running",
    "Shift x2 = fix word.  Shift x3 = fix sentence.`nLeft+Right Shift = on/off.", 1)

; Reflect the persisted on/off state in the tray icon at launch.
if (toolEnabled)
    TraySetIcon("shell32.dll", 222)
else
    TraySetIcon("shell32.dll", 132)

BuildLayoutMenu() {
    global layoutMenu, LAYOUTS, currentLayout
    for name, _ in LAYOUTS
        layoutMenu.Add("English ⇄ " name, SelectLayout)
    RefreshLayoutMenu()
}

SelectLayout(name, *) {
    global currentLayout
    ; The menu passes the FULL item text ("English ⇄ Arabic (101)"); strip the
    ; prefix back to the layout key stored in LAYOUTS.
    key := RegExReplace(name, "^English ⇄ ", "")
    currentLayout := key
    SaveSetting("Layout", key)
    InitMaps()                         ; rebuild lookup tables for the new pair
    RefreshLayoutMenu()
    Notify("Layout: English ⇄ " key)
}

RefreshLayoutMenu() {
    global layoutMenu, LAYOUTS, currentLayout
    for name, _ in LAYOUTS {
        item := "English ⇄ " name
        if (name = currentLayout)
            layoutMenu.Check(item)
        else
            layoutMenu.Uncheck(item)
    }
}
