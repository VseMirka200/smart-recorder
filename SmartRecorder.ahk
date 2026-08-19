#Requires AutoHotkey v2.0
#SingleInstance Force
#Include *i OCR.ahk

; ============================================================
; SMART RECORDER — TEST MODE
; AutoHotkey v2
;
; Функции:
;   - запись мыши + клавиатуры
;   - воспроизведение с изменяемой скоростью
;   - заданное число повторов
;   - случайный кулдаун между полными повторами
;   - экранная панель состояния
;   - OCR-помощник для тестовых форм
;   - синтетический профиль: случайный возраст/пол в заданных пределах
;   - новый профиль перед каждым повтором (по желанию)
;   - автоматическое сохранение записанного макроса на диск
;   - автоматическая загрузка макроса после перезапуска программы
;   - распознаёт вопросы про возраст/пол и ПОКАЗЫВАЕТ ответ
;   - F7 вводит текущий тестовый ответ
;
; ВАЖНО: режим предназначен для собственных/тестовых форм.
; OCR-помощник не отправляет формы автоматически.
; ============================================================

CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")
SetMouseDelay(-1)
SetKeyDelay(-1, -1)

global appIconPath := A_ScriptDir . "\SmartRecorder.ico"

; ------------------------- НАСТРОЙКИ -------------------------
global repeatCount := 1
global playbackSpeed := 2.0
global cooldownMinMinutes := 0.05
global cooldownMaxMinutes := 0.10
global recordInterval := 15

global ageMin := 20
global ageMax := 55
global sexMode := "Случайно (М/Ж)"
global randomProfileEachRepeat := true

; Текущий синтетический профиль
global testAge := 30
global testSex := "Мужской"

global smartOcrEnabled := false
global ocrInterval := 1200

; ---------------------- СОХРАНЕНИЕ МАКРОСА -------------------
; Запись автоматически сохраняется сюда после завершения F8
; и автоматически загружается при следующем запуске программы.
global recordingsDir := A_ScriptDir . "\recordings"
global recordingFile := recordingsDir . "\last_recording.srm"
global currentRecordingPath := recordingFile
global currentRecordingName := "last_recording.srm"

; --------------------- СНИМКИ F4 ----------------------------
global f4ScreenshotEnabled := true
global f4ScreenshotWidth := 820
global f4ScreenshotHeight := 260
global f4ScreenshotDir := A_ScriptDir "\screenshots\F4"
global f4ScreenshotLastError := ""

global lastSaveStatus := "Сохранённая запись ещё не загружена"

; -------------------------- СОСТОЯНИЕ ------------------------
global recording := false
global playing := false
global stopRequested := false
global events := []
global recordStart := 0
global lastX := 0
global lastY := 0

global moveCount := 0
global clickCount := 0
global wheelCount := 0
global keyPressCount := 0
global lastAction := "Ожидание"

global keyboardHook := 0
global playbackKeysDown := Map()

global ignoreKeyboardCapture := false
global ignoreMouseCapture := false
global recordingPaused := false

global statusVisible := true
global controlVisible := true
global lastPlaybackStatusTick := 0

; ---------------------- ВРЕМЯ РАБОТЫ ------------------------
; Перед запуском F9 все случайные кулдауны выбираются заранее.
; Поэтому чёрная панель может показывать почти точное общее время.
global runCooldownPlan := []
global runPlannedSeconds := 0
global runStartTick := 0
global runMacroSeconds := 0

; После F10 чёрная панель фиксируется на статусе "ОСТАНОВЛЕНО".
; Фоновый OCR не сможет её перерисовать, пока пользователь
; сам не начнёт новое действие.
global statusPanelFrozen := false

; -------------------------- ЖУРНАЛ ---------------------------
global journalEntries := []
global journalMaxEntries := 9
global journalVisible := true

; ---------------------- НАДЁЖНОСТЬ F4 -----------------------
global answerCaptureAttempts := 4
global answerFindTimeoutMs := 30000

; --------------------- ГИБРИДНЫЙ F4 -------------------------
; Если текст ответа не виден, программа сама немного листает страницу,
; повторяет OCR и пытается найти тот же ответ.
global answerAutoScrollEnabled := true
global answerScrollSteps := 24
global answerScrollNotches := 3
global answerScrollPauseMs := 260

; ---------------------- БЕЗОПАСНЫЙ F4 -----------------------
; true = никогда не выбирать "похожий" ответ и не использовать старые X/Y.
; Если точный текст не найден, макрос остановится.
global answerStrictMode := true

global smartDetectedQuestion := ""
global smartSuggestedAnswer := ""
global smartLastText := ""
global smartLastError := ""
global ocrAvailable := false

; ============================================================
; ПРОВЕРКА OCR
; ============================================================

try {
    OCR.GetAvailableLanguages()
    OCR.PerformanceMode := 1
    ocrAvailable := true
} catch as err {
    ocrAvailable := false
    smartLastError := "OCR.ahk не найден или не загрузился"
}

ApplyAppIcon()

; ============================================================
; ПАНЕЛЬ СОСТОЯНИЯ
; ============================================================

; ============================================================
; ЧЁРНОЕ ОКНО №1 — СТАТУС
; ============================================================

global statusGui := Gui(
    "+AlwaysOnTop -Caption +ToolWindow +Border +E0x20"
)

statusGui.BackColor := "202020"
statusGui.SetFont("s10 cFFFFFF", "Segoe UI")

global statusTextCtrl := statusGui.Add(
    "Text",
    "x12 y10 w475 h345",
    ""
)

statusGui.Show(
    "x20 y20 w500 h370 NoActivate"
)


; ============================================================
; ЧЁРНОЕ ОКНО №2 — ЖУРНАЛ
; ============================================================

global journalGui := Gui(
    "+AlwaysOnTop -Caption +ToolWindow +Border +E0x20"
)

journalGui.BackColor := "111111"

journalGui.SetFont(
    "s10 cFFFFFF bold",
    "Segoe UI"
)

global journalTitleCtrl := journalGui.Add(
    "Text",
    "x12 y9 w475 h22",
    "ЖУРНАЛ ДЕЙСТВИЙ"
)

journalGui.SetFont(
    "s9 cCFCFCF",
    "Consolas"
)

global journalTextCtrl := journalGui.Add(
    "Text",
    "x12 y35 w475 h155",
    ""
)

journalGui.Show(
    "x20 y405 w500 h205 NoActivate"
)

; ============================================================
; ОКНО НАСТРОЕК
; ============================================================

global controlGui := Gui("+AlwaysOnTop", "Smart Recorder — Test Mode")
controlGui.SetFont("s10", "Segoe UI")

; ------------------------------------------------------------
; КОМПАКТНАЯ ПАНЕЛЬ НАСТРОЕК
; ------------------------------------------------------------

; Запуск / тайминги
controlGui.Add("GroupBox", "x10 y10 w385 h125", "Запуск и тайминги")

; Общая сетка верхнего блока: все строки начинаются с x25 и заканчиваются на x380.
; Подписи выровнены по одной левой линии, правый край элементов общий.
controlGui.Add("Text", "x25 y35 w138 h25 0x200", "Количество повторов:")
global repeatEditCtrl := controlGui.Add("Edit", "x169 y35 w211 h25", repeatCount)

; Скорость + кулдаун: одинаковые компактные отступы подпись → поле.
controlGui.Add("Text", "x20 y70 w62 h25 Right 0x200", "Скорость:")
global speedEditCtrl := controlGui.Add("Edit", "x87 y70 w95 h25", playbackSpeed)

controlGui.Add("Text", "x188 y70 w62 h25 Right 0x200", "Кулдаун:")
global cooldownMinEditCtrl := controlGui.Add("Edit", "x255 y70 w54 h25", FormatDurationInput(cooldownMinMinutes * 60))
controlGui.Add("Text", "x313 y70 w10 h25 Center 0x200", "—")
global cooldownMaxEditCtrl := controlGui.Add("Edit", "x327 y70 w53 h25", FormatDurationInput(cooldownMaxMinutes * 60))

controlGui.Add("Text", "x25 y104 w54 h20 0x200", "Формат:")
global formatHintCtrl := controlGui.Add("Text", "x82 y104 w298 h20 0x200", "3м, 3м30с, 90с, 00:03:30")
formatHintCtrl.SetFont("s9", "Segoe UI")

; Профиль
controlGui.Add("GroupBox", "x10 y145 w385 h195", "Профиль теста")

; Единая аккуратная сетка профиля.
controlGui.Add("Text", "x25 y170 w52 h25 Right 0x200", "Возраст:")
global ageMinEditCtrl := controlGui.Add("Edit", "x83 y170 w48 h25", ageMin)
controlGui.Add("Text", "x136 y170 w16 h25 Center 0x200", "—")
global ageMaxEditCtrl := controlGui.Add("Edit", "x157 y170 w48 h25", ageMax)

controlGui.Add("Text", "x215 y170 w28 h25 Right 0x200", "Пол:")
global sexModeDropCtrl := controlGui.Add("DropDownList", "x248 y170 w132", ["Случайно (М/Ж)", "Мужской", "Женский"])
sexModeDropCtrl.Choose(1)

global randomProfileCheckCtrl := controlGui.Add("CheckBox", "x25 y203 w355 h24", "Новый случайный профиль перед каждым повтором")
randomProfileCheckCtrl.Value := 1

global currentProfileLabelCtrl := controlGui.Add("Text", "x25 y232 w355 h22", "Текущий профиль: —")

global smartOcrCheckCtrl := controlGui.Add("CheckBox", "x25 y260 w230 h24", "Включить OCR-распознавание (F6)")
global ocrStateLabelCtrl := controlGui.Add("Text", "x295 y260 w85 h24 Right 0x200", ocrAvailable ? "OCR: готов" : "OCR: нет")

global newProfileGuiBtn := controlGui.Add("Button", "x25 y293 w138 h30", "Новый профиль F5")
controlGui.Add("Text", "x175 y293 w205 h30 0x200", "F3 — выбор пола")

; Основное управление
global recordGuiBtn := controlGui.Add("Button", "x15 y350 w120 h38", "Запись F8")
global playGuiBtn := controlGui.Add("Button", "x145 y350 w120 h38", "Старт F9")
global stopGuiBtn := controlGui.Add("Button", "x275 y350 w120 h38", "СТОП F10")

global smartTypeGuiBtn := controlGui.Add("Button", "x15 y398 w185 h36", "Ввести подсказку F7")
global hideGuiBtn := controlGui.Add("Button", "x210 y398 w185 h36", "Скрыть настройки")

controlGui.Add(
    "Text",
    "x15 y444 w380 h50",
    "F1 — журнал | F3 — пол | F4 — ответ | F5 — профиль | F6 — OCR`nF7 — OCR-ответ | F11 — статус | F12 — настройки | Esc — выход"
)

; ------------------------------------------------------------
; ЗАПИСИ: СОХРАНЕНИЕ АВТОМАТИЧЕСКОЕ, В GUI ТОЛЬКО ВЫБОР ФАЙЛА
; ------------------------------------------------------------
controlGui.Add("GroupBox", "x10 y500 w385 h92", "Запись")

global recordingFileLabelCtrl := controlGui.Add(
    "Text",
    "x25 y522 w345 h22",
    "Текущий файл: last_recording.srm"
)

global loadOtherRecordingGuiBtn := controlGui.Add(
    "Button",
    "x25 y550 w345 h32",
    "Загрузить другую запись..."
)

recordGuiBtn.OnEvent("Click", StartRecordingFromGui)
playGuiBtn.OnEvent("Click", StartPlaybackFromGui)
stopGuiBtn.OnEvent("Click", StopPlaybackFromGui)
smartTypeGuiBtn.OnEvent("Click", TypeSmartAnswerFromGui)
newProfileGuiBtn.OnEvent("Click", NewProfileFromGui)
loadOtherRecordingGuiBtn.OnEvent("Click", LoadOtherRecordingFromGui)
hideGuiBtn.OnEvent("Click", HideControlWindow)
smartOcrCheckCtrl.OnEvent("Click", SmartCheckboxChanged)
controlGui.OnEvent("Close", HideControlWindow)

controlGui.Show("x540 y20 w410 h605")
ApplyGuiIcons()
ApplySettings()
GenerateTestProfile(false)

; При старте автоматически загружаем последнюю сохранённую запись.
EnsureRecordingStorage()
if LoadRecordingFromFile(recordingFile, false) {
    currentRecordingPath := recordingFile
    currentRecordingName := "last_recording.srm"
}

ShowIdleStatus()
LogEvent("Программа запущена — журнал в отдельном окне")
LogEvent(ocrAvailable ? "OCR готов" : "OCR недоступен")
LogEvent("OCR скрывает чёрную панель перед снимком")
LogEvent("F4 PLAY: снимки включены при воспроизведении")

; ============================================================
; ГОРЯЧИЕ КЛАВИШИ
; ============================================================

F1::ToggleJournalPanel()
F2::InsertProfileAgeHotkey()
F3::InsertProfileSexHotkey()
F4::RememberAnswerByText()
F5::NewTestProfile()
F6::ToggleSmartOcr()
F7::TypeSmartAnswer()
F8::ToggleRecording()
F9::PlayRecording()
F10::StopPlayback()
F11::ToggleStatusPanel()
F12::ToggleControlWindow()
Esc::QuitScript()

ApplyAppIcon() {
    global appIconPath
    if FileExist(appIconPath) {
        try TraySetIcon(appIconPath)
    }
}

ApplyGuiIcons() {
    global appIconPath, statusGui, journalGui, controlGui
    if !FileExist(appIconPath)
        return
    try SetWindowIcon(statusGui.Hwnd, appIconPath)
    try SetWindowIcon(journalGui.Hwnd, appIconPath)
    try SetWindowIcon(controlGui.Hwnd, appIconPath)
}

SetWindowIcon(hwnd, iconPath) {
    hIconBig := LoadPicture(iconPath, "Icon1 w32 h32", &imgType)
    hIconSmall := LoadPicture(iconPath, "Icon1 w16 h16", &imgType2)
    if hIconBig
        SendMessage(0x80, 1, hIconBig,, "ahk_id " hwnd) ; WM_SETICON, ICON_BIG
    if hIconSmall
        SendMessage(0x80, 0, hIconSmall,, "ahk_id " hwnd) ; WM_SETICON, ICON_SMALL
}

UnlockStatusPanel() {
    global statusPanelFrozen
    statusPanelFrozen := false
}

GetOcrObjectScreenCenter(obj, &screenX, &screenY) {
    if !IsObject(obj)
        return false

    try {
        x := obj.x + obj.w / 2
        y := obj.y + obj.h / 2

        if obj.HasProp("Relative") {
            rel := obj.Relative

            if rel.HasProp("x")
                x += rel.x

            if rel.HasProp("y")
                y += rel.y

            if rel.HasProp("CoordMode") && rel.HasProp("hWnd") {
                if rel.CoordMode = "Window" {
                    WinGetPos(&wx, &wy,,, rel.hWnd)
                    x += wx
                    y += wy
                } else if rel.CoordMode = "Client" {
                    WinGetClientPos(&cx, &cy,,, rel.hWnd)
                    x += cx
                    y += cy
                }
            }
        }

        screenX := Round(x)
        screenY := Round(y)
        return true
    } catch {
        return false
    }
}

GetOcrObjectScreenRect(
    obj,
    &screenX,
    &screenY,
    &screenW,
    &screenH
) {
    if !IsObject(obj)
        return false

    try {
        x := obj.x
        y := obj.y
        w := obj.w
        h := obj.h

        if obj.HasProp("Relative") {
            rel := obj.Relative

            if rel.HasProp("x")
                x += rel.x

            if rel.HasProp("y")
                y += rel.y

            if rel.HasProp("CoordMode") &&
                rel.HasProp("hWnd") {

                if rel.CoordMode = "Window" {
                    WinGetPos(
                        &wx,
                        &wy,
                        ,
                        ,
                        rel.hWnd
                    )

                    x += wx
                    y += wy

                } else if rel.CoordMode = "Client" {
                    WinGetClientPos(
                        &cx,
                        &cy,
                        ,
                        ,
                        rel.hWnd
                    )

                    x += cx
                    y += cy
                }
            }
        }

        screenX := Round(x)
        screenY := Round(y)
        screenW := Max(1, Round(w))
        screenH := Max(1, Round(h))

        return true

    } catch {
        return false
    }
}


HideStatusForOcr() {
    global statusGui, statusVisible
    global journalGui, journalVisible

    state := {
        statusWasVisible: statusVisible,
        journalWasVisible: journalVisible
    }

    if statusVisible
        statusGui.Hide()

    if journalVisible
        journalGui.Hide()

    ; Даём Windows успеть убрать оба окна из OCR-кадра.
    if statusVisible || journalVisible
        Sleep(45)

    return state
}

RestoreStatusAfterOcr(state) {
    global statusGui, statusVisible
    global journalGui, journalVisible

    if !IsObject(state)
        return

    if state.statusWasVisible && statusVisible {
        statusGui.Show(
            "x20 y20 w500 h370 NoActivate"
        )
    }

    if state.journalWasVisible && journalVisible {
        journalGui.Show(
            "x20 y405 w500 h205 NoActivate"
        )
    }
}

EnsureF4ScreenshotDir() {
    global f4ScreenshotDir

    if !DirExist(f4ScreenshotDir)
        DirCreate(f4ScreenshotDir)
}

SafeScreenshotFilePart(value) {
    value := CleanRememberedAnswerText(value)

    ; Кавычку убираем отдельно, чтобы не было проблем
    ; с экранированием строк в AutoHotkey v2.
    value := StrReplace(
        value,
        Chr(34),
        "_"
    )

    ; Остальные недопустимые символы имени файла Windows.
    value := RegExReplace(
        value,
        "[\\/:*?<>|]",
        "_"
    )

    value := RegExReplace(
        value,
        "\s+",
        " "
    )

    value := Trim(value)

    if value = ""
        value := "F4"

    if StrLen(value) > 42
        value := SubStr(value, 1, 42)

    return value
}


GdipStartForF4() {
    static token := 0

    if token
        return token

    try {
        DllCall(
            "kernel32\LoadLibraryW",
            "WStr",
            "gdiplus.dll",
            "Ptr"
        )

        startupInput :=
            Buffer(
                A_PtrSize = 8
                    ? 24
                    : 16,
                0
            )

        NumPut(
            "UInt",
            1,
            startupInput,
            0
        )

        status :=
            DllCall(
                "gdiplus\GdiplusStartup",
                "UPtr*",
                &token,
                "Ptr",
                startupInput.Ptr,
                "Ptr",
                0,
                "UInt"
            )

        if status != 0 {
            token := 0
            return 0
        }

        return token

    } catch {
        token := 0
        return 0
    }
}

SaveHBitmapAsPng(hBitmap, filePath) {
    global f4ScreenshotLastError

    f4ScreenshotLastError := ""

    if !GdipStartForF4() {
        f4ScreenshotLastError :=
            "Не удалось запустить Windows GDI+."
        return false
    }

    pBitmap := 0

    try {
        status :=
            DllCall(
                "gdiplus\GdipCreateBitmapFromHBITMAP",
                "Ptr",
                hBitmap,
                "Ptr",
                0,
                "Ptr*",
                &pBitmap,
                "UInt"
            )

        if status != 0 || !pBitmap {
            f4ScreenshotLastError :=
                "GDI+ не создал изображение. Код " .
                status
            return false
        }

        pngClsid := Buffer(16, 0)

        clsidStatus :=
            DllCall(
                "ole32\CLSIDFromString",
                "WStr",
                "{557CF406-1A04-11D3-9A73-0000F81EF32E}",
                "Ptr",
                pngClsid.Ptr,
                "Int"
            )

        if clsidStatus != 0 {
            f4ScreenshotLastError :=
                "Не удалось получить PNG-кодек."
            return false
        }

        saveStatus :=
            DllCall(
                "gdiplus\GdipSaveImageToFile",
                "Ptr",
                pBitmap,
                "WStr",
                filePath,
                "Ptr",
                pngClsid.Ptr,
                "Ptr",
                0,
                "UInt"
            )

        if saveStatus != 0 {
            f4ScreenshotLastError :=
                "GDI+ не сохранил PNG. Код " .
                saveStatus
            return false
        }

        if !FileExist(filePath) {
            f4ScreenshotLastError :=
                "PNG не появился после сохранения."
            return false
        }

        return true

    } catch as err {
        f4ScreenshotLastError :=
            "Ошибка GDI+: " .
            err.Message
        return false

    } finally {
        if pBitmap {
            try DllCall(
                "gdiplus\GdipDisposeImage",
                "Ptr",
                pBitmap
            )
        }
    }
}

CaptureScreenRectNativePng(
    left,
    top,
    width,
    height,
    markX,
    markY,
    markW,
    markH,
    filePath
) {
    global f4ScreenshotLastError

    f4ScreenshotLastError := ""

    hdcScreen := 0
    hdcMem := 0
    hBitmap := 0
    oldBitmap := 0
    pen := 0
    oldPen := 0
    oldBrush := 0

    try {
        hdcScreen :=
            DllCall(
                "user32\GetDC",
                "Ptr",
                0,
                "Ptr"
            )

        if !hdcScreen {
            f4ScreenshotLastError :=
                "Windows не дал доступ к экрану."
            return false
        }

        hdcMem :=
            DllCall(
                "gdi32\CreateCompatibleDC",
                "Ptr",
                hdcScreen,
                "Ptr"
            )

        if !hdcMem {
            f4ScreenshotLastError :=
                "Не удалось создать GDI-контекст."
            return false
        }

        hBitmap :=
            DllCall(
                "gdi32\CreateCompatibleBitmap",
                "Ptr",
                hdcScreen,
                "Int",
                width,
                "Int",
                height,
                "Ptr"
            )

        if !hBitmap {
            f4ScreenshotLastError :=
                "Не удалось создать bitmap."
            return false
        }

        oldBitmap :=
            DllCall(
                "gdi32\SelectObject",
                "Ptr",
                hdcMem,
                "Ptr",
                hBitmap,
                "Ptr"
            )

        copied :=
            DllCall(
                "gdi32\BitBlt",
                "Ptr",
                hdcMem,
                "Int",
                0,
                "Int",
                0,
                "Int",
                width,
                "Int",
                height,
                "Ptr",
                hdcScreen,
                "Int",
                left,
                "Int",
                top,
                "UInt",
                0x00CC0020,
                "Int"
            )

        if !copied {
            f4ScreenshotLastError :=
                "Windows не смог скопировать экран."
            return false
        }

        ; Красная рамка показывает точный OCR-прямоугольник.
        pen :=
            DllCall(
                "gdi32\CreatePen",
                "Int",
                0,
                "Int",
                3,
                "UInt",
                0x000000FF,
                "Ptr"
            )

        if pen {
            oldPen :=
                DllCall(
                    "gdi32\SelectObject",
                    "Ptr",
                    hdcMem,
                    "Ptr",
                    pen,
                    "Ptr"
                )

            nullBrush :=
                DllCall(
                    "gdi32\GetStockObject",
                    "Int",
                    5,
                    "Ptr"
                )

            oldBrush :=
                DllCall(
                    "gdi32\SelectObject",
                    "Ptr",
                    hdcMem,
                    "Ptr",
                    nullBrush,
                    "Ptr"
                )

            DllCall(
                "gdi32\Rectangle",
                "Ptr",
                hdcMem,
                "Int",
                markX,
                "Int",
                markY,
                "Int",
                markX + markW,
                "Int",
                markY + markH
            )

            if oldBrush {
                DllCall(
                    "gdi32\SelectObject",
                    "Ptr",
                    hdcMem,
                    "Ptr",
                    oldBrush
                )
            }

            if oldPen {
                DllCall(
                    "gdi32\SelectObject",
                    "Ptr",
                    hdcMem,
                    "Ptr",
                    oldPen
                )
            }
        }

        ; Bitmap больше не должен быть выбран в DC перед GDI+.
        if oldBitmap {
            DllCall(
                "gdi32\SelectObject",
                "Ptr",
                hdcMem,
                "Ptr",
                oldBitmap
            )

            oldBitmap := 0
        }

        return SaveHBitmapAsPng(
            hBitmap,
            filePath
        )

    } catch as err {
        f4ScreenshotLastError :=
            "Снимок Windows: " .
            err.Message
        return false

    } finally {
        if oldBrush && hdcMem {
            try DllCall(
                "gdi32\SelectObject",
                "Ptr",
                hdcMem,
                "Ptr",
                oldBrush
            )
        }

        if oldPen && hdcMem {
            try DllCall(
                "gdi32\SelectObject",
                "Ptr",
                hdcMem,
                "Ptr",
                oldPen
            )
        }

        if oldBitmap && hdcMem {
            try DllCall(
                "gdi32\SelectObject",
                "Ptr",
                hdcMem,
                "Ptr",
                oldBitmap
            )
        }

        if pen {
            try DllCall(
                "gdi32\DeleteObject",
                "Ptr",
                pen
            )
        }

        if hBitmap {
            try DllCall(
                "gdi32\DeleteObject",
                "Ptr",
                hBitmap
            )
        }

        if hdcMem {
            try DllCall(
                "gdi32\DeleteDC",
                "Ptr",
                hdcMem
            )
        }

        if hdcScreen {
            try DllCall(
                "user32\ReleaseDC",
                "Ptr",
                0,
                "Ptr",
                hdcScreen
            )
        }
    }
}

SaveRecognizedF4Screenshot(
    recognizedObj,
    recognizedText
) {
    global f4ScreenshotEnabled
    global f4ScreenshotDir
    global f4ScreenshotLastError

    f4ScreenshotLastError := ""

    if !f4ScreenshotEnabled {
        f4ScreenshotLastError :=
            "Снимки F4 выключены."
        return ""
    }

    if !IsObject(recognizedObj) {
        f4ScreenshotLastError :=
            "Нет OCR-объекта для снимка."
        return ""
    }

    if !GetOcrObjectScreenRect(
        recognizedObj,
        &objX,
        &objY,
        &objW,
        &objH
    ) {
        f4ScreenshotLastError :=
            "Не удалось получить экранные координаты OCR."
        return ""
    }

    try {
        EnsureF4ScreenshotDir()

        ; Контекст вокруг подтверждённого ответа.
        padX := 90
        padY := 60

        left := objX - padX
        top := objY - padY
        w := objW + padX * 2
        h := objH + padY * 2

        if w < 500 {
            extra := 500 - w
            left -= Floor(extra / 2)
            w := 500
        }

        if h < 180 {
            extra := 180 - h
            top -= Floor(extra / 2)
            h := 180
        }

        virtualLeft := SysGet(76)
        virtualTop := SysGet(77)
        virtualWidth := SysGet(78)
        virtualHeight := SysGet(79)

        virtualRight :=
            virtualLeft +
            virtualWidth

        virtualBottom :=
            virtualTop +
            virtualHeight

        if left < virtualLeft
            left := virtualLeft

        if top < virtualTop
            top := virtualTop

        if left + w > virtualRight
            w := virtualRight - left

        if top + h > virtualBottom
            h := virtualBottom - top

        if w < 1 || h < 1 {
            f4ScreenshotLastError :=
                "OCR-область оказалась вне экрана."
            return ""
        }

        stamp :=
            FormatTime(
                A_Now,
                "yyyyMMdd_HHmmss"
            ) .
            "_" .
            Format(
                "{:03}",
                Mod(A_TickCount, 1000)
            )

        safeLabel :=
            SafeScreenshotFilePart(
                recognizedText
            )

        fullPath :=
            f4ScreenshotDir .
            "\" .
            stamp .
            "_F4_CONFIRMED_" .
            safeLabel .
            ".png"

        markX := objX - left
        markY := objY - top

        overlayState :=
            HideStatusForOcr()

        try {
            Sleep(55)

            saved :=
                CaptureScreenRectNativePng(
                    left,
                    top,
                    w,
                    h,
                    markX,
                    markY,
                    objW,
                    objH,
                    fullPath
                )
        } finally {
            RestoreStatusAfterOcr(
                overlayState
            )
        }

        if saved
            return fullPath

        return ""

    } catch as err {
        f4ScreenshotLastError :=
            "Снимок F4: " .
            err.Message
        return ""
    }
}


LogEvent(message) {
    global journalEntries, journalMaxEntries, journalTextCtrl

    message := String(message)
    message := StrReplace(message, "`r", " ")
    message := StrReplace(message, "`n", " / ")
    message := RegExReplace(message, "\s+", " ")
    message := Trim(message)

    if StrLen(message) > 92
        message := SubStr(message, 1, 89) . "..."

    stamp := FormatTime(A_Now, "HH:mm:ss")
    journalEntries.Push(stamp . "  " . message)

    while journalEntries.Length > journalMaxEntries
        journalEntries.RemoveAt(1)

    output := ""
    for i, entry in journalEntries {
        if i > 1
            output .= "`n"
        output .= entry
    }

    journalTextCtrl.Text := output
}

ShortLogText(value, maxLen:=42) {
    value := CleanRememberedAnswerText(value)
    if StrLen(value) > maxLen
        return SubStr(value, 1, maxLen - 3) . "..."
    return value
}

PauseRecordingForEditor() {
    global recording, recordingPaused

    if !recording
        return 0

    recordingPaused := true
    LogEvent("ЗАПИСЬ НА ПАУЗЕ: редактор F4")

    return A_TickCount
}

ResumeRecordingAfterEditor(pauseStarted) {
    global recording, recordingPaused, recordStart

    if !recording {
        recordingPaused := false
        return
    }

    if pauseStarted > 0 {
        pausedMs := A_TickCount - pauseStarted

        ; Полностью исключаем время, проведённое в редакторе,
        ; из временной шкалы записанного макроса.
        recordStart += pausedMs
    }

    recordingPaused := false
    LogEvent("ЗАПИСЬ ПРОДОЛЖЕНА после редактора F4")
}

; ============================================================
; ОТВЕТЫ ПО ТЕКСТУ
;
; F4 во время записи:
;   1) наведите мышь на выбранный вариант ИЛИ кнопку ("Далее");
;   2) нажмите F4 ВМЕСТО обычного клика;
;   3) OCR запомнит полный текст и программа сама нажмёт его.
;
; При воспроизведении координата не используется:
; программа ждёт появления этого же текста и кликает по нему.
; Это устойчивее к сдвигам/задержкам загрузки страницы.
; ============================================================

RememberAnswerByText() {
    global recording, playing, events, recordStart
    global lastAction, ocrAvailable, statusTextCtrl
    global ignoreMouseCapture, ignoreKeyboardCapture
    global f4ScreenshotLastError

    if playing {
        LogEvent("F4 пропущен: сейчас идёт воспроизведение")
        return
    }

    if !recording {
        LogEvent("F4: сначала включите запись F8")
        statusTextCtrl.Text :=
            "ℹ ОТВЕТ ПО ТЕКСТУ`n`n" .
            "F4 используется во время записи.`n" .
            "Нажмите F8, наведите мышь на ответ`n" .
            "и вместо обычного клика нажмите F4."
        return
    }

    if !ocrAvailable {
        LogEvent("F4 ошибка: OCR недоступен")
        statusTextCtrl.Text :=
            "❌ OCR НЕ ДОСТУПЕН`n`n" .
            "Для F4 нужен OCR.ahk."
        return
    }

    ; Именно эту точку пользователь выбрал внутри строки ответа.
    MouseGetPos(&anchorX, &anchorY)

    LogEvent(
        "F4: распознаю ответ у X=" .
        anchorX .
        ", Y=" .
        anchorY
    )

    statusTextCtrl.Text :=
        "🔎 F4 — РАСПОЗНАЮ ОТВЕТ`n`n" .
        "Не двигайте мышь примерно 1 секунду."

    captured := CaptureAnswerTextAtCursor()

    if !IsObject(captured) || captured.text = "" {
        LogEvent("F4 неудача: текст под курсором не распознан")

        statusTextCtrl.Text :=
            "⚠ F4 НЕ УВИДЕЛ ТЕКСТ`n`n" .
            "Наведите мышь на буквы ответа,`n" .
            "дождитесь загрузки и нажмите F4 снова."

        return
    }

    ; --------------------------------------------------------
    ; РУЧНАЯ ПРОВЕРКА РАСПОЗНАННОГО ТЕКСТА
    ;
    ; OCR иногда путает одну букву/слово. Поэтому перед сохранением
    ; показываем распознанную фразу пользователю и разрешаем её
    ; исправить. Клики и клавиши самого редактора в макрос не пишутся.
    ; --------------------------------------------------------

    originalOcrText := captured.text

    ; ВАЖНО: пока пользователь редактирует текст,
    ; запись полностью заморожена.
    pauseStarted := PauseRecordingForEditor()

    ignoreKeyboardCapture := true
    ignoreMouseCapture := true

    try {
        editResult := InputBox(
            "Проверьте распознанный текст ответа.`n`n" .
            "Пока это окно открыто, запись ПОЛНОСТЬЮ НА ПАУЗЕ.`n" .
            "Мышь, клавиатура, колесо и время не записываются.`n`n" .
            "Исправьте ошибки OCR и нажмите OK.`n" .
            "Отмена = не сохранять этот F4.",
            "F4 — проверить текст ответа",
            "w760 h250",
            originalOcrText
        )
    } finally {
        ignoreKeyboardCapture := false
        ignoreMouseCapture := false
        ResumeRecordingAfterEditor(pauseStarted)
    }

    if editResult.Result != "OK" {
        LogEvent(
            "F4 отменён: текст не сохранён"
        )

        statusTextCtrl.Text :=
            "ℹ F4 ОТМЕНЁН`n`n" .
            "Распознанный ответ не был сохранён."

        return
    }

    editedText :=
        CleanRememberedAnswerText(
            editResult.Value
        )

    ; Показываем/сохраняем уже очищенную форму,
    ; чтобы случайный "\." не отличался от "." на странице.

    if editedText = "" {
        LogEvent(
            "F4 не сохранён: после редактирования текст пуст"
        )

        statusTextCtrl.Text :=
            "⚠ F4 НЕ СОХРАНЁН`n`n" .
            "После редактирования текст пуст."

        return
    }

    captured.text := editedText

    ; --------------------------------------------------------
    ; СКРИНШОТ ТОЛЬКО ПОДТВЕРЖДЁННОГО ТЕКСТА
    ;
    ; Теперь, когда пользователь исправил/подтвердил текст,
    ; ещё раз ищем именно ЭТУ фразу на странице.
    ; Если программа находит её как отдельный OCR-объект,
    ; сохраняем снимок именно этого ответа.
    ;
    ; Сырой OCR до редактора больше НЕ фотографируется.
    ; --------------------------------------------------------

    confirmedScreenshotPath := ""
    confirmedObj := 0

    try {
        confirmedObj :=
            FindConfirmedF4ObjectOnScreen(
                captured.text
            )
    } catch as err {
        LogEvent(
            "F4 подтверждённый поиск ошибка: " .
            ShortLogText(
                err.Message,
                40
            )
        )
    }

    if IsObject(confirmedObj) {
        confirmedScreenshotPath :=
            SaveRecognizedF4Screenshot(
                confirmedObj,
                captured.text
            )

        if confirmedScreenshotPath != "" {
            LogEvent(
                "F4 СКРИН ПРАВИЛЬНОГО ОТВЕТА: " .
                confirmedScreenshotPath
            )
        } else {
            if f4ScreenshotLastError != ""
                shotErrorText := f4ScreenshotLastError
            else
                shotErrorText := "неизвестная ошибка"

            LogEvent(
                "F4 снимок НЕ сохранён: " .
                shotErrorText
            )
        }
    } else {
        LogEvent(
            "F4 подтверждённый текст не найден на экране — снимка нет"
        )
    }

    if editedText != originalOcrText {
        LogEvent(
            "F4 текст исправлен: «" .
            ShortLogText(
                editedText,
                54
            ) .
            "»"
        )
    } else {
        LogEvent(
            "F4 текст подтверждён без изменений"
        )
    }

    ; Защита от пустого/случайного результата.
    normalizedCaptured := NormalizeAnswerForMatch(captured.text)

    if StrLen(normalizedCaptured) < 1 {
        LogEvent("F4: пустой нормализованный ответ")
        return
    }

    ; Смещение курсора относительно центра OCR-строки.
    ; Оно позволяет повторить клик ВНУТРИ той же строки,
    ; даже если сама строка потом сместится на странице.
    dx := 0
    dy := 0

    ; Если подтверждённый текст найден заново, привязываем
    ; смещение именно к нему. Иначе используем исходный OCR-объект.
    offsetObj := 0

    if IsObject(confirmedObj) {
        offsetObj := confirmedObj
    } else if captured.HasOwnProp("line") &&
        IsObject(captured.line) {
        offsetObj := captured.line
    }

    if IsObject(offsetObj) {
        if GetOcrObjectScreenCenter(
            offsetObj,
            &lineCenterX,
            &lineCenterY
        ) {
            dx := anchorX - lineCenterX
            dy := anchorY - lineCenterY
        }
    }

    semanticRole :=
        RegExMatch(
            StrLower(captured.text),
            "^(далее|продолжить|следующий|next)$"
        )
            ? "кнопка"
            : "ответ"

    LogEvent(
        "F4 сохраняет " .
        semanticRole .
        ": «" .
        ShortLogText(captured.text, 46) .
        "»"
    )

    events.Push({
        kind: "answer_text",
        t: A_TickCount - recordStart,
        text: captured.text,

        ; Абсолютная точка, куда пользователь навёл мышь.
        x: anchorX,
        y: anchorY,

        ; Смещение относительно распознанной строки.
        dx: dx,
        dy: dy,

        ; Тип клика — сейчас обычная ЛКМ.
        button: "Left",
        clicks: 1
    })

    lastAction :=
        "Ответ по тексту: " .
        captured.text

    LogEvent(
        "F4 запомнил: " .
        ShortLogText(captured.text) .
        " | X=" .
        anchorX .
        " Y=" .
        anchorY .
        " | d=" .
        dx .
        "," .
        dy
    )

    ; ВО ВРЕМЯ ЗАПИСИ выбираем ровно ту точку,
    ; на которую пользователь навёл курсор.
    ignoreMouseCapture := true

    try {
        CoordMode("Mouse", "Screen")

        if IsObject(confirmedObj) &&
            GetOcrObjectScreenCenter(
                confirmedObj,
                &confirmedCenterX,
                &confirmedCenterY
            ) {
            ; Нажимаем то, что программа нашла по ПРАВИЛЬНОМУ
            ; подтверждённому тексту, а не исходную точку мыши.
            MouseMove(
                confirmedCenterX,
                confirmedCenterY,
                0
            )

            Sleep(35)
            Click()

            LogEvent(
                "F4 программа нажала подтверждённый ответ X=" .
                confirmedCenterX .
                " Y=" .
                confirmedCenterY
            )
        } else {
            ; Если после ручной правки OCR уже не может найти эту
            ; фразу на экране, не делаем сомнительный клик.
            LogEvent(
                "F4 НЕ НАЖАЛ: подтверждённый текст не найден"
            )

            statusTextCtrl.Text :=
                "⛔ F4 НЕ НАЖАЛ`n`n" .
                "Подтверждённый текст не найден на странице:`n" .
                captured.text .
                "`n`n" .
                "Ничего не выбрано."

            return
        }
    } finally {
        ignoreMouseCapture := false
    }

    if confirmedScreenshotPath != "" {
        shotInfo :=
            "Скриншот правильного ответа сохранён в screenshots\F4`n"
    } else {
        if f4ScreenshotLastError != ""
            shotReason := f4ScreenshotLastError
        else
            shotReason := "неизвестная ошибка"

        shotInfo :=
            "Скриншот НЕ сохранён: " .
            shotReason .
            "`n"
    }

    statusTextCtrl.Text :=
        "✓ F4 ПОДТВЕРЖДЁН`n`n" .
        "Правильный текст:`n" .
        captured.text .
        "`n`n" .
        shotInfo .
        "Скриншот = ответ, который программа нашла по этому тексту.`n" .
        "Клик тоже сделан по этому найденному ответу."
}


CaptureAnswerTextAtCursor() {
    global ocrAvailable, answerCaptureAttempts

    if !ocrAvailable
        return 0

    MouseGetPos(&mx, &my)

    ; Широкая область нужна для длинных вариантов,
    ; которые переносятся на 2-4 строки.
    configs := [
        {w:1200, h:150, scale:1.60, gray:true},
        {w:1400, h:210, scale:1.55, gray:true},
        {w:1500, h:270, scale:1.45, gray:false},
        {w:1600, h:330, scale:1.40, gray:true}
    ]

    maxAttempts :=
        Min(
            answerCaptureAttempts,
            configs.Length
        )

    Loop maxAttempts {
        attempt := A_Index
        cfg := configs[attempt]

        if attempt > 1
            Sleep(150)

        MouseGetPos(&mx, &my)

        left :=
            mx -
            Floor(cfg.w / 2)

        top :=
            my -
            Floor(cfg.h / 2)

        try {
            overlayWasVisible :=
                HideStatusForOcr()

            try {
                options := {
                    scale: cfg.scale,
                    grayscale: cfg.gray
                }

                try {
                    options.lang := "ru-RU"

                    result :=
                        OCR.FromRect(
                            left,
                            top,
                            cfg.w,
                            cfg.h,
                            options
                        )
                } catch {
                    options := {
                        scale: cfg.scale,
                        grayscale: cfg.gray
                    }

                    result :=
                        OCR.FromRect(
                            left,
                            top,
                            cfg.w,
                            cfg.h,
                            options
                        )
                }
            } finally {
                RestoreStatusAfterOcr(
                    overlayWasVisible
                )
            }

            if result.Lines.Length = 0 {
                LogEvent(
                    "F4 OCR " .
                    attempt .
                    "/" .
                    maxAttempts .
                    ": строк нет"
                )
                continue
            }

            ; ВАЖНО:
            ; координаты OCR.FromRect уже экранные,
            ; поэтому сравниваем их напрямую с MouseGetPos.
            anchorIndex := 0
            bestScore := 999999

            for i, line in result.Lines {
                lineText :=
                    CleanRememberedAnswerText(
                        line.Text
                    )

                if lineText = ""
                    continue

                centerY :=
                    line.y +
                    line.h / 2

                verticalDistance :=
                    Abs(
                        centerY -
                        my
                    )

                horizontalGap := 0

                if mx < line.x {
                    horizontalGap :=
                        line.x -
                        mx
                } else if mx > line.x + line.w {
                    horizontalGap :=
                        mx -
                        (line.x + line.w)
                }

                ; Вертикаль важнее горизонтали:
                ; пользователь обычно наводит мышь на сам ответ.
                score :=
                    verticalDistance * 5 +
                    horizontalGap

                if score < bestScore {
                    bestScore := score
                    anchorIndex := i
                }
            }

            if anchorIndex = 0
                continue

            anchorLine :=
                result.Lines[
                    anchorIndex
                ]

            ; Собираем ВСЮ группу перенесённых строк ответа.
            groupStart := anchorIndex
            groupEnd := anchorIndex

            anchorLeft := anchorLine.x
            anchorRight :=
                anchorLine.x +
                anchorLine.w

            ; Сколько пикселей допускаем между строками одного ответа.
            maxGap :=
                Max(
                    18,
                    Round(
                        anchorLine.h *
                        1.15
                    )
                )

            ; ----- вверх -----
            i := anchorIndex - 1

            while i >= 1 {
                prev :=
                    result.Lines[i]

                next :=
                    result.Lines[
                        i + 1
                    ]

                verticalGap :=
                    next.y -
                    (
                        prev.y +
                        prev.h
                    )

                prevRight :=
                    prev.x +
                    prev.w

                horizontalRelated :=
                    (
                        prevRight >=
                        anchorLeft - 90
                    ) &&
                    (
                        prev.x <=
                        anchorRight + 90
                    )

                ; Для переноса строки начало текста обычно близко,
                ; либо строки хотя бы существенно перекрываются.
                indentRelated :=
                    Abs(
                        prev.x -
                        anchorLeft
                    ) <= 170

                if verticalGap > maxGap ||
                    verticalGap < -8 ||
                    !horizontalRelated ||
                    !indentRelated {
                    break
                }

                groupStart := i
                anchorLeft :=
                    Min(
                        anchorLeft,
                        prev.x
                    )
                anchorRight :=
                    Max(
                        anchorRight,
                        prevRight
                    )

                i -= 1
            }

            ; ----- вниз -----
            i := anchorIndex + 1

            while i <= result.Lines.Length {
                prev :=
                    result.Lines[
                        i - 1
                    ]

                next :=
                    result.Lines[i]

                verticalGap :=
                    next.y -
                    (
                        prev.y +
                        prev.h
                    )

                nextRight :=
                    next.x +
                    next.w

                horizontalRelated :=
                    (
                        nextRight >=
                        anchorLeft - 90
                    ) &&
                    (
                        next.x <=
                        anchorRight + 90
                    )

                indentRelated :=
                    Abs(
                        next.x -
                        anchorLeft
                    ) <= 170

                if verticalGap > maxGap ||
                    verticalGap < -8 ||
                    !horizontalRelated ||
                    !indentRelated {
                    break
                }

                groupEnd := i
                anchorLeft :=
                    Min(
                        anchorLeft,
                        next.x
                    )
                anchorRight :=
                    Max(
                        anchorRight,
                        nextRight
                    )

                i += 1
            }

            fullText := ""

            Loop groupEnd - groupStart + 1 {
                line :=
                    result.Lines[
                        groupStart +
                        A_Index -
                        1
                    ]

                lineText :=
                    CleanRememberedAnswerText(
                        line.Text
                    )

                if lineText = ""
                    continue

                if fullText != ""
                    fullText .= " "

                fullText .= lineText
            }

            fullText :=
                CleanRememberedAnswerText(
                    fullText
                )

            if fullText = ""
                continue

            ; Для вычисления dx/dy нужен bounding-box ВСЕЙ фразы.
            groupWords := []

            Loop groupEnd - groupStart + 1 {
                line :=
                    result.Lines[
                        groupStart +
                        A_Index -
                        1
                    ]

                for _, word in line.Words
                    groupWords.Push(word)
            }

            fullObj := 0

            if groupWords.Length > 0 {
                try {
                    rect :=
                        OCR.WordsBoundingRect(
                            groupWords*
                        )

                    ; Небольшой объект с x/y/w/h —
                    ; GetOcrObjectScreenCenter сможет его использовать.
                    fullObj := {
                        x: rect.x,
                        y: rect.y,
                        w: rect.w,
                        h: rect.h
                    }
                }
            }

            LogEvent(
                "F4 OCR ТЕКСТ " .
                attempt .
                "/" .
                maxAttempts .
                ": «" .
                ShortLogText(
                    fullText,
                    54
                ) .
                "»"
            )

            return {
                text: fullText,
                line: IsObject(fullObj)
                    ? fullObj
                    : anchorLine,
                attempt: attempt
            }

        } catch as err {
            LogEvent(
                "F4 OCR " .
                attempt .
                "/" .
                maxAttempts .
                " ошибка: " .
                ShortLogText(
                    err.Message,
                    38
                )
            )
        }
    }

    return 0
}


CleanRememberedAnswerText(value) {
    value := Trim(String(value))
    value := StrReplace(value, "`t", " ")
    value := StrReplace(value, "`r", " ")
    value := StrReplace(value, "`n", " ")
    value := RegExReplace(value, "\s+", " ")

    ; Иногда пользователь/редактор оставляет обратный слеш
    ; перед обычной пунктуацией: \. \, \: \; \( \)
    ; На странице такого слеша нет, поэтому для поиска он мешает.
    ; Удаляем слеш только перед пунктуацией, а обычные слеши в словах
    ; или путях не трогаем.
    value := RegExReplace(
        value,
        "\\(?=[\.\,\:\;\!\?\(\)\[\]\{\}])",
        ""
    )

    return value
}


NormalizeAnswerForMatch(value) {
    value := StrLower(CleanRememberedAnswerText(value))
    value := StrReplace(value, "ё", "е")
    value := RegExReplace(value, "[^\p{L}\p{N}]+", " ")
    value := RegExReplace(value, "\s+", " ")
    return Trim(value)
}

FindConfirmedF4ObjectOnScreen(answerText) {
    overlayState := HideStatusForOcr()

    try {
        try result :=
            OCR.FromWindow(
                "A",
                {
                    lang:"ru-RU",
                    scale:1.45,
                    grayscale:true
                }
            )
        catch
            result :=
                OCR.FromWindow(
                    "A",
                    {
                        scale:1.45,
                        grayscale:true
                    }
                )
    } finally {
        RestoreStatusAfterOcr(
            overlayState
        )
    }

    match :=
        FindBestRememberedAnswer(
            result,
            answerText
        )

    if IsObject(match) &&
        match.HasOwnProp("obj") {
        return match.obj
    }

    return 0
}

FindBestRememberedAnswer(result, answerText) {
    target :=
        NormalizeAnswerForMatch(
            answerText
        )

    if target = ""
        return 0

    exactMatches := []

    ; 1) Сначала проверяем каждую OCR-строку целиком.
    for _, line in result.Lines {
        lineNorm :=
            NormalizeAnswerForMatch(
                line.Text
            )

        if lineNorm = target
            exactMatches.Push(line)
    }

    if exactMatches.Length = 1 {
        return {
            obj: exactMatches[1],
            mode: "точный полный текст"
        }
    }

    if exactMatches.Length > 1 {
        return {
            ambiguous: true,
            count: exactMatches.Length,
            mode: "полный текст найден несколько раз"
        }
    }

    ; 2) Если длинный ответ разбит на несколько OCR-строк,
    ; используем FindStrings с игнорированием переносов.
    cleanAnswer :=
        CleanRememberedAnswerText(
            answerText
        )

    try {
        matches :=
            result.FindStrings(
                cleanAnswer,
                {
                    CaseSense: false,
                    IgnoreLinebreaks: true,
                    AllowOverlap: false
                }
            )

        if matches.Length = 1 {
            return {
                obj: matches[1],
                mode: "полный текст через перенос строк"
            }
        }

        if matches.Length > 1 {
            return {
                ambiguous: true,
                count: matches.Length,
                mode: "полный текст найден несколько раз"
            }
        }
    } catch {
    }

    return 0
}


TryFindRememberedAnswerOnScreen(answerText) {
    overlayWasVisible := HideStatusForOcr()

    try {
        try result :=
            OCR.FromWindow(
                "A",
                {
                    lang:"ru-RU",
                    scale:1.40,
                    grayscale:true
                }
            )
        catch
            result :=
                OCR.FromWindow(
                    "A",
                    {
                        scale:1.40,
                        grayscale:true
                    }
                )
    } finally {
        RestoreStatusAfterOcr(
            overlayWasVisible
        )
    }

    return FindBestRememberedAnswer(
        result,
        answerText
    )
}

DoRememberedAnswerClick(
    match,
    clickDx,
    clickDy,
    fallbackX,
    fallbackY,
    button:="Left",
    clickCount:=1,
    allowFallback:=false,
    recognizedText:=""
) {
    global f4ScreenshotLastError
    if IsObject(match) && match.HasOwnProp("obj") {
        if GetOcrObjectScreenCenter(
            match.obj,
            &centerX,
            &centerY
        ) {
            targetX := Round(centerX + clickDx)
            targetY := Round(centerY + clickDy)

            ; ------------------------------------------------
            ; СКРИНШОТ ПРИ ВОСПРОИЗВЕДЕНИИ F4
            ;
            ; Снимаем именно OCR-объект, который программа
            ; сейчас признала правильным ответом.
            ; Снимок делается ДО клика.
            ; ------------------------------------------------
            playbackShot := ""

            if recognizedText != "" {
                playbackShot :=
                    SaveRecognizedF4Screenshot(
                        match.obj,
                        recognizedText
                    )

                if playbackShot != "" {
                    LogEvent(
                        "F4 PLAY СКРИН: " .
                        playbackShot
                    )
                } else {
                    if f4ScreenshotLastError != ""
                        shotErr := f4ScreenshotLastError
                    else
                        shotErr := "неизвестная ошибка"

                    LogEvent(
                        "F4 PLAY СКРИН НЕ СОХРАНЁН: " .
                        shotErr
                    )
                }
            }

            CoordMode("Mouse", "Screen")
            MouseMove(targetX, targetY, 0)
            Sleep(45)

            MouseClick(
                button,
                targetX,
                targetY,
                clickCount,
                0
            )

            return {
                ok: true,
                x: targetX,
                y: targetY,
                method: "точный OCR + сохранённое смещение",
                screenshot: playbackShot
            }
        }
    }

    ; В строгом режиме сюда не попадём.
    if allowFallback && (fallbackX > 0 || fallbackY > 0) {
        CoordMode("Mouse", "Screen")
        MouseMove(fallbackX, fallbackY, 0)
        Sleep(45)

        MouseClick(
            button,
            fallbackX,
            fallbackY,
            clickCount,
            0
        )

        return {
            ok: true,
            x: fallbackX,
            y: fallbackY,
            method: "запасные X/Y"
        }
    }

    return {ok:false}
}


FindAndClickRememberedAnswer(
    answerText,
    clickDx:=0,
    clickDy:=0,
    fallbackX:=0,
    fallbackY:=0,
    button:="Left",
    clickCount:=1
) {
    global ocrAvailable
    global stopRequested
    global statusTextCtrl
    global answerFindTimeoutMs
    global answerAutoScrollEnabled
    global answerScrollSteps
    global answerScrollNotches
    global answerScrollPauseMs
    global answerStrictMode

    shortAnswer := ShortLogText(answerText, 46)

    if !ocrAvailable {
        LogEvent(
            "СТОП: OCR недоступен, ответ не нажимаю"
        )

        statusTextCtrl.Text :=
            "⛔ БЕЗОПАСНАЯ ОСТАНОВКА`n`n" .
            "OCR недоступен.`n" .
            "Ответ не был нажат.`n`n" .
            "Искал: " . answerText

        return false
    }

    LogEvent(
        "Ищу ПОЛНЫЙ текст: «" .
        shortAnswer .
        "»"
    )

    deadline := A_TickCount + answerFindTimeoutMs

    ; --------------------------------------------------------
    ; Функция локальной проверки текущего экрана
    ; --------------------------------------------------------

    TryCurrentScreen() {
        match := TryFindRememberedAnswerOnScreen(answerText)

        if IsObject(match) {
            if match.HasOwnProp("ambiguous") && match.ambiguous {
                LogEvent(
                    "НЕ НАЖИМАЮ: одинаковых ответов " .
                    match.count .
                    " — «" .
                    shortAnswer .
                    "»"
                )

                return {
                    state: "ambiguous",
                    match: match
                }
            }

            if match.HasOwnProp("obj") {
                clickResult := DoRememberedAnswerClick(
                    match,
                    clickDx,
                    clickDy,
                    fallbackX,
                    fallbackY,
                    button,
                    clickCount,
                    false,
                    answerText
                )

                if clickResult.ok {
                    if clickResult.HasOwnProp("screenshot") &&
                        clickResult.screenshot != "" {
                        shotSuffix := " | PNG сохранён"
                    } else {
                        shotSuffix := " | PNG нет"
                    }

                    LogEvent(
                        "ТОЧНО НАЖАЛ: «" .
                        shortAnswer .
                        "» X=" .
                        clickResult.x .
                        " Y=" .
                        clickResult.y .
                        shotSuffix
                    )

                    return {
                        state: "clicked",
                        click: clickResult
                    }
                }
            }
        }

        return {state:"not_found"}
    }

    ; --------------------------------------------------------
    ; 1. Несколько попыток без прокрутки
    ; --------------------------------------------------------

    Loop 4 {
        if stopRequested
            return false

        try {
            probe := TryCurrentScreen()

            if probe.state = "clicked"
                return true

            if probe.state = "ambiguous" {
                statusTextCtrl.Text :=
                    "⛔ НЕ НАЖИМАЮ`n`n" .
                    "На экране несколько одинаковых вариантов:`n" .
                    answerText .
                    "`n`n" .
                    "Лучше остановиться, чем выбрать не тот."

                return false
            }
        } catch as err {
            LogEvent(
                "OCR ошибка: " .
                ShortLogText(err.Message, 40)
            )
        }

        Sleep(220)
    }

    ; --------------------------------------------------------
    ; 2. Прокрутка вниз
    ; --------------------------------------------------------

    downStepsDone := 0

    if answerAutoScrollEnabled {
        LogEvent(
            "Полного текста не видно — листаю вниз"
        )

        Loop answerScrollSteps {
            if stopRequested
                return false

            if A_TickCount >= deadline
                break

            Loop answerScrollNotches
                SendEvent("{WheelDown}")

            downStepsDone += 1
            Sleep(answerScrollPauseMs)

            try {
                probe := TryCurrentScreen()

                if probe.state = "clicked" {
                    LogEvent(
                        "Нашёл после ↓" .
                        downStepsDone
                    )
                    return true
                }

                if probe.state = "ambiguous" {
                    statusTextCtrl.Text :=
                        "⛔ НЕ НАЖИМАЮ`n`n" .
                        "Нашёл несколько одинаковых ответов:`n" .
                        answerText

                    return false
                }
            } catch {
            }
        }
    }

    ; --------------------------------------------------------
    ; 3. Вернуться и проверить выше
    ; --------------------------------------------------------

    if answerAutoScrollEnabled {
        Loop downStepsDone {
            Loop answerScrollNotches
                SendEvent("{WheelUp}")
            Sleep(80)
        }

        LogEvent(
            "Проверяю выше исходной позиции"
        )

        upSteps := Min(answerScrollSteps, 5)

        Loop upSteps {
            if stopRequested
                return false

            if A_TickCount >= deadline
                break

            Loop answerScrollNotches
                SendEvent("{WheelUp}")

            Sleep(answerScrollPauseMs)

            try {
                probe := TryCurrentScreen()

                if probe.state = "clicked" {
                    LogEvent(
                        "Нашёл после ↑" .
                        A_Index
                    )
                    return true
                }

                if probe.state = "ambiguous" {
                    statusTextCtrl.Text :=
                        "⛔ НЕ НАЖИМАЮ`n`n" .
                        "Несколько одинаковых ответов:`n" .
                        answerText

                    return false
                }
            } catch {
            }
        }
    }

    ; --------------------------------------------------------
    ; 4. НИКАКИХ запасных координат в строгом режиме
    ; --------------------------------------------------------

    LogEvent(
        "СТОП: полный текст не найден — ничего не нажато"
    )

    statusTextCtrl.Text :=
        "⛔ ОТВЕТ НЕ ПОДТВЕРЖДЁН`n`n" .
        "Полный текст не найден:`n" .
        answerText .
        "`n`n" .
        "Ничего не нажимаю.`n" .
        "Проверьте журнал."

    return false
}


; ============================================================
; ПРОФИЛЬНЫЕ ПОЛЯ В МАКРОСЕ
; F2 = возраст текущего профиля
; F3 = пол текущего профиля
; ============================================================

InsertProfileAgeHotkey() {
    global recording, playing, events, recordStart, lastAction

    if playing
        return

    if recording {
        events.Push({kind:"profile_age", t:A_TickCount-recordStart})
        lastAction := "Метка профиля: возраст"
        LogEvent("F2: метка возраста профиля")
    }

    InsertCurrentProfileAge()
}

InsertProfileSexHotkey() {
    global recording, playing, events, recordStart, lastAction

    if playing
        return

    ; F3 больше не запоминает координаты мыши.
    ; Во время записи сохраняется только специальная команда,
    ; а нужный radio-вариант каждый раз находится OCR-ом заново.
    if recording {
        events.Push({
            kind: "profile_sex",
            t: A_TickCount - recordStart
        })
        lastAction := "Метка профиля: пол (OCR)"
        LogEvent("F3: метка пола профиля — OCR")
    }

    InsertCurrentProfileSex()
}

InsertCurrentProfileAge() {
    global testAge, ignoreKeyboardCapture

    ignoreKeyboardCapture := true
    try {
        SendText(String(testAge))
    } finally {
        ignoreKeyboardCapture := false
    }
}

NormalizeGenderOcrText(text) {
    text := StrLower(String(text))
    text := StrReplace(text, "ё", "е")

    ; Частые случаи, когда OCR смешивает похожие латинские
    ; и кириллические символы в одном слове.
    replacements := Map(
        "a", "а",
        "c", "с",
        "e", "е",
        "k", "к",
        "m", "м",
        "o", "о",
        "p", "р",
        "t", "т",
        "x", "х",
        "y", "у"
    )

    for from, to in replacements
        text := StrReplace(text, from, to)

    ; Для сравнения оставляем только буквы.
    return RegExReplace(text, "[^а-я]", "")
}

GenderEditDistance(a, b) {
    a := String(a)
    b := String(b)
    aLen := StrLen(a)
    bLen := StrLen(b)

    prev := []
    Loop bLen + 1
        prev.Push(A_Index - 1)

    Loop aLen {
        i := A_Index
        curr := [i]
        aChar := SubStr(a, i, 1)

        Loop bLen {
            j := A_Index
            cost := aChar = SubStr(b, j, 1) ? 0 : 1
            curr.Push(Min(
                curr[j] + 1,
                prev[j + 1] + 1,
                prev[j] + cost
            ))
        }

        prev := curr
    }

    return prev[bLen + 1]
}

GenderCandidateScore(text, targetSex) {
    normalized := NormalizeGenderOcrText(text)
    target := NormalizeGenderOcrText(targetSex)

    if normalized = "" || target = ""
        return 0

    if normalized = target
        return 100

    if InStr(normalized, target)
        return 96

    root := targetSex = "Женский" ? "жен" : "муж"
    if InStr(normalized, root)
        return 88

    ; OCR иногда ошибается на 1–2 символа, особенно на тёмной теме.
    ; Для отдельного короткого слова разрешаем небольшую погрешность.
    if StrLen(normalized) >= 5 && StrLen(normalized) <= 10 {
        distance := GenderEditDistance(normalized, target)
        if distance <= 1
            return 82
        if distance <= 2
            return 72
    }

    return 0
}

FindGenderCandidate(result, targetSex) {
    best := ""
    bestScore := 0

    ; Сначала строки: так клик обычно приходится по центру label.
    for line in result.Lines {
        score := GenderCandidateScore(line.Text, targetSex)
        if score > bestScore {
            best := line
            bestScore := score
        }
    }

    ; Затем отдельные слова — полезно, если OCR объединил строку странно.
    for word in result.Words {
        score := GenderCandidateScore(word.Text, targetSex)
        if score > bestScore {
            best := word
            bestScore := score
        }
    }

    return bestScore >= 72 ? best : ""
}

InsertCurrentProfileSex() {
    global testSex, ocrAvailable, statusTextCtrl
    global controlGui, controlVisible

    ; Пол больше НИКОГДА не вводится как текст.
    ; Единственный способ — распознать нужный вариант и нажать его.
    if testSex != "Мужской" && testSex != "Женский" {
        LogEvent("F3: неподдерживаемое значение пола: " . testSex)
        statusTextCtrl.Text :=
            "⛔ ПОЛ НЕ ВЫБРАН`n`n" .
            "Поддерживаются только Мужской / Женский."
        return false
    }

    if !ocrAvailable {
        LogEvent("F3: OCR недоступен — пол не выбран")
        statusTextCtrl.Text :=
            "⛔ ПОЛ НЕ ВЫБРАН`n`n" .
            "OCR недоступен.`n" .
            "Текстом пол не вводится."
        return false
    }

    ; Запоминаем окно формы ДО скрытия наших панелей.
    targetHwnd := WinExist("A")
    if !targetHwnd {
        LogEvent("F3: активное окно не найдено")
        return false
    }

    overlayState := HideStatusForOcr()
    controlWasVisible := controlVisible

    if controlWasVisible {
        controlGui.Hide()
        Sleep(45)
    }

    found := ""
    recognizedSample := ""

    try {
        ; Несколько проходов нужны для светлой/тёмной темы и браузеров
        ; с аппаратным рендерингом. Никакого точного FindString(),
        ; который раньше падал с "target string ... was not found".
        passes := [
            {scale:1.55, grayscale:true,  invertcolors:false, mode:4},
            {scale:1.80, grayscale:true,  invertcolors:true,  mode:4},
            {scale:2.00, grayscale:false, invertcolors:false, mode:4},
            {scale:1.75, grayscale:true,  invertcolors:true,  mode:5}
        ]

        for pass in passes {
            result := ""

            try {
                options := {
                    lang: "ru-RU",
                    scale: pass.scale,
                    grayscale: pass.grayscale,
                    invertcolors: pass.invertcolors,
                    mode: pass.mode
                }
                result := OCR.FromWindow("ahk_id " . targetHwnd, options)
            } catch {
                ; Если русский OCR-пакет недоступен, пробуем системный язык.
                try {
                    options := {
                        scale: pass.scale,
                        grayscale: pass.grayscale,
                        invertcolors: pass.invertcolors,
                        mode: pass.mode
                    }
                    result := OCR.FromWindow("ahk_id " . targetHwnd, options)
                } catch {
                    continue
                }
            }

            if !IsObject(result)
                continue

            if recognizedSample = "" {
                try recognizedSample := SubStr(result.Text, 1, 220)
            }

            found := FindGenderCandidate(result, testSex)
            if IsObject(found) {
                ; Кликаем, пока наши окна ещё скрыты и не перекрывают форму.
                found.Click()
                Sleep(100)
                break
            }
        }
    } finally {
        RestoreStatusAfterOcr(overlayState)

        if controlWasVisible {
            controlGui.Show("x540 y20 w410 h675 NoActivate")
        }
    }

    if IsObject(found) {
        LogEvent("F3: OCR выбрал пол → " . testSex)
        statusTextCtrl.Text :=
            "✓ ПОЛ ВЫБРАН`n`n" .
            "Профиль: " . testSex . "`n" .
            "Нужный radio-вариант найден OCR и нажат."
        return true
    }

    LogEvent("F3: OCR не нашёл вариант → " . testSex)
    statusTextCtrl.Text :=
        "⛔ ПОЛ НЕ ВЫБРАН`n`n" .
        "Не удалось распознать: " . testSex . "`n" .
        "Текстовый ввод отключён полностью."

    if recognizedSample != ""
        LogEvent("F3 OCR видел: " . StrReplace(recognizedSample, "`n", " | "))

    return false
}


; ============================================================
; МЫШЬ — ЗАПИСЬ
; ============================================================

~LButton::RecordMouseButtonEvent("Left", "D")
~LButton Up::RecordMouseButtonEvent("Left", "U")
~RButton::RecordMouseButtonEvent("Right", "D")
~RButton Up::RecordMouseButtonEvent("Right", "U")
~MButton::RecordMouseButtonEvent("Middle", "D")
~MButton Up::RecordMouseButtonEvent("Middle", "U")
~XButton1::RecordMouseButtonEvent("X1", "D")
~XButton1 Up::RecordMouseButtonEvent("X1", "U")
~XButton2::RecordMouseButtonEvent("X2", "D")
~XButton2 Up::RecordMouseButtonEvent("X2", "U")
~WheelUp::RecordWheelEvent("WheelUp")
~WheelDown::RecordWheelEvent("WheelDown")

; ============================================================
; GUI ОБРАБОТЧИКИ
; ============================================================

StartRecordingFromGui(*) => ToggleRecording()
StartPlaybackFromGui(*) => PlayRecording()
StopPlaybackFromGui(*) => StopPlayback()
TypeSmartAnswerFromGui(*) => TypeSmartAnswer()
NewProfileFromGui(*) => NewTestProfile()
LoadOtherRecordingFromGui(*) {
    global recording, playing
    global currentRecordingPath, currentRecordingName
    global statusTextCtrl

    if recording || playing {
        statusTextCtrl.Text :=
            "⚠ НЕЛЬЗЯ СМЕНИТЬ ЗАПИСЬ`n`n" .
            "Сначала остановите запись или воспроизведение."
        return
    }

    selected := FileSelect(
        1,
        A_ScriptDir "\recordings",
        "Выберите любую запись .srm",
        "Smart Recorder (*.srm)"
    )

    if selected = "" {
        LogEvent("Выбор другой записи отменён")
        return
    }

    if LoadRecordingFromFile(selected, true) {
        currentRecordingPath := selected
        SplitPath(selected, &fileName)
        currentRecordingName := fileName

        LogEvent(
            "Выбрана другая запись: " .
            fileName
        )

        statusTextCtrl.Text :=
            "📂 ДРУГАЯ ЗАПИСЬ ЗАГРУЖЕНА`n`n" .
            "Файл: " . fileName . "`n`n" .
            "F9 теперь запускает именно эту запись.`n" .
            "Для другой записи снова нажмите F12 → Загрузить другую запись..."
    }
}

HideControlWindow(*) {
    global controlGui, controlVisible
    controlGui.Hide()
    controlVisible := false
}

SmartCheckboxChanged(*) {
    global smartOcrCheckCtrl
    SetSmartOcr(smartOcrCheckCtrl.Value ? true : false)
}

; ============================================================
; ЧТЕНИЕ НАСТРОЕК
; ============================================================

ParseDuration(text) {
    ; Возвращает секунды. -1 = формат не распознан.
    s := StrLower(Trim(text))

    if s = ""
        return -1

    ; Унифицируем ввод.
    s := StrReplace(s, ",", ".")
    s := RegExReplace(s, "\s+", " ")

    ; --------------------------------------------------------
    ; Просто число = минуты
    ; 3 -> 3 минуты
    ; 0.5 -> 30 секунд
    ; --------------------------------------------------------

    if RegExMatch(s, "^\d+(?:\.\d+)?$")
        return Round((s + 0) * 60)

    ; --------------------------------------------------------
    ; HH:MM:SS
    ; 00:03:30
    ; --------------------------------------------------------

    if RegExMatch(s, "^(\d{1,3}):(\d{1,2}):(\d{1,2})$", &m) {
        h := m[1] + 0
        min := m[2] + 0
        sec := m[3] + 0

        if min > 59 || sec > 59
            return -1

        return h * 3600 + min * 60 + sec
    }

    ; --------------------------------------------------------
    ; MM:SS
    ; 03:30
    ; --------------------------------------------------------

    if RegExMatch(s, "^(\d{1,4}):(\d{1,2})$", &m) {
        min := m[1] + 0
        sec := m[2] + 0

        if sec > 59
            return -1

        return min * 60 + sec
    }

    ; --------------------------------------------------------
    ; Текстовый формат:
    ; 1ч 5м 30с
    ; 1 час 5 минут
    ; 3м
    ; 90с
    ;
    ; Здесь НЕ используется \b после кириллицы.
    ; --------------------------------------------------------

    total := 0
    foundAny := false
    rest := s

    ; ЧАСЫ
    if RegExMatch(
        rest,
        "i)(\d+(?:\.\d+)?)\s*(часов|часа|час|ч)(?=\s|$)",
        &mh
    ) {
        total += Round((mh[1] + 0) * 3600)
        rest := StrReplace(rest, mh[0], " ")
        foundAny := true
    }

    ; МИНУТЫ
    if RegExMatch(
        rest,
        "i)(\d+(?:\.\d+)?)\s*(минуты|минута|минут|мин|м)(?=\s|$)",
        &mm
    ) {
        total += Round((mm[1] + 0) * 60)
        rest := StrReplace(rest, mm[0], " ")
        foundAny := true
    }

    ; СЕКУНДЫ
    if RegExMatch(
        rest,
        "i)(\d+(?:\.\d+)?)\s*(секунды|секунда|секунд|сек|с)(?=\s|$)",
        &ms
    ) {
        total += Round(ms[1] + 0)
        rest := StrReplace(rest, ms[0], " ")
        foundAny := true
    }

    ; После удаления распознанных частей не должно оставаться
    ; ничего кроме пробелов.
    rest := Trim(RegExReplace(rest, "\s+", " "))

    if foundAny && rest = ""
        return total

    return -1
}

FormatDurationInput(totalSeconds) {
    ; Короткий и понятный формат для полей ввода.
    totalSeconds := Round(totalSeconds)

    if totalSeconds < 0
        totalSeconds := 0

    h := Floor(totalSeconds / 3600)
    m := Floor(Mod(totalSeconds, 3600) / 60)
    s := Mod(totalSeconds, 60)

    parts := []

    if h > 0
        parts.Push(h . "ч")

    if m > 0
        parts.Push(m . "м")

    if s > 0 || parts.Length = 0
        parts.Push(s . "с")

    result := ""
    for i, part in parts {
        if i > 1
            result .= " "
        result .= part
    }

    return result
}

ApplySettings() {
    global repeatCount, playbackSpeed
    global cooldownMinMinutes, cooldownMaxMinutes
    global ageMin, ageMax, sexMode, randomProfileEachRepeat
    global repeatEditCtrl, speedEditCtrl
    global cooldownMinEditCtrl, cooldownMaxEditCtrl
    global ageMinEditCtrl, ageMaxEditCtrl, sexModeDropCtrl, randomProfileCheckCtrl

    repeatText := Trim(repeatEditCtrl.Value)
    speedText := StrReplace(Trim(speedEditCtrl.Value), ",", ".")
    minText := Trim(cooldownMinEditCtrl.Value)
    maxText := Trim(cooldownMaxEditCtrl.Value)
    ageMinText := Trim(ageMinEditCtrl.Value)
    ageMaxText := Trim(ageMaxEditCtrl.Value)

    if !RegExMatch(repeatText, "^\d+$") || (repeatText + 0) < 1 {
        MsgBox("Количество повторов должно быть целым числом от 1.")
        return false
    }
    if !RegExMatch(speedText, "^\d+(\.\d+)?$") || (speedText + 0) < 0.1 || (speedText + 0) > 50 {
        MsgBox("Скорость: число от 0.1 до 50. Например: 1, 2, 5.")
        return false
    }
    minSeconds := ParseDuration(minText)
    maxSeconds := ParseDuration(maxText)

    if minSeconds < 0 || maxSeconds < 0 {
        MsgBox(
            "Не удалось понять время кулдауна.`n`n" .
            "Введено ОТ: " . minText . "`n" .
            "Введено ДО: " . maxText . "`n`n" .
            "Допустимые примеры:`n" .
            "3          = 3 минуты`n" .
            "3м         = 3 минуты`n" .
            "3м 30с     = 3 минуты 30 секунд`n" .
            "90с        = 90 секунд`n" .
            "1ч 5м      = 1 час 5 минут`n" .
            "03:30      = 3 минуты 30 секунд`n" .
            "00:03:30   = 3 минуты 30 секунд"
        )
        return false
    }

    if minSeconds > maxSeconds {
        MsgBox("Кулдаун ОТ не может быть больше кулдауна ДО.")
        return false
    }

    if !RegExMatch(ageMinText, "^\d{1,3}$") || !RegExMatch(ageMaxText, "^\d{1,3}$") {
        MsgBox("Границы возраста должны быть целыми числами.")
        return false
    }

    minAgeValue := ageMinText + 0
    maxAgeValue := ageMaxText + 0

    if minAgeValue < 1 || maxAgeValue > 120 || minAgeValue > maxAgeValue {
        MsgBox("Возраст: диапазон от 1 до 120, причём ОТ не больше ДО.")
        return false
    }

    repeatCount := repeatText + 0
    playbackSpeed := speedText + 0
    ; Остальная программа исторически хранит кулдаун в минутах.
    ; Конвертируем понятный человеку ввод обратно в минуты.
    cooldownMinMinutes := minSeconds / 60
    cooldownMaxMinutes := maxSeconds / 60

    ; Нормализуем поля, чтобы пользователь сразу видел понятный формат.
    cooldownMinEditCtrl.Value := FormatDurationInput(minSeconds)
    cooldownMaxEditCtrl.Value := FormatDurationInput(maxSeconds)
    ageMin := minAgeValue
    ageMax := maxAgeValue
    sexMode := sexModeDropCtrl.Text
    randomProfileEachRepeat := randomProfileCheckCtrl.Value ? true : false
    return true
}

GenerateTestProfile(showStatus:=true) {
    global ageMin, ageMax, sexMode
    global testAge, testSex
    global currentProfileLabelCtrl
    global smartDetectedQuestion, smartSuggestedAnswer
    global statusTextCtrl

    testAge := Random(ageMin, ageMax)

    switch sexMode {
        case "Мужской":
            testSex := "Мужской"
        case "Женский":
            testSex := "Женский"
        default:
            testSex := Random(0, 1) = 0 ? "Мужской" : "Женский"
    }

    currentProfileLabelCtrl.Text := "Текущий профиль: " . testAge . " лет, " . testSex
    LogEvent("Профиль: " . testAge . " лет, " . testSex)

    if smartDetectedQuestion = "Возраст"
        smartSuggestedAnswer := String(testAge)
    else if smartDetectedQuestion = "Пол"
        smartSuggestedAnswer := testSex

    if showStatus {
        statusTextCtrl.Text :=
            "🎲 НОВЫЙ ТЕСТОВЫЙ ПРОФИЛЬ`n`n" .
            "Возраст: " . testAge . "`n" .
            "Пол: " . testSex . "`n`n" .
            "F6 — OCR | F7 — ввести подсказку"
    }
}

NewTestProfile() {
    global recording, playing

    if recording || playing
        return

    UnlockStatusPanel()

    if !ApplySettings()
        return

    GenerateTestProfile(true)
}

; ============================================================
; СОХРАНЕНИЕ / ЗАГРУЗКА ЗАПИСИ МЕЖДУ СЕССИЯМИ
; ============================================================

EnsureRecordingStorage() {
    global recordingsDir

    try {
        if !DirExist(recordingsDir)
            DirCreate(recordingsDir)
        return true
    } catch {
        return false
    }
}

SaveRecordingToFile(path, showStatus:=true) {
    global events, recording, playing
    global lastSaveStatus, statusTextCtrl

    if recording || playing {
        if showStatus
            statusTextCtrl.Text := "⚠ СОХРАНЕНИЕ НЕДОСТУПНО`n`nСначала остановите запись/воспроизведение."
        return false
    }

    if events.Length = 0 {
        lastSaveStatus := "Сохранять нечего: запись пустая"
        if showStatus
            statusTextCtrl.Text := "⚠ НЕТ ЗАПИСИ`n`nСначала запишите действия клавишей F8."
        return false
    }

    if !EnsureRecordingStorage() {
        lastSaveStatus := "Не удалось создать папку recordings"
        if showStatus
            statusTextCtrl.Text := "❌ ОШИБКА СОХРАНЕНИЯ`n`nНе удалось создать папку recordings."
        return false
    }

    try {
        file := FileOpen(path, "w", "UTF-8")
        if !IsObject(file)
            throw Error("Не удалось открыть файл для записи")

        ; Заголовок собственного простого формата.
        file.Write("SMARTRECORDER`t1`n")

        for _, event in events {
            switch event.kind {
                case "move":
                    file.Write(
                        "M`t" . event.t .
                        "`t" . event.x .
                        "`t" . event.y . "`n"
                    )

                case "button":
                    file.Write(
                        "B`t" . event.t .
                        "`t" . event.button .
                        "`t" . event.state .
                        "`t" . event.x .
                        "`t" . event.y . "`n"
                    )

                case "wheel":
                    file.Write(
                        "W`t" . event.t .
                        "`t" . event.button .
                        "`t" . event.x .
                        "`t" . event.y . "`n"
                    )

                case "key":
                    ; Имя клавиши не сохраняем: после загрузки оно
                    ; восстанавливается из vk/sc.
                    file.Write(
                        "K`t" . event.t .
                        "`t" . event.vk .
                        "`t" . event.sc .
                        "`t" . event.state . "`n"
                    )

                case "answer_text":
                    safeText := CleanRememberedAnswerText(event.text)

                    answerX :=
                        event.HasOwnProp("x")
                            ? event.x
                            : 0

                    answerY :=
                        event.HasOwnProp("y")
                            ? event.y
                            : 0

                    answerDx :=
                        event.HasOwnProp("dx")
                            ? event.dx
                            : 0

                    answerDy :=
                        event.HasOwnProp("dy")
                            ? event.dy
                            : 0

                    answerButton :=
                        event.HasOwnProp("button")
                            ? event.button
                            : "Left"

                    answerClicks :=
                        event.HasOwnProp("clicks")
                            ? event.clicks
                            : 1

                    ; T3:
                    ; t / absX / absY / dx / dy / button / clicks / text
                    file.Write(
                        "T3`t" .
                        event.t .
                        "`t" .
                        answerX .
                        "`t" .
                        answerY .
                        "`t" .
                        answerDx .
                        "`t" .
                        answerDy .
                        "`t" .
                        answerButton .
                        "`t" .
                        answerClicks .
                        "`t" .
                        safeText .
                        "`n"
                    )

                case "profile_age":
                    file.Write("A`t" . event.t . "`n")

                case "profile_sex":
                    sexX := event.HasOwnProp("x") ? event.x : ""
                    file.Write(
                        "S`t" . event.t .
                        "`t" . sexX . "`n"
                    )
            }
        }

        file.Close()

        lastSaveStatus := "Сохранено: " . events.Length . " событий"
        LogEvent("Макрос сохранён: " . events.Length . " событий")

        if showStatus {
            statusTextCtrl.Text :=
                "💾 ЗАПИСЬ СОХРАНЕНА`n`n" .
                "Событий: " . events.Length . "`n" .
                "Файл: recordings\\last_recording.srm`n`n" .
                "Эта запись автоматически загрузится`n" .
                "при следующем запуске программы."
        }

        return true

    } catch as err {
        lastSaveStatus := "Ошибка сохранения: " . err.Message

        if showStatus
            statusTextCtrl.Text := "❌ ОШИБКА СОХРАНЕНИЯ`n`n" . err.Message

        return false
    }
}

LoadRecordingFromFile(path, showStatus:=true) {
    global events, recording, playing
    global lastSaveStatus, statusTextCtrl
    global currentRecordingPath, currentRecordingName
    global recordingFileLabelCtrl
    global moveCount, clickCount, wheelCount, keyPressCount

    if recording || playing {
        if showStatus
            statusTextCtrl.Text := "⚠ ЗАГРУЗКА НЕДОСТУПНА`n`nСначала остановите запись/воспроизведение."
        return false
    }

    if !FileExist(path) {
        lastSaveStatus := "Сохранённая запись пока отсутствует"

        if showStatus
            statusTextCtrl.Text :=
                "📂 СОХРАНЁННОЙ ЗАПИСИ НЕТ`n`n" .
                "После первой записи F8 она будет`n" .
                "сохранена автоматически."

        return false
    }

    try {
        content := FileRead(path, "UTF-8")
        lines := StrSplit(content, "`n", "`r")

        if lines.Length < 1 || Trim(lines[1]) != "SMARTRECORDER`t1"
            throw Error("Неизвестный или повреждённый формат файла")

        loadedEvents := []

        Loop lines.Length {
            if A_Index = 1
                continue

            line := Trim(lines[A_Index])
            if line = ""
                continue

            p := StrSplit(line, "`t")
            type := p[1]

            switch type {
                case "M":
                    if p.Length < 4
                        continue
                    loadedEvents.Push({
                        kind: "move",
                        t: p[2] + 0,
                        x: p[3] + 0,
                        y: p[4] + 0
                    })

                case "B":
                    if p.Length < 6
                        continue
                    loadedEvents.Push({
                        kind: "button",
                        t: p[2] + 0,
                        button: p[3],
                        state: p[4],
                        x: p[5] + 0,
                        y: p[6] + 0
                    })

                case "W":
                    if p.Length < 5
                        continue
                    loadedEvents.Push({
                        kind: "wheel",
                        t: p[2] + 0,
                        button: p[3],
                        x: p[4] + 0,
                        y: p[5] + 0
                    })

                case "K":
                    if p.Length < 5
                        continue

                    vk := p[3] + 0
                    sc := p[4] + 0

                    loadedEvents.Push({
                        kind: "key",
                        t: p[2] + 0,
                        vk: vk,
                        sc: sc,
                        state: p[5],
                        name: GetRecordedKeyName(vk, sc)
                    })

                case "T3":
                    if p.Length >= 9 {
                        rememberedText :=
                            CleanRememberedAnswerText(p[9])

                        if p.Length > 9 {
                            Loop p.Length - 9
                                rememberedText .=
                                    " " .
                                    p[A_Index + 9]

                            rememberedText :=
                                CleanRememberedAnswerText(
                                    rememberedText
                                )
                        }

                        loadedEvents.Push({
                            kind: "answer_text",
                            t: p[2] + 0,
                            x: p[3] + 0,
                            y: p[4] + 0,
                            dx: p[5] + 0,
                            dy: p[6] + 0,
                            button: p[7],
                            clicks: p[8] + 0,
                            text: rememberedText
                        })
                    }

                case "T2":
                    if p.Length >= 5 {
                        rememberedText :=
                            CleanRememberedAnswerText(p[5])

                        if p.Length > 5 {
                            Loop p.Length - 5
                                rememberedText .=
                                    " " .
                                    p[A_Index + 5]

                            rememberedText :=
                                CleanRememberedAnswerText(
                                    rememberedText
                                )
                        }

                        loadedEvents.Push({
                            kind: "answer_text",
                            t: p[2] + 0,
                            x: 0,
                            y: 0,
                            dx: p[3] + 0,
                            dy: p[4] + 0,
                            button: "Left",
                            clicks: 1,
                            text: rememberedText
                        })
                    }

                ; Старый формат v8-v11 по-прежнему читается.
                case "T":
                    if p.Length >= 3 {
                        rememberedText :=
                            CleanRememberedAnswerText(p[3])

                        if p.Length > 3 {
                            Loop p.Length - 3
                                rememberedText .=
                                    " " .
                                    p[A_Index + 3]

                            rememberedText :=
                                CleanRememberedAnswerText(
                                    rememberedText
                                )
                        }

                        loadedEvents.Push({
                            kind: "answer_text",
                            t: p[2] + 0,
                            x: 0,
                            y: 0,
                            dx: 0,
                            dy: 0,
                            button: "Left",
                            clicks: 1,
                            text: rememberedText
                        })
                    }

                case "A":
                    if p.Length >= 2
                        loadedEvents.Push({kind:"profile_age", t:p[2] + 0})

                case "S":
                    if p.Length >= 2 {
                        sexEvent := {
                            kind: "profile_sex",
                            t: p[2] + 0
                        }

                        ; Новые записи содержат X; старые продолжают работать
                        ; старый X читается только для совместимости и больше не используется.
                        if (p.Length >= 3 && p[3] != "")
                            sexEvent.x := p[3] + 0

                        loadedEvents.Push(sexEvent)
                    }
            }
        }

        if loadedEvents.Length = 0
            throw Error("Файл не содержит событий")

        events := loadedEvents
        RecountLoadedEvents()

        lastSaveStatus := "Загружено: " . events.Length . " событий"
        currentRecordingPath := path
        SplitPath(path, &loadedFileName)
        currentRecordingName := loadedFileName

        try {
            recordingFileLabelCtrl.Text :=
                "Текущий файл: " .
                loadedFileName
        }
        LogEvent("Макрос загружен: " . events.Length . " событий")

        if showStatus {
            statusTextCtrl.Text :=
                "📂 ЗАПИСЬ ЗАГРУЖЕНА`n`n" .
                "Событий: " . events.Length . "`n" .
                "Движений: " . moveCount . "`n" .
                "Кликов: " . clickCount . "`n" .
                "Клавиш: " . keyPressCount . "`n" .
                "Колесо: " . wheelCount . "`n`n" .
                "F9 — запустить сохранённую запись."
        }

        return true

    } catch as err {
        lastSaveStatus := "Ошибка загрузки: " . err.Message

        if showStatus
            statusTextCtrl.Text := "❌ ОШИБКА ЗАГРУЗКИ`n`n" . err.Message

        return false
    }
}

RecountLoadedEvents() {
    global events
    global moveCount, clickCount, wheelCount, keyPressCount

    moveCount := 0
    clickCount := 0
    wheelCount := 0
    keyPressCount := 0

    for _, event in events {
        switch event.kind {
            case "move":
                moveCount += 1

            case "button":
                if event.state = "D"
                    clickCount += 1

            case "wheel":
                wheelCount += 1

            case "answer_text":
                clickCount += 1

            case "key":
                if event.state = "D"
                    keyPressCount += 1
        }
    }
}

; ============================================================
; ЗАПИСЬ
; ============================================================

ToggleRecording() {
    global recording, playing, events, recordStart
    global lastX, lastY, recordInterval
    global moveCount, clickCount, wheelCount, keyPressCount
    global lastAction, controlGui, controlVisible

    UnlockStatusPanel()

    if playing
        return

    if !recording {
        events := []
        moveCount := 0
        clickCount := 0
        wheelCount := 0
        keyPressCount := 0
        recording := true
        recordStart := A_TickCount
        MouseGetPos(&lastX, &lastY)
        events.Push({kind:"move", x:lastX, y:lastY, t:0})
        moveCount := 1
        lastAction := "Запись началась"
        LogEvent("Запись начата")

        controlGui.Hide()
        controlVisible := false
        SetTimer(RecordMouseMove, recordInterval)
        StartKeyboardRecording()
        SetTimer(UpdateRecordingStatus, 100)
        UpdateRecordingStatus()
        return
    }

    recording := false
    SetTimer(RecordMouseMove, 0)
    SetTimer(UpdateRecordingStatus, 0)
    StopKeyboardRecording()
    lastAction := "Запись завершена"
    LogEvent("Запись завершена: " . events.Length . " событий")

    ; Автоматически сохраняем свежую запись на диск.
    SaveRecordingToFile(recordingFile, false)

    ShowRecordedStatus()
    controlGui.Show("x540 y20 w410 h675 NoActivate")
    controlVisible := true
}

StartKeyboardRecording() {
    global keyboardHook
    keyboardHook := InputHook("V")
    keyboardHook.KeyOpt("{All}", "+N")
    keyboardHook.OnKeyDown := KeyboardKeyDown
    keyboardHook.OnKeyUp := KeyboardKeyUp
    keyboardHook.Start()
}

StopKeyboardRecording() {
    global keyboardHook
    try {
        if IsObject(keyboardHook)
            keyboardHook.Stop()
    }
    keyboardHook := 0
}

KeyboardKeyDown(hook, vk, sc) {
    global recording, playing, events, recordStart
    global keyPressCount, lastAction, ignoreKeyboardCapture, recordingPaused
    if !recording || playing || recordingPaused || ignoreKeyboardCapture || IsRecorderControlKey(vk)
        return

    keyName := GetRecordedKeyName(vk, sc)
    events.Push({kind:"key", vk:vk, sc:sc, state:"D", name:keyName, t:A_TickCount-recordStart})
    keyPressCount += 1
    lastAction := "Клавиша ↓ " . keyName
}

KeyboardKeyUp(hook, vk, sc) {
    global recording, playing, events, recordStart, lastAction
    global ignoreKeyboardCapture, recordingPaused
    if !recording || playing || recordingPaused || ignoreKeyboardCapture || IsRecorderControlKey(vk)
        return

    keyName := GetRecordedKeyName(vk, sc)
    events.Push({kind:"key", vk:vk, sc:sc, state:"U", name:keyName, t:A_TickCount-recordStart})
    lastAction := "Клавиша ↑ " . keyName
}

IsRecorderControlKey(vk) {
    if vk = 0x1B
        return true

    ; F1 — показать/скрыть отдельный журнал.
    if vk = 0x70
        return true

    ; F2/F3/F4 — специальные команды записи.
    if vk = 0x71 || vk = 0x72 || vk = 0x73
        return true

    ; F5..F12 control the program.
    return vk >= 0x74 && vk <= 0x7B
}

GetRecordedKeyName(vk, sc) {
    code := "vk" . Format("{:02X}", vk)
    if sc
        code .= "sc" . Format("{:03X}", sc)
    name := GetKeyName(code)
    return name = "" ? code : name
}

RecordMouseMove() {
    global recording, playing, events, recordStart
    global lastX, lastY, moveCount, lastAction, recordingPaused
    if !recording || playing || recordingPaused
        return

    MouseGetPos(&x, &y)
    if x != lastX || y != lastY {
        events.Push({kind:"move", x:x, y:y, t:A_TickCount-recordStart})
        moveCount += 1
        lastX := x
        lastY := y
        lastAction := "Движение мыши"
    }
}

RecordMouseButtonEvent(button, state) {
    global recording, playing, events, recordStart, clickCount, lastAction
    global ignoreMouseCapture, recordingPaused

    if !recording || playing || recordingPaused || ignoreMouseCapture
        return

    MouseGetPos(&x, &y)
    events.Push({kind:"button", button:button, state:state, x:x, y:y, t:A_TickCount-recordStart})
    if state = "D"
        clickCount += 1
    lastAction := GetButtonName(button) . (state="D" ? " ↓" : " ↑")
}

RecordWheelEvent(direction) {
    global recording, playing, events, recordStart, wheelCount, lastAction
    global recordingPaused
    if !recording || playing || recordingPaused
        return

    MouseGetPos(&x, &y)
    events.Push({kind:"wheel", button:direction, x:x, y:y, t:A_TickCount-recordStart})
    wheelCount += 1
    lastAction := direction = "WheelUp" ? "Колесо вверх" : "Колесо вниз"
}

; ============================================================
; РАСЧЁТ ВРЕМЕНИ РАБОТЫ
; ============================================================

GetRecordedMacroSeconds() {
    global events, playbackSpeed

    if events.Length = 0
        return 0

    lastTimeMs := events[events.Length].t

    if playbackSpeed <= 0
        return 0

    return Max(0, lastTimeMs / 1000 / playbackSpeed)
}

BuildRunTimePlan() {
    global repeatCount, cooldownMinMinutes, cooldownMaxMinutes
    global runCooldownPlan, runPlannedSeconds, runMacroSeconds

    runCooldownPlan := []

    runMacroSeconds := GetRecordedMacroSeconds()

    minSec := Round(cooldownMinMinutes * 60)
    maxSec := Round(cooldownMaxMinutes * 60)

    if maxSec < minSec
        maxSec := minSec

    cooldownTotal := 0

    if repeatCount > 1 {
        Loop repeatCount - 1 {
            cd := Random(minSec, maxSec)
            runCooldownPlan.Push(cd)
            cooldownTotal += cd
        }
    }

    runPlannedSeconds :=
        Round(
            runMacroSeconds * repeatCount +
            cooldownTotal
        )

    return runPlannedSeconds
}

GetRunRemainingSeconds() {
    global runPlannedSeconds, runStartTick

    if runStartTick <= 0
        return runPlannedSeconds

    elapsedSec :=
        (A_TickCount - runStartTick) / 1000

    return Max(
        0,
        Ceil(runPlannedSeconds - elapsedSec)
    )
}

GetEstimatedRangeText() {
    global events, repeatCount, playbackSpeed
    global cooldownMinMinutes, cooldownMaxMinutes

    if events.Length = 0
        return "нет записи"

    macroSec := GetRecordedMacroSeconds()

    minCooldown :=
        Round(cooldownMinMinutes * 60)

    maxCooldown :=
        Round(cooldownMaxMinutes * 60)

    if maxCooldown < minCooldown
        maxCooldown := minCooldown

    minTotal :=
        Round(
            macroSec * repeatCount +
            minCooldown * Max(0, repeatCount - 1)
        )

    maxTotal :=
        Round(
            macroSec * repeatCount +
            maxCooldown * Max(0, repeatCount - 1)
        )

    if minTotal = maxTotal
        return FormatCooldown(minTotal)

    return (
        FormatCooldown(minTotal) .
        " – " .
        FormatCooldown(maxTotal)
    )
}

; ============================================================
; ВОСПРОИЗВЕДЕНИЕ
; ============================================================

PlayRecording() {
    global recording, playing, stopRequested, events
    global repeatCount, playbackSpeed
    global cooldownMinMinutes, cooldownMaxMinutes
    global randomProfileEachRepeat, testAge, testSex
    global controlGui, controlVisible, lastPlaybackStatusTick
    global playbackKeysDown
    global runCooldownPlan, runPlannedSeconds, runStartTick, runMacroSeconds

    if recording || playing
        return

    UnlockStatusPanel()

    if !ApplySettings()
        return
    if events.Length = 0 {
        ShowNoRecordingStatus()
        return
    }

    playing := true
    stopRequested := false
    lastPlaybackStatusTick := 0
    playbackKeysDown := Map()

    ; Выбираем все случайные кулдауны заранее и считаем
    ; примерную продолжительность полного запуска.
    BuildRunTimePlan()
    runStartTick := A_TickCount
    LogEvent(
        "Старт: " . repeatCount . " повт., ~" .
        FormatCooldown(runPlannedSeconds)
    )

    controlGui.Hide()
    controlVisible := false

    Loop repeatCount {
        currentRepeat := A_Index
        if stopRequested
            break

        LogEvent(
            "Повтор " . currentRepeat . "/" . repeatCount .
            " — " . testAge . " лет, " . testSex
        )

        ; Используем профиль, который уже подготовлен для этого повтора.
        playStart := A_TickCount
        for index, event in events {
            if stopRequested
                break

            targetTime := Round(event.t / playbackSpeed)
            elapsed := A_TickCount - playStart
            waitTime := targetTime - elapsed
            if waitTime > 0 && !InterruptibleSleep(waitTime)
                break
            if stopRequested
                break

            if event.kind = "move" {
                UpdatePlaybackStatus(currentRepeat, repeatCount, index, events.Length, "Мышь", false)
                MouseMove(event.x, event.y, 0)
            } else if event.kind = "button" {
                UpdatePlaybackStatus(currentRepeat, repeatCount, index, events.Length, GetButtonName(event.button), true)
                MouseMove(event.x, event.y, 0)
                MouseClick(event.button, event.x, event.y, 1, 0, event.state)
            } else if event.kind = "wheel" {
                UpdatePlaybackStatus(currentRepeat, repeatCount, index, events.Length, event.button, true)
                MouseMove(event.x, event.y, 0)
                MouseClick(event.button)
            } else if event.kind = "key" {
                UpdatePlaybackStatus(currentRepeat, repeatCount, index, events.Length, "Клавиша " . event.name, true)
                SendRecordedKey(event)

            } else if event.kind = "answer_text" {
                UpdatePlaybackStatus(
                    currentRepeat,
                    repeatCount,
                    index,
                    events.Length,
                    (
                        RegExMatch(
                            StrLower(event.text),
                            "^(далее|продолжить|следующий|next)$"
                        )
                            ? "Кнопка по тексту → "
                            : "Ответ по тексту → "
                    ) . event.text,
                    true
                )

                answerDx :=
                    event.HasOwnProp("dx")
                        ? event.dx
                        : 0

                answerDy :=
                    event.HasOwnProp("dy")
                        ? event.dy
                        : 0

                answerX :=
                    event.HasOwnProp("x")
                        ? event.x
                        : 0

                answerY :=
                    event.HasOwnProp("y")
                        ? event.y
                        : 0

                answerButton :=
                    event.HasOwnProp("button")
                        ? event.button
                        : "Left"

                answerClicks :=
                    event.HasOwnProp("clicks")
                        ? event.clicks
                        : 1

                if !FindAndClickRememberedAnswer(
                    event.text,
                    answerDx,
                    answerDy,
                    answerX,
                    answerY,
                    answerButton,
                    answerClicks
                ) {
                    stopRequested := true
                    break
                }

            } else if event.kind = "profile_age" {
                UpdatePlaybackStatus(
                    currentRepeat, repeatCount, index, events.Length,
                    "Профиль → возраст " . testAge, true
                )
                InsertCurrentProfileAge()

            } else if event.kind = "profile_sex" {
                UpdatePlaybackStatus(
                    currentRepeat, repeatCount, index, events.Length,
                    "Профиль → пол " . testSex, true
                )

                ; Старые записи могли хранить X, но теперь он намеренно игнорируется.
                InsertCurrentProfileSex()
            }
        }

        ReleasePlaybackKeys()
        if stopRequested
            break

        if currentRepeat < repeatCount {
            ; Полный цикл завершён. Сразу готовим НОВЫЙ профиль
            ; для следующей отправки/повтора.
            if randomProfileEachRepeat
                GenerateTestProfile(false)

            ; Кулдаун для этого перехода уже выбран при F9.
            cooldownSeconds := runCooldownPlan[currentRepeat]
            LogEvent(
                "Кулдаун: " . FormatCooldown(cooldownSeconds) .
                " → повтор " . (currentRepeat + 1)
            )

            if !RunCooldown(
                cooldownSeconds,
                currentRepeat,
                repeatCount
            )
                break
        }
    }

    ReleaseAllPlaybackInputs()
    playing := false
    controlGui.Show("x540 y20 w410 h675 NoActivate")
    controlVisible := true

    if stopRequested
        ShowStoppedStatus()
    else
        ShowFinishedStatus()

    runStartTick := 0
}

SendRecordedKey(event) {
    global playbackKeysDown
    keyID := GetSendKeyID(event.vk, event.sc)
    if event.state = "D" {
        SendEvent("{" . keyID . " Down}")
        playbackKeysDown[keyID] := true
    } else {
        SendEvent("{" . keyID . " Up}")
        if playbackKeysDown.Has(keyID)
            playbackKeysDown.Delete(keyID)
    }
}

GetSendKeyID(vk, sc) {
    if sc
        return "sc" . Format("{:03X}", sc)
    return "vk" . Format("{:02X}", vk)
}

InterruptibleSleep(milliseconds) {
    global stopRequested
    endTick := A_TickCount + milliseconds
    Loop {
        if stopRequested
            return false
        remaining := endTick - A_TickCount
        if remaining <= 0
            break
        Sleep(Min(remaining, 25))
    }
    return true
}

RunCooldown(totalSeconds, completedRepeat, totalRepeats) {
    global stopRequested, statusTextCtrl
    global cooldownMinMinutes, cooldownMaxMinutes
    global testAge, testSex, randomProfileEachRepeat
    global runPlannedSeconds, statusPanelFrozen

    if totalSeconds <= 0
        return true

    endTick := A_TickCount + totalSeconds * 1000
    Loop {
        if stopRequested || statusPanelFrozen
            return false
        remainingMs := endTick - A_TickCount
        if remainingMs <= 0
            break
        remainingSeconds := Ceil(remainingMs / 1000)

        statusTextCtrl.Text :=
            "⏳ КУЛДАУН`n`n" .
            "Выполнено: " . completedRepeat . " / " . totalRepeats . "`n" .
            "Следующий: " . (completedRepeat+1) . " / " . totalRepeats . "`n" .
            "Следующий профиль: " . testAge . " лет, " . testSex . "`n" .
            "Диапазон: " . FormatCooldown(Round(cooldownMinMinutes * 60)) . " – " . FormatCooldown(Round(cooldownMaxMinutes * 60)) . "`n" .
            "Этот кулдаун: " . FormatCooldown(totalSeconds) . "`n" .
            "До следующего повтора: " . FormatCooldown(remainingSeconds) . "`n`n" .
            "Весь запуск: ~" . FormatCooldown(runPlannedSeconds) . "`n" .
            "Осталось всего: ~" . FormatCooldown(GetRunRemainingSeconds()) . "`n`n" .
            "F10 — ОСТАНОВИТЬ"
        Sleep(200)
    }
    return true
}

FormatCooldown(totalSeconds) {
    totalSeconds := Floor(totalSeconds)
    hours := Floor(totalSeconds / 3600)
    minutes := Floor(Mod(totalSeconds, 3600) / 60)
    seconds := Mod(totalSeconds, 60)
    if hours > 0
        return hours . " ч " . Format("{:02}", minutes) . " мин " . Format("{:02}", seconds) . " сек"
    return minutes . " мин " . Format("{:02}", seconds) . " сек"
}

StopPlayback() {
    global playing, stopRequested, statusTextCtrl
    global statusPanelFrozen

    if !playing
        return

    stopRequested := true
    statusPanelFrozen := true
    LogEvent("F10: остановка макроса")

    statusTextCtrl.Text :=
        "■ ОСТАНОВКА...`n`n" .
        "Останавливаю макрос.`n" .
        "Панель зафиксирована и больше не обновляется."

    ReleaseAllPlaybackInputs()
}

ReleasePlaybackKeys() {
    global playbackKeysDown
    for keyID, _ in playbackKeysDown
        SendEvent("{" . keyID . " Up}")
    playbackKeysDown := Map()
}

ReleaseAllPlaybackInputs() {
    ReleasePlaybackKeys()
    SendEvent("{LButton Up}{RButton Up}{MButton Up}{XButton1 Up}{XButton2 Up}")
}

; ============================================================
; OCR-ПОМОЩНИК — ТОЛЬКО ПОДСКАЗКА/РУЧНОЙ ВВОД
; ============================================================

ToggleSmartOcr() {
    global smartOcrEnabled

    UnlockStatusPanel()
    SetSmartOcr(!smartOcrEnabled)
}

SetSmartOcr(enable) {
    global smartOcrEnabled, smartOcrCheckCtrl, ocrAvailable, ocrInterval
    global smartLastError

    if enable && !ocrAvailable {
        smartOcrEnabled := false
        smartOcrCheckCtrl.Value := 0
        smartLastError := "OCR недоступен: положите OCR.ahk рядом со скриптом"
        ShowSmartStatus()
        return
    }

    smartOcrEnabled := enable
    smartOcrCheckCtrl.Value := enable ? 1 : 0
    LogEvent(enable ? "OCR включён" : "OCR выключен")
    SetTimer(SmartScanTimer, enable ? ocrInterval : 0)
    if enable {
        smartLastError := ""
        SmartScanTimer()
    } else {
        ShowSmartStatus()
    }
}

SmartScanTimer() {
    global smartOcrEnabled, recording, playing, controlGui
    global smartDetectedQuestion, smartSuggestedAnswer
    global smartLastText, smartLastError, testAge, testSex
    global statusPanelFrozen

    ; После F10 OCR продолжает существовать, но чёрную панель
    ; больше не имеет права перерисовывать.
    if statusPanelFrozen
        return

    if !smartOcrEnabled || recording || playing
        return

    ; Не сканируем собственное окно настроек.
    if WinActive("ahk_id " . controlGui.Hwnd)
        return

    if !ApplySettingsSilent()
        return

    try {
        try result := OCR.FromWindow("A", {lang:"ru-RU", scale:1.25, grayscale:true})
        catch
            result := OCR.FromWindow("A", {scale:1.25, grayscale:true})

        text := NormalizeOcrText(result.Text)
        smartLastText := StrLen(text) > 180 ? SubStr(text, 1, 180) . "…" : text
        smartLastError := ""

        if ContainsAgeQuestion(text) {
            smartDetectedQuestion := "Возраст"
            smartSuggestedAnswer := String(testAge)
        } else if ContainsSexQuestion(text) {
            smartDetectedQuestion := "Пол"
            smartSuggestedAnswer := testSex
        } else {
            smartDetectedQuestion := ""
            smartSuggestedAnswer := ""
        }
    } catch as err {
        smartLastError := "OCR: " . err.Message
        smartDetectedQuestion := ""
        smartSuggestedAnswer := ""
    }

    ShowSmartStatus()
}

ApplySettingsSilent() {
    ; OCR использует уже созданный текущий профиль.
    return true
}

NormalizeOcrText(text) {
    text := StrLower(text)
    text := StrReplace(text, "ё", "е")
    text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

ContainsAgeQuestion(text) {
    return InStr(text, "ваш возраст")
        || InStr(text, "укажите возраст")
        || InStr(text, "сколько вам лет")
        || RegExMatch(text, "(^|[.!?;:]\s+)возраст\s*[:?]")
}

ContainsSexQuestion(text) {
    return InStr(text, "ваш пол")
        || InStr(text, "укажите пол")
        || RegExMatch(text, "(^|[.!?;:]\s+)пол\s*[:?]")
}

TypeSmartAnswer() {
    global smartOcrEnabled, smartSuggestedAnswer, smartDetectedQuestion
    global smartLastError

    if !smartOcrEnabled {
        smartLastError := "Сначала включите OCR клавишей F6"
        ShowSmartStatus()
        return
    }
    if smartSuggestedAnswer = "" {
        smartLastError := "Подходящий вопрос пока не распознан"
        ShowSmartStatus()
        return
    }

    ; Пол никогда не вводим текстом: F7 для вопроса о поле
    ; использует тот же OCR-клик, что и F3.
    if smartDetectedQuestion = "Пол" {
        if InsertCurrentProfileSex()
            smartLastError := "Пол выбран OCR: " . smartSuggestedAnswer
        else
            smartLastError := "Пол не выбран: нужный вариант OCR не найден"
        ShowSmartStatus()
        return
    }

    ; Для возраста/обычного текстового поля ручной ввод F7 сохраняется.
    SendText(smartSuggestedAnswer)
    smartLastError := "Введено: " . smartDetectedQuestion . " → " . smartSuggestedAnswer
    ShowSmartStatus()
}

ShowSmartStatus() {
    global statusTextCtrl, smartOcrEnabled, ocrAvailable
    global smartDetectedQuestion, smartSuggestedAnswer
    global smartLastText, smartLastError
    global testAge, testSex

    text := "🔎 OCR-ПОМОЩНИК`n`n"
    text .= "OCR: " . (ocrAvailable ? "готов" : "не найден") . "`n"
    text .= "Режим: " . (smartOcrEnabled ? "ВКЛ" : "ВЫКЛ") . "`n"
    text .= "Профиль: " . testAge . " лет, " . testSex . "`n"
    if smartDetectedQuestion != "" {
        text .= "Найден вопрос: " . smartDetectedQuestion . "`n"
        text .= "Подсказка: " . smartSuggestedAnswer . "`n"
        text .= smartDetectedQuestion = "Пол" ? "`nF7 распознает и нажмёт нужный вариант пола." : "`nПоставьте курсор в поле и нажмите F7."
    } else {
        text .= "Вопрос возраст/пол не найден.`n"
    }
    if smartLastError != ""
        text .= "`n`nСтатус: " . smartLastError
    if smartLastText != ""
        text .= "`n`nOCR-фрагмент: " . smartLastText
    statusTextCtrl.Text := text
}

; ============================================================
; СТАТУСЫ
; ============================================================

UpdateRecordingStatus() {
    global recording, statusTextCtrl, events, recordStart
    global moveCount, clickCount, wheelCount, keyPressCount, lastAction
    global recordingPaused

    if !recording || recordingPaused
        return

    MouseGetPos(&x, &y)
    elapsed := Round((A_TickCount-recordStart)/1000, 1)
    statusTextCtrl.Text :=
        "● ЗАПИСЬ МЫШИ + КЛАВИАТУРЫ`n`n" .
        "Время: " . elapsed . " сек.`n" .
        "Событий: " . events.Length . "`n" .
        "Движений: " . moveCount . "`n" .
        "Кликов: " . clickCount . "`n" .
        "Клавиш: " . keyPressCount . "`n" .
        "Колесо: " . wheelCount . "`n" .
        "Курсор: X=" . x . " Y=" . y . "`n" .
        "Последнее: " . lastAction . "`n`n" .
        "F2 — возраст профиля`n" .
        "F3 — пол: наведите мышь внутрь строки и нажмите F3`n" .
        "F4 — ответ/кнопка: OCR → проверить текст → сохранить`n" .
        "F8 — закончить запись"
}

UpdatePlaybackStatus(currentRepeat, totalRepeats, currentEvent, totalEvents, action, forceUpdate:=false) {
    global statusTextCtrl, lastPlaybackStatusTick, playbackSpeed
    global testAge, testSex
    global runPlannedSeconds, runMacroSeconds
    global statusPanelFrozen

    if statusPanelFrozen
        return
    if !forceUpdate && A_TickCount-lastPlaybackStatusTick < 70
        return
    lastPlaybackStatusTick := A_TickCount

    repeatPercent := Round(currentEvent/totalEvents*100)
    overallPercent := Round((((currentRepeat-1)+(currentEvent/totalEvents))/totalRepeats)*100)
    statusTextCtrl.Text :=
        "▶ ВОСПРОИЗВЕДЕНИЕ`n`n" .
        "Повтор: " . currentRepeat . " / " . totalRepeats . "`n" .
        "Профиль: " . testAge . " лет, " . testSex . "`n" .
        "Скорость: x" . playbackSpeed . "`n" .
        "Прогресс повтора: " . repeatPercent . "%`n" .
        "Общий прогресс: " . overallPercent . "%`n" .
        "Сейчас: " . action . "`n`n" .
        "Один проход: ~" . FormatCooldown(Round(runMacroSeconds)) . "`n" .
        "Весь запуск: ~" . FormatCooldown(runPlannedSeconds) . "`n" .
        "Осталось: ~" . FormatCooldown(GetRunRemainingSeconds()) . "`n`n" .
        "F10 — ОСТАНОВИТЬ"
}

ShowRecordedStatus() {
    global statusTextCtrl, events, moveCount, clickCount, wheelCount, keyPressCount
    global lastSaveStatus

    statusTextCtrl.Text :=
        "■ ЗАПИСЬ ЗАВЕРШЕНА`n`n" .
        "Событий: " . events.Length . "`n" .
        "Движений: " . moveCount . "`n" .
        "Кликов: " . clickCount . "`n" .
        "Клавиш: " . keyPressCount . "`n" .
        "Колесо: " . wheelCount . "`n`n" .
        "💾 " . lastSaveStatus . "`n" .
        "Файл: recordings\last_recording.srm`n`n" .
        "Один проход: ~" . FormatCooldown(Round(GetRecordedMacroSeconds())) . "`n" .
        "Ожидаемое время запуска: " . GetEstimatedRangeText() . "`n`n" .
        "F9 — запустить"
}

ShowNoRecordingStatus() {
    global statusTextCtrl
    statusTextCtrl.Text := "! НЕТ ЗАПИСИ`n`nF8 — начать запись.`nВыполните действия и снова нажмите F8."
}

ShowStoppedStatus() {
    global statusTextCtrl, runStartTick
    global statusPanelFrozen

    statusPanelFrozen := true

    elapsed := 0
    if runStartTick > 0
        elapsed := Round((A_TickCount - runStartTick) / 1000)

    statusTextCtrl.Text :=
        "■ ОСТАНОВЛЕНО`n`n" .
        "Программа работала: " . FormatCooldown(elapsed) . "`n`n" .
        "F9 — запустить снова`n" .
        "F8 — новая запись"
}

ShowFinishedStatus() {
    global statusTextCtrl, repeatCount, playbackSpeed, testAge, testSex
    global runStartTick, runPlannedSeconds

    elapsed := 0
    if runStartTick > 0
        elapsed := Round((A_TickCount - runStartTick) / 1000)

    statusTextCtrl.Text :=
        "✓ ГОТОВО`n`n" .
        "Повторов: " . repeatCount . "`n" .
        "Последний профиль: " . testAge . " лет, " . testSex . "`n" .
        "Скорость: x" . playbackSpeed . "`n" .
        "Планировалось: ~" . FormatCooldown(runPlannedSeconds) . "`n" .
        "Фактически: " . FormatCooldown(elapsed) . "`n`n" .
        "F9 — снова`nF8 — новая запись"
}

ShowIdleStatus() {
    global statusTextCtrl, repeatCount, playbackSpeed
    global cooldownMinMinutes, cooldownMaxMinutes, ocrAvailable
    global testAge, testSex, ageMin, ageMax, randomProfileEachRepeat
    global events, lastSaveStatus
    statusTextCtrl.Text :=
        "● SMART RECORDER ГОТОВ`n`n" .
        "F1 — отдельный журнал вкл/выкл`n" .
        "F2 — вставить возраст профиля`n" .
        "F3 — вставить пол профиля`n" .
        "F4 — ответ по тексту (наведите мышь и нажмите F4)`n" .
        "F5 — новый тестовый профиль`n" .
        "F6 — OCR помощник`n" .
        "F7 — ввести OCR-подсказку`n" .
        "F8 — запись`n" .
        "F9 — старт`n" .
        "F10 — стоп`n" .
        "F11 — панель`n" .
        "F12 — настройки`n" .
        "Esc — выход`n`n" .
        "Повторов: " . repeatCount . " | Скорость: x" . playbackSpeed . "`n" .
        "Профиль: " . testAge . " лет, " . testSex . "`n" .
        "Возраст: " . ageMin . "–" . ageMax . " | Новый/повтор: " . (randomProfileEachRepeat ? "ДА" : "НЕТ") . "`n" .
        "Кулдаун: " . FormatCooldown(Round(cooldownMinMinutes * 60)) . " – " . FormatCooldown(Round(cooldownMaxMinutes * 60)) . "`n" .
        "OCR: " . (ocrAvailable ? "готов" : "нужен OCR.ahk") . "`n" .
        "Запись в памяти: " . events.Length . " событий`n" .
        "Время одного прохода: ~" . FormatCooldown(Round(GetRecordedMacroSeconds())) . "`n" .
        "Ожидаемое время запуска: " . GetEstimatedRangeText() . "`n" .
        "Файл: " . currentRecordingName . "`n" .
        "💾 " . lastSaveStatus
}

GetButtonName(button) {
    switch button {
        case "Left": return "ЛКМ"
        case "Right": return "ПКМ"
        case "Middle": return "Средняя кнопка"
        case "X1": return "Боковая 1"
        case "X2": return "Боковая 2"
        default: return button
    }
}

ToggleStatusPanel() {
    global statusGui, statusVisible

    if statusVisible {
        statusGui.Hide()
        statusVisible := false
    } else {
        statusGui.Show(
            "x20 y20 w500 h370 NoActivate"
        )
        statusVisible := true
    }
}

ToggleJournalPanel() {
    global journalGui, journalVisible

    if journalVisible {
        journalGui.Hide()
        journalVisible := false
    } else {
        journalGui.Show(
            "x20 y405 w500 h205 NoActivate"
        )
        journalVisible := true
    }
}

ToggleControlWindow() {
    global controlGui, controlVisible, recording, playing
    if recording || playing
        return
    if controlVisible {
        controlGui.Hide()
        controlVisible := false
    } else {
        controlGui.Show("x540 y20 w410 h605")
        controlVisible := true
    }
}

QuitScript() {
    global recording, events, recordingFile

    if recording {
        recording := false
        SetTimer(RecordMouseMove, 0)
        SetTimer(UpdateRecordingStatus, 0)
        StopKeyboardRecording()
    }

    ; Дополнительная страховка: сохраняем текущую запись при выходе.
    if events.Length > 0
        SaveRecordingToFile(recordingFile, false)

    SetTimer(SmartScanTimer, 0)
    ReleaseAllPlaybackInputs()
    ExitApp()
}
