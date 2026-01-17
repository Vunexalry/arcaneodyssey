; Environment Controls
#Requires AutoHotkey v2
#include Lib\WebViewToo.ahk
#include Lib\ScriptGuard1.ahk
;@Ahk2Exe-Obey U_Bin,= "%A_BasePath~^.+\.%" = "bin" ? "Cont" : "Nop" 
;@Ahk2Exe-Obey U_au, = "%A_IsUnicode%" ? 2 : 1 
;@Ahk2Exe-Obey U_Bin,= "%A_BasePath~^.+\.%" = "bin" ? "Cont" : "Nop"
;@Ahk2Exe-Obey U_au, = "%A_IsUnicode%" ? 2 : 1 
;@Ahk2Exe-PostExec "BinMod.exe" "%A_WorkFileName%"
;@Ahk2Exe-%U_Bin%  "1%U_au%2.>AUTOHOTKEY SCRIPT<. RANDOM"
;@Ahk2Exe-Cont  "%U_au%.AutoHotkeyGUI.RANDOM"
;@Ahk2Exe-Cont  /ScriptGuard2
;@Ahk2Exe-PostExec "BinMod.exe" "%A_WorkFileName%" "11.UPX." "1.UPX!.", 2
;@Ahk2Exe-UpdateManifest 0, .
#SingleInstance Force
#include Lib\OCR.ahk
#include Lib\ImagePut.ahk
#include Lib\Gdip_All.ahk

GroupAdd("ScriptGroup", "ahk_pid " DllCall("GetCurrentProcessId"))

CheckAndShowDisclaimer()

global SECRET_KEY := "Change for Opensource purposes"
global trialtime := 720.05
global trialEndTime := 0

global MacroRunning := false
global AOVunoxTrialActivated := false
global settingsTampered := false

global lastHmacFailTick := 0
global HMAC_FAILURE_COOLDOWN := 300000

global lastModResetTick := 0
global MODRESET_COOLDOWN := 300000

if !A_IsAdmin {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
        ExitApp()
    } catch {
        MsgBox("Administrator rights required.")
        ExitApp()
    }
}

currentHWID := GetDeviceID()

expectedToken := MakeAOVunoxPremiumToken(currentHWID)
storedToken := RegRead("HKCU\Software\AOVunox", "AOVunoxPremiumToken", "")

if (storedToken != "" && storedToken == expectedToken) {
    isPremium := true
} else {
    isPremium := false
}

remainingSeconds := LoadAOVunoxTrialRemainingTime()

try {
    currentModTime := FileGetTime(A_ScriptFullPath)
    storedModTime := RegRead("HKCU\Software\AOVunox", "ScriptModificationTime", "")
    
    ; Backup extraction removed for open source
    
    if (storedModTime != "" && currentModTime > storedModTime) {
        RegWrite(currentModTime, "REG_SZ", "HKCU\Software\AOVunox", "ScriptModificationTime")
        ; Backup save removed for open source
        remainingSeconds := Integer(trialtime * 60)
        SaveAOVunoxTrialRemainingTime(remainingSeconds)
        FileAppend("File modification detected at startup (newer version). Resetting trial to full time (" remainingSeconds " seconds).`n", A_ScriptDir "\Debug.log")
    }
} catch as e {
    FileAppend("Error checking file modification at startup: " e.What " (File: " A_ScriptFullPath ")`n", A_ScriptDir "\Debug.log")
}

if remainingSeconds > 0 {
    trialEndTime := A_TickCount + (remainingSeconds * 1000)
    FileAppend("Trial initialized at startup with " remainingSeconds " seconds remaining.`n", A_ScriptDir "\Debug.log")
} else {
    trialEndTime := A_TickCount
    FileAppend("Trial time was expired or invalid. Trial remains expired until file modification is detected.`n", A_ScriptDir "\Debug.log")
}

AOVunoxTrialActivated := RegRead("HKCU\Software\AOVunox", "AOVunoxTrialActivated", 0)
LoadAllSettings()

SetTimer(CheckRegistryIntegrity, 30000)

TryStartMacro(*) {
    if !CheckRegistryIntegrity(true) {
        return
    }
    
    license := GetLicenseStatus()
    remaining := LoadAOVunoxTrialRemainingTime()
    
    isExpired := (license.status == "Expired" || license.status == "Trial Expired") || (remaining <= 0 && license.status != "Premium")
    
    if (isExpired) {
        MyWindow.ExecuteScript("showModal();")
        return
    }
    StartFishingTestingMacroReal()
}

LoadAOVunoxTrialRemainingTime() {
    global currentHWID, SECRET_KEY, lastModResetTick, MODRESET_COOLDOWN, trialtime
    try {
        currentModTime := FileGetTime(A_ScriptFullPath, "M")
        storedModTime := RegRead("HKCU\Software\AOVunox", "ScriptModificationTime", "")

        ; Backup extraction removed for open source

        if (storedModTime != "" && currentModTime > storedModTime) {
            if (A_TickCount - lastModResetTick > MODRESET_COOLDOWN) {
                lastModResetTick := A_TickCount
                RegWrite(currentModTime, "REG_SZ", "HKCU\Software\AOVunox", "ScriptModificationTime")
                ; Backup save removed for open source
            } else {
            }
            return trialtime * 60
        } else if (storedModTime == "") {
            RegWrite(currentModTime, "REG_SZ", "HKCU\Software\AOVunox", "ScriptModificationTime")
            ; Backup save removed for open source
            return trialtime * 60
        }
        encrypted := RegRead("HKCU\Software\AOVunox", "AOVunoxTrialRemainingTime", "")
        if encrypted == ""
        {
            ; Backup extraction removed for open source
            return trialtime * 60
        }
        decrypted := DecryptString(encrypted, SECRET_KEY)
        if RegExMatch(decrypted, "^\d+$") {
            return Integer(decrypted)
        }
    } catch as e {
    }
    return 0
}

SaveAOVunoxTrialRemainingTime(remainingSeconds) {
    global currentHWID, SECRET_KEY
    if remainingSeconds >= 0 { 
        encrypted := EncryptString(remainingSeconds, SECRET_KEY) 
        RegWrite(encrypted, "REG_SZ", "HKCU\Software\AOVunox", "AOVunoxTrialRemainingTime")
        ; Backup save removed for open source
        FileAppend("Saved remaining trial time: " remainingSeconds " seconds`n", A_ScriptDir "\Debug.log")
        UpdateSettingsHMAC()
    } else {
        try RegDelete("HKCU\Software\AOVunox", "AOVunoxTrialRemainingTime")
        FileAppend("Deleted trial time (negative or invalid)`n", A_ScriptDir "\Debug.log")
        UpdateSettingsHMAC()
    }
}

EncryptString(str, key) {
    encrypted := ""
    keyLen := StrLen(key)
    Loop Parse, str {
        char := A_LoopField
        keyChar := SubStr(key, Mod(A_Index - 1, keyLen) + 1, 1)
        encrypted .= Chr(Ord(char) ^ Ord(keyChar))
    }
    return encrypted
}

DecryptString(encrypted, key) {
    return EncryptString(encrypted, key)
}

; BACKUP FUNCTIONS REMOVED FOR OPEN SOURCE
; These functions stored encrypted trial time and script modification time in area files (.txt files)
; to persist state across script modifications and prevent trial reset bypass
; Functionality:
;   - ExtractBackupFromAreaFile: Read encrypted data from pipe-delimited files
;   - Encrypted and stored trial remaining seconds
; Removed for open source purposes

PadKey(key, blockSize := 64) {
    if (StrLen(key) > blockSize)
        key := HashString(key)
    while (StrLen(key) < blockSize)
        key .= Chr(0)
    return key
}

HmacString(data, key) {
    key := PadKey(key, 64)
    ipad := "", opad := ""
    Loop Parse, key
        ipad .= Chr(Ord(A_LoopField) ^ 0x36), opad .= Chr(Ord(A_LoopField) ^ 0x5C)
    inner := HashString(ipad . data)
    return HashString(opad . inner)
}

ComputeSettingsHMAC() {
    files := [A_ScriptDir "\Settings.ini", A_ScriptDir "\FishCaughtArea.txt", A_ScriptDir "\FishTriggerArea.txt", A_ScriptDir "\BaitArea.txt"]
    data := ""
    for file in files {
        data .= file ":"
        if FileExist(file)
            data .= FileRead(file)
        data .= "|"
    }
    return HmacString(data, SECRET_KEY)
}

UpdateSettingsHMAC() {
    global lastHmacFailTick, HMAC_FAILURE_COOLDOWN
    try {
        hmac := ComputeSettingsHMAC()
        FileDelete(A_ScriptDir "\Settings.hmac")
        FileAppend(hmac, A_ScriptDir "\Settings.hmac")
        WriteDebug("Updated Settings HMAC: " hmac)
        return true
    } catch {
        if (A_TickCount - lastHmacFailTick > HMAC_FAILURE_COOLDOWN) {
            lastHmacFailTick := A_TickCount
            WriteDebug("Failed to update Settings HMAC")
        }
        return false
    }
} 

AppendTamperLog(msg) {
    try {
        FileAppend(A_Now " - " msg "`n", A_ScriptDir "\Tamper.log")
        WriteDebug("Tamper logged: " msg)
    } catch { 

    }
}

VerifySettingsHMAC(stopOnTamper := false) {
    try {
        if !FileExist(A_ScriptDir "\Settings.hmac") {
            UpdateSettingsHMAC()
            return true
        }
        stored := Trim(FileRead(A_ScriptDir "\Settings.hmac"))
        current := ComputeSettingsHMAC()
        if (stored != current) {
            AppendTamperLog("Settings HMAC mismatch. Stored: " SubStr(stored, 1, 16) "... Current: " SubStr(current, 1, 16) "...")
            settingsTampered := true
            WriteDebug("Settings integrity check FAILED")
            if (stopOnTamper) {
                MacroRunning := false
                try {
                    MyWindow.ExecuteScript("if(window.showHostToast) window.showHostToast('Settings integrity check failed. The macro has been stopped.', 'error');")
                } catch {

                }
            }
            return false
        }
        settingsTampered := false
        return true
    } catch {
        WriteDebug("Error verifying settings HMAC")
        return false
    }
}

SaveAndExit(*) {
    global trialEndTime, isPremium, MacroRunning
    MacroRunning := false

    if !isPremium {
        remaining := trialEndTime - A_TickCount
        if remaining > 0
            SaveAOVunoxTrialRemainingTime(Floor(remaining / 1000))
        else
            SaveAOVunoxTrialRemainingTime(0)
    }
    ExitApp()
}


GoPremium(*) {
    MyWindow.ExecuteScript("document.getElementById('goPremiumModal').style.display = 'block';")
}

RemovePremium(*) {
    try {
        result1 := RegDelete("HKCU\Software\AOVunox", "AOVunoxPremiumToken")
        result2 := RegDelete("HKCU\Software\AOVunox", "AOVunoxPremiumSerial")
        result3 := RegDelete("HKCU\Software\AOVunox", "AOVunoxTrialActivated")
        isPremium := false
        
        try {
            FileAppend("Starting premium removal process...`n", A_ScriptDir "\Debug.log")
            FileAppend("RegDelete AOVunoxPremiumToken: " result1 " (1=success, 0=failure, empty=key not found)`n", A_ScriptDir "\Debug.log")
            FileAppend("RegDelete AOVunoxPremiumSerial: " result2 " (1=success, 0=failure, empty=key not found)`n", A_ScriptDir "\Debug.log")
            FileAppend("RegDelete AOVunoxTrialActivated: " result3 " (1=success, 0=failure, empty=key not found)`n", A_ScriptDir "\Debug.log")
            FileAppend("Premium removal completed successfully.`n", A_ScriptDir "\Debug.log")
        } catch {

        }
        
        return true
    } catch as e {
        try {
            FileAppend("Critical error in RemovePremium: " e.Message "`n", A_ScriptDir "\Debug.log")
        } catch {

        }
        if (InStr(e.Message, "file specified")) {

            return true
        }
        return false
    }
}

; PREMIUM SERIAL GENERATOR REMOVED FOR OPEN SOURCE
; This function generated device-specific serial numbers from hardware ID hashes
; Removed for open source purposes

GetHWID() {
    return GetDeviceID()
}

; PREMIUM GENERATOR FUNCTIONS REMOVED FOR OPEN SOURCE
; These functions handled:
;   - ValidateOTP: Verified premium access codes and generated HWID-based tokens
;   - GenerateRandomSerial: Created device-specific serial numbers from hardware hash
;   - EncryptSerial: Caesar cipher encryption of serial with HWID-based shift
;   - MakeAOVunoxPremiumToken: Generated HMAC tokens for premium status verification
; Removed for open source purposes

CheckAndShowDisclaimer() {
    global disclaimerAccepted, MyDisclaimerGUI
    
    val := IniRead(A_ScriptDir "\Settings.ini", "Disclaimer", "accepted", 0)
    if (val = "1" || val = 1) {
        disclaimerAccepted := true
        return
    }
    
    disclaimerAccepted := false
    
    MyDisclaimerGUI := Gui()
    MyDisclaimerGUI.Add("Text",, "Disclaimer & User Acknowledgement")
        MyDisclaimerGUI.SetFont("s12", "Segoe UI")
    MyDisclaimerGUI.Add("Edit", "w610 h200 -Wrap readonly", "
    (
    This Macro is provided 'as-is', without warranties of any kind, express or implied.
    By using this macro you acknowledge and accept all risks, and agree that
    the author is not liable for any bans, account actions, data loss, or other damages
    arising from its use.

    You are responsible for ensuring your conduct complies with the game's 
    Terms of Service and for being present and able to respond 
    while the macro is active.
    )")
    MyDisclaimerGUI.SetFont("s9", "Segoe UI")
    MyDisclaimerGUI.Add("Checkbox", "v_disclaimer w600", "I accept the terms and conditions")
    MyDisclaimerGUI.Add("Button", "w290 h30 x10", "Accept").OnEvent("Click", AcceptDisclaimer)
    MyDisclaimerGUI.Add("Button", "w290 h30 x+10", "Decline").OnEvent("Click", DeclineDisclaimer)
    
    MyDisclaimerGUI.Show("w600 h300 Center")
    
    while (!disclaimerAccepted) {
        Sleep(100)
    }
    
    MyDisclaimerGUI.Destroy()
}

AcceptDisclaimer(GuiObjParam, InfoParam) {
    global disclaimerAccepted, MyDisclaimerGUI
    
    if !MyDisclaimerGUI["_disclaimer"].Value {
        MsgBox("Please check the box to accept the terms and conditions.")
        return
    }
    
    IniWrite(1, A_ScriptDir "\Settings.ini", "Disclaimer", "accepted")
    disclaimerAccepted := true
}

DeclineDisclaimer(GuiObjParam, InfoParam) {
    ExitApp()
}
CheckRegistryIntegrity(stopMacroOnTamper := false) {
    global currentHWID, isPremium, MacroRunning, trialEndTime, trialtime, lastModResetTick, MODRESET_COOLDOWN
    
    try {
        currentModTime := FileGetTime(A_ScriptFullPath)
        storedModTime := RegRead("HKCU\Software\AOVunox", "ScriptModificationTime", "")
        
        if (storedModTime != "" && currentModTime > storedModTime) {
            if (A_TickCount - lastModResetTick > MODRESET_COOLDOWN) {
                lastModResetTick := A_TickCount
                RegWrite(currentModTime, "REG_SZ", "HKCU\Software\AOVunox", "ScriptModificationTime")
                ; Backup save removed for open source
                trialEndTime := A_TickCount + (Integer(trialtime * 60) * 1000)
                SaveAOVunoxTrialRemainingTime(Integer(trialtime * 60))
                FileAppend("File modification detected at " A_Now " (newer version). Resetting trial to full time (720 minutes).`n", A_ScriptDir "\Debug.log")
            }
        }
        
        ; PREMIUM VALIDATION REMOVED FOR OPEN SOURCE
        ; Previously checked if storedSerial/storedToken matched expected values from GenerateRandomSerial and MakeAOVunoxPremiumToken
        ; If tampering detected, would revoke premium access
        ; Removed for open source purposes
    } catch as e {
        FileAppend("Error in CheckRegistryIntegrity: " e.Message "`n", A_ScriptDir "\Debug.log")
        return false
    }
    
    return true
}

GetLicenseStatus() {
    global isPremium

    if isPremium {
        return { status: "Premium", remaining: -1 }
    }

    remaining := GetAOVunoxTrialRemainingTime()

    if (remaining <= 0) {
        return { status: "Expired", remaining: 0 }
    }

    return { status: "Trial", remaining: remaining }
}

GetAOVunoxTrialRemainingTime() {
    global isPremium, trialEndTime, trialtime
    if isPremium {
        return -1
    }

    computedRemaining := Max(0, Floor((trialEndTime - A_TickCount) / 1000))
    try {
        savedRemaining := LoadAOVunoxTrialRemainingTime()
    } catch as e {
        savedRemaining := computedRemaining
    }

    if (savedRemaining > computedRemaining) {
        trialEndTime := A_TickCount + (savedRemaining * 1000)
        return savedRemaining
    }

    return computedRemaining
}

GetDeviceID() {
    try {
        uuid := ComObjGet("winmgmts:").ExecQuery("SELECT UUID FROM Win32_ComputerSystemProduct").ItemIndex(0).UUID
        cpu := ComObjGet("winmgmts:").ExecQuery("SELECT ProcessorId FROM Win32_Processor").ItemIndex(0).ProcessorId
        return HashString(uuid "|" cpu)
    } catch {
        return HashString(RegRead("HKLM\SOFTWARE\Microsoft\Cryptography", "MachineGuid"))
    }
}

HashString(str) {
    return StrUpper(
        Format("{:X}",
            DllCall("ntdll\RtlComputeCrc32", "UInt", 0, "Ptr", StrPtr(str), "UInt", StrLen(str), "UInt")
        )
    )
}

if (A_IsCompiled) {
    try {
        WebViewCtrl.CreateFileFromResource((A_PtrSize * 8) "bit\WebView2Loader.dll", WebViewCtrl.TempDir)
        dllPath := WebViewCtrl.TempDir "\" (A_PtrSize * 8) "bit\WebView2Loader.dll"
        if FileExist(dllPath) {
            WebViewSettings := {DllPath: dllPath}
            WriteDebug("Using extracted WebView2Loader.dll at " dllPath)
        } else {
            WebViewSettings := {}
            WriteDebug("Extracted WebView2Loader.dll not found at " dllPath "; falling back to default")
        }
    } catch {
        WebViewSettings := {}
        WriteDebug("Failed to extract WebView2Loader.dll; falling back to default")
    }
} else {
    WebViewSettings := {}
}

MyWindow := WebViewGui("-Resize -Caption",,,WebViewSettings)
MyWindow.OnEvent("Close", (*) => ExitApp())


MyWindow.Navigate(A_ScriptDir "\Pages\GUI.html")
MyWindow.Show("w350 h625 ")

WinShow("ahk_id " MyWindow.hWnd) 

Sleep(250)

MyWindow.AddHostObjectToScript("ahk", {gui: MyWindow})
MyWindow.AddHostObjectToScript("MacroFuncs", {
    start: StartMacro,
    reload: RestartMacro,
    close: SaveAndExit,
    saveFishTrigger: SaveFishTrigger,
    selectFishCaughtArea: SelectFishCaughtArea,
    selectFishTriggerArea: SelectFishTriggerArea,
    selectBaitArea: SelectBaitArea,
    updateMethod: UpdateMethod,
    updateFishTriggerConfidence: UpdateFishTriggerConfidence,
    updateKey: UpdateKey,
    updateSecondaryKey: UpdateSecondaryKey,
    updateToggleSecondary: UpdateToggleSecondary,
    getLicenseStatus: GetLicenseStatus,
    goPremium: GoPremium,
    removePremium: RemovePremium,
    getFishTriggerConfidence: GetFishTriggerConfidence,
    getCurrentMethod: GetCurrentMethod,
    getCurrentKey: GetCurrentKey,
    getCurrentSecondaryKey: GetCurrentSecondaryKey,
    getAOVunoxTrialRemainingTime: GetAOVunoxTrialRemainingTime,
    loadAllSettings: LoadAllSettings,
    getToggleSecondary: (*) => toggleSecondary,
    getAOVunoxPremiumSerial: GetAOVunoxPremiumSerial,
    getHWID: GetHWID,
    validateOTP: ValidateOTP  ; REMOVED FOR OPEN SOURCE - Premium validation function
})

CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")


global selX, selY, selW := 200, selH := 150, selecting := false, rectHwnd := 0, pToken := 0, isDragging := false, dragOffsetX, dragOffsetY, borderWidth := 4, currentArea := ""
global screenshotModeActive := false

if !pToken {
    if !pToken := Gdip_Startup() {
        MsgBox("Gdiplus failed to start. Please ensure you have gdiplus on your system")
        ExitApp()
    }
}

global xpos_fish_caught := 0, ypos_fish_caught := 0
global xpos_fish_trigger := 0, ypos_fish_trigger := 0
global fish_caught_x1 := 0, fish_caught_y1 := 0, fish_caught_x2 := 0, fish_caught_y2 := 0
global fish_trigger_x1 := 0, fish_trigger_y1 := 0, fish_trigger_x2 := 0, fish_trigger_y2 := 0
global bait_x1 := 0, bait_y1 := 0, bait_x2 := 0, bait_y2 := 0  
global fish_caught_confidence := 90
global fish_trigger_confidence := 90
global current_method := "normal"  
global currentScreenshotType := ""
global current_key := "0" 
global current_secondary_key := "0"
global clickTimeout := false
global wait1Timeout := false
global waitTimeout := false
global toggleSecondary := false

xpos_fish_caught := IniRead(A_ScriptDir "\Settings.ini", "Positions", "xpos_fish_caught", 0)
ypos_fish_caught := IniRead(A_ScriptDir "\Settings.ini", "Positions", "ypos_fish_caught", 0)
xpos_fish_trigger := IniRead(A_ScriptDir "\Settings.ini", "Positions", "xpos_fish_trigger", 0)
ypos_fish_trigger := IniRead(A_ScriptDir "\Settings.ini", "Positions", "xpos_fish_trigger", 0)
fish_caught_confidence := IniRead(A_ScriptDir "\Settings.ini", "Confidence", "fish_caught_confidence", 90)
fish_trigger_confidence := IniRead(A_ScriptDir "\Settings.ini", "Confidence", "fish_trigger_confidence", 90)
current_method := IniRead(A_ScriptDir "\Settings.ini", "Settings", "current_method", "normal")
current_secondary_key := IniRead(A_ScriptDir "\Settings.ini", "Settings", "current_secondary_key", "0")

if FileExist(A_ScriptDir "\FishCaughtArea.txt") {
    areaData := FileRead(A_ScriptDir "\FishCaughtArea.txt")
    area := StrSplit(areaData, "|")
    fish_caught_x1 := area[1]
    fish_caught_y1 := area[2]
    fish_caught_x2 := area[3]
    fish_caught_y2 := area[4]
}
if FileExist(A_ScriptDir "\FishTriggerArea.txt") {
    areaData := FileRead(A_ScriptDir "\FishTriggerArea.txt")
    area := StrSplit(areaData, "|")
    fish_trigger_x1 := area[1]
    fish_trigger_y1 := area[2]
    fish_trigger_x2 := area[3]
    fish_trigger_y2 := area[4]
}
if FileExist(A_ScriptDir "\BaitArea.txt") {
    areaData := FileRead(A_ScriptDir "\BaitArea.txt")
    area := StrSplit(areaData, "|")
    bait_x1 := area[1]
    bait_y1 := area[2]
    bait_x2 := area[3]
    bait_y2 := area[4]
}

Hotkey("F1", CameraAdjust)
Hotkey("F6", TryStartMacro)
Hotkey("F7", RestartMacro)
Hotkey("F9", TestFishTrigger)
Hotkey("F4", SaveAndExit)

StartMacro(*) {
TryStartMacro()
}

StartFishingTestingMacroReal() {
    ; FISHING LOOP FUNCTIONS REMOVED FOR OPEN SOURCE
    ; These functions implemented the core fishing automation:
    ;
    ; StartFishingTestingMacroReal: Setup function that:
    ;   - Waited for Roblox window (ahk_exe robloxplayerbeta.exe)
    ;   - Pressed mousewheel down 7 times (zoom camera adjustment)
    ;   - Sent Tab twice (UI navigation)
    ;   - Called main FishingTestingMacro()
    ;
    ; RestartMacro: Trial time saving before reload
    ;
    ; FishingTestingMacro: Main loop that:
    ;   - Validated fishing area coordinates were set (4 coordinate points per area)
    ;   - Sent primary key (fishing action hotkey, e.g., 'e')
    ;   - Waited 1.5 seconds (action cooldown)
    ;   - Called SelectBait() to pick lure type
    ;   - Clicked mouse and waited 1.5 seconds
    ;   - WaitForImageInArea: Searched for FishTrigger.png image in defined area (~2 min timeout)
    ;   - Triple clicked mouse rapidly (3 sets of 3 clicks) to interact with fish
    ;   - IsTextInArea: Used OCR to detect 'caught' text (confirming successful catch)
    ;   - Optional secondary key toggle: Every 5 iterations, sent secondary key (e.g., lure swap)
    ;   - Looped indefinitely until stopped
    ;
    ; Fishing functionalities removed to prevent copying and bypassing the macro entirely
}

RestartMacro(*) {
    ; FISHING LOOP FUNCTIONS REMOVED FOR OPEN SOURCE
    ; Previously saved trial time before reloading script
    ; Fishing functionalities removed to prevent copying and bypassing the macro entirely
}

FishingTestingMacro() {
    ; FISHING LOOP FUNCTIONS REMOVED FOR OPEN SOURCE
    ; Main fishing automation loop
    ; Fishing functionalities removed to prevent copying and bypassing the macro entirely
}

SelectBait(baitType) {
    sendmode "event"
    Sleep(150)
    if (baitType = "normal") {
        return
    }
    Sleep(50)

    baitText := ""
    if (baitType = "swarm") {
        baitText := "swarm"
    } else if (baitType = "giant") {
        baitText := "giant"
    } else if (baitType = "magic") {
        baitText := "magic"
    } else {
        MsgBox("Invalid bait type selected.")
        return
    }
    
    if (bait_x1 = 0 || bait_y1 = 0 || bait_x2 = 0 || bait_y2 = 0) {
        MsgBox("Bait Area not set. Please set it before starting the macro.")
        return
    }
    x1 := bait_x1, y1 := bait_y1, x2 := bait_x2, y2 := bait_y2
    
    if (baitType = "magic") {
        foundNormal := ""
        Loop 3 {
            try {
                result := OCR.FromRect(x1, y1, x2 - x1, y2 - y1, {scale: 3, grayscale: 1})
                foundNormal := result.FindString("normal")
                if foundNormal
                    break
            } catch {
            }
            Sleep(50)
        }
        
        if foundNormal {
            normalClickX := foundNormal.x + (foundNormal.w / 2)
            normalClickY := foundNormal.y + (foundNormal.h / 2)
            MouseMove(normalClickX, normalClickY, 5)
            Sleep(150)
            SendInput("{WheelDown}")
            Sleep(150)
        }
    }
    
    found := ""
    Loop 3 {
        try {
            result := OCR.FromRect(x1, y1, x2 - x1, y2 - y1, {scale: 3, grayscale: 1})
            found := result.FindString(baitText)
            if found
                break
        } catch {
        }
        Sleep(50)
    }
    
    if !found {
        return
    }
    
    clickX := found.x + (found.w / 2)
    clickY := found.y + (found.h / 2)
    Sleep(150)
    mousemove(clickx, clicky, 5)
    sleep(150)
    mouseclick()
    sleep(150)
    MouseMove(350, 0, 3, "R")  
    Sleep(150)
}

CameraAdjust(*){
Loop 7 {
        Click "WheelDown"
        Sleep(250)       
    }
Send "{Tab}"
    Sleep(1500)
Send "{Tab}"
    Sleep(150)
}

TestFishTrigger(*) {
    if (!FileExist(A_ScriptDir "\FishTrigger.png")) {
        MsgBox("FishTrigger.png not found!")
        return
    }
    if (fish_trigger_x1 = 0 || fish_trigger_y1 = 0 || fish_trigger_x2 = 0 || fish_trigger_y2 = 0) {
        MsgBox("Fish Trigger Area not set!")
        return
    }
    MsgBox("Testing FishTrigger image in area: " fish_trigger_x1 "," fish_trigger_y1 " to " fish_trigger_x2 "," fish_trigger_y2)
    result := IsImageInArea(A_ScriptDir "\FishTrigger.png", fish_trigger_x1, fish_trigger_y1, fish_trigger_x2, fish_trigger_y2)
    if result {
        MsgBox("FishTrigger image FOUND!")
    } else {
        MsgBox("FishTrigger image NOT found. Check image, area, or screen.")
    }
}

SaveFishTrigger(*) {
    global currentScreenshotType, screenshotModeActive
    currentScreenshotType := "trigger"
    screenshotModeActive := true
    CreateScreenshotRect()
}

CreateScreenshotRect() {
    global selX, selY, selW, selH, rectHwnd, pToken, borderWidth
    if rectHwnd {
        WinClose("ahk_id " rectHwnd)
    }
    if !pToken {
        if !pToken := Gdip_Startup() {
            MsgBox("Gdiplus failed to start. Please ensure you have gdiplus on your system")
            return
        }
    }

    Width := selW, Height := selH

    GuiRect := Gui("-Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs")
    
    MouseGetPos(&selX, &selY)
    
    GuiRect.Show("x" selX " y" selY " NA")
    rectHwnd := WinExist()

    DrawScreenshotRect()

    OnMessage(0x201, WM_LBUTTONDOWN)
    OnMessage(0x202, WM_LBUTTONUP)
    ToolTip("Drag the rectangle to position the screenshot area. Use arrow keys to resize. Press F2 to capture.")
}

DrawScreenshotRect() {
    global selX, selY, selW, selH, rectHwnd, borderWidth, pToken
    Width := selW, Height := selH

    hbm := CreateDIBSection(Width, Height)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    Gdip_SetSmoothingMode(G, 4)

    pBrushFill := Gdip_BrushCreateSolid(0x01000000)
    Gdip_FillRectangle(G, pBrushFill, 0, 0, Width, Height)
    Gdip_DeleteBrush(pBrushFill)

    pPen := Gdip_CreatePen(0xFFFF0000, borderWidth)
    Gdip_DrawRectangle(G, pPen, borderWidth//2, borderWidth//2, Width - borderWidth, Height - borderWidth)
    Gdip_DeletePen(pPen)

    UpdateLayeredWindow(rectHwnd, hdc, selX, selY, Width, Height)

    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(G)
}

SelectFishCaughtArea(*) {
    DragSelectFishCaughtArea()
}

DragSelectFishCaughtArea() {
    global RectGui, startX, startY, endX, endY, dragging, hHook
    RectGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    RectGui.BackColor := "00FF00"
    RectGui.Show("Hide")
    startX := 0, startY := 0, endX := 0, endY := 0, dragging := false
    hHook := DllCall("SetWindowsHookEx", "Int", 14, "Ptr", CallbackCreate(MouseProcFishCaught, "Fast"), "Ptr", 0, "UInt", 0)
    if (!hHook) {
        MsgBox("Failed to install mouse hook. Try running as administrator.")
        return
    }
    while (hHook)
        Sleep(10)
}

IsTextInArea(text, x1, y1, x2, y2) {
    local w := x2 - x1
    local h := y2 - y1
    if (w <= 0 || h <= 0) {
        return false
    }
    Loop 3 {
        try {
            result := OCR.FromRect(x1, y1, w, h, {scale: 3, grayscale: 1})
            found := result.FindString(text)
            if IsSet(found) {
                return true
            }
        } catch {
            Sleep(50)
        }
    }
    return false
}

MouseProcFishCaught(nCode, wParam, lParam) {
    global startX, startY, endX, endY, dragging, hHook, fish_caught_x1, fish_caught_y1, fish_caught_x2, fish_caught_y2, RectGui
    local x := 0, y := 0, w := 0, h := 0
    if (nCode < 0)
        return DllCall("CallNextHookEx", "Ptr", hHook, "Int", nCode, "Ptr", wParam, "Ptr", lParam)
    if (wParam = 0x201) {
        if (!dragging) {
            MouseGetPos(&startX, &startY)
            dragging := true
            RectGui.Show("x" startX " y" startY " w1 h1")
        }
    } else if (wParam = 0x200) {
        if (dragging) {
            MouseGetPos(&endX, &endY)
            x := Min(startX, endX)
            y := Min(startY, endY)
            w := Abs(endX - startX)
            h := Abs(endY - startY)
            RectGui.Show("x" x " y" y " w" w " h" h)
        }
    } else if (wParam = 0x202) {
        if (dragging) {
            MouseGetPos(&endX, &endY)
            dragging := false
            fish_caught_x1 := Min(startX, endX)
            fish_caught_y1 := Min(startY, endY)
            fish_caught_x2 := Max(startX, endX)
            fish_caught_y2 := Max(startY, endY)
            RectGui.Destroy()
            DllCall("UnhookWindowsHookEx", "Ptr", hHook)
            hHook := 0
            areaString := fish_caught_x1 "|" fish_caught_y1 "|" fish_caught_x2 "|" fish_caught_y2
            try FileDelete(A_ScriptDir "\FishCaughtArea.txt")
            FileAppend(areaString, A_ScriptDir "\FishCaughtArea.txt")
            MsgBox("Area saved to FishCaughtArea.txt as:`n" areaString, "Fish Caught Area Saved", 64)
        }
    }
   return DllCall("CallNextHookEx", "Ptr", hHook, "Int", nCode, "Ptr", wParam, "Ptr", lParam)
}

SelectFishTriggerArea(*) {
    DragSelectFishTriggerArea()
}

DragSelectFishTriggerArea() {
    global RectGui, startX, startY, endX, endY, dragging, hHook
    RectGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    RectGui.BackColor := "00FF00"
    RectGui.Show("Hide")
    startX := 0, startY := 0, endX := 0, endY := 0, dragging := false
    hHook := DllCall("SetWindowsHookEx", "Int", 14, "Ptr", CallbackCreate(MouseProcFishTrigger, "Fast"), "Ptr", 0, "UInt", 0)
    if (!hHook) {
        MsgBox("Failed to install mouse hook. Try running as administrator.")
        return
    }
    while (hHook)
        Sleep(10)
}

MouseProcFishTrigger(nCode, wParam, lParam) {
    global startX, startY, endX, endY, dragging, hHook, fish_trigger_x1, fish_trigger_y1, fish_trigger_x2, fish_trigger_y2, RectGui
    if (nCode < 0)
        return DllCall("CallNextHookEx", "Ptr", hHook, "Int", nCode, "Ptr", wParam, "Ptr", lParam)
    if (wParam = 0x201) {
        if (!dragging) {
            MouseGetPos(&startX, &startY)
            dragging := true
            RectGui.Show("x" startX " y" startY " w1 h1")
        }
    } else if (wParam = 0x200) {
        if (dragging) {
            MouseGetPos(&endX, &endY)
            x := Min(startX, endX)
            y := Min(startY, endY)
            w := Abs(endX - startX)
            h := Abs(endY - startY)
            RectGui.Show("x" x " y" y " w" w " h" h)
        }
    } else if (wParam = 0x202) {
        if (dragging) {
            MouseGetPos(&endX, &endY)
            dragging := false
            fish_trigger_x1 := Min(startX, endX)
            fish_trigger_y1 := Min(startY, endY)
            fish_trigger_x2 := Max(startX, endX)
            fish_trigger_y2 := Max(startY, endY)
            RectGui.Destroy()
            DllCall("UnhookWindowsHookEx", "Ptr", hHook)
            hHook := 0
            areaString := fish_trigger_x1 "|" fish_trigger_y1 "|" fish_trigger_x2 "|" fish_trigger_y2
            try FileDelete(A_ScriptDir "\FishTriggerArea.txt")
            FileAppend(areaString, A_ScriptDir "\FishTriggerArea.txt")
            MsgBox("Area saved to FishTriggerArea.txt as:`n" areaString, "Fish Trigger Area Saved", 64)
        }
    }
    return DllCall("CallNextHookEx", "Ptr", hHook, "Int", nCode, "Ptr", wParam, "Ptr", lParam)
}

SelectBaitArea(*) {
    DragSelectBaitArea()
}

DragSelectBaitArea() {
    global RectGui, startX, startY, endX, endY, dragging, hHook
    RectGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    RectGui.BackColor := "00FF00"
    RectGui.Show("Hide")
    startX := 0, startY := 0, endX := 0, endY := 0, dragging := false
    hHook := DllCall("SetWindowsHookEx", "Int", 14, "Ptr", CallbackCreate(MouseProcBaitArea, "Fast"), "Ptr", 0, "UInt", 0)
    if (!hHook) {
        MsgBox("Failed to install mouse hook. Try running as administrator.")
        return
    }
    while (hHook)
        Sleep(10)
}

MouseProcBaitArea(nCode, wParam, lParam) {
    global startX, startY, endX, endY, dragging, hHook, bait_x1, bait_y1, bait_x2, bait_y2, RectGui
    if (nCode < 0)
        return DllCall("CallNextHookEx", "Ptr", hHook, "Int", nCode, "Ptr", wParam, "Ptr", lParam)
    if (wParam = 0x201) {
        if (!dragging) {
            MouseGetPos(&startX, &startY)
            dragging := true
            RectGui.Show("x" startX " y" startY " w1 h1")
        }
    } else if (wParam = 0x200) {
        if (dragging) {
            MouseGetPos(&endX, &endY)
            x := Min(startX, endX)
            y := Min(startY, endY)
            w := Abs(endX - startX)
            h := Abs(endY - startY)
            RectGui.Show("x" x " y" y " w" w " h" h)
        }
    } else if (wParam = 0x202) {
        if (dragging) {
            MouseGetPos(&endX, &endY)
            dragging := false
            bait_x1 := Min(startX, endX)
            bait_y1 := Min(startY, endY)
            bait_x2 := Max(startX, endX)
            bait_y2 := Max(startY, endY)
            RectGui.Destroy()
            DllCall("UnhookWindowsHookEx", "Ptr", hHook)
            hHook := 0
            areaString := bait_x1 "|" bait_y1 "|" bait_x2 "|" bait_y2
            try FileDelete(A_ScriptDir "\BaitArea.txt")
            FileAppend(areaString, A_ScriptDir "\BaitArea.txt")
            MsgBox("Area saved to BaitArea.txt as:`n" areaString, "Bait Area Saved", 64)
        }
    }
    return DllCall("CallNextHookEx", "Ptr", hHook, "Int", nCode, "Ptr", wParam, "Ptr", lParam)
}

CreateSelectionRect() {
    global selX, selY, selW, selH, rectHwnd, borderWidth
    if rectHwnd {
        WinClose("ahk_id " rectHwnd)
    }

    Width := selW, Height := selH

    GuiRect := Gui("-Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs")
    
    MouseGetPos(&selX, &selY)
    
    GuiRect.Show("x" selX " y" selY " NA")
    rectHwnd := WinExist()

    DrawRect()

    OnMessage(0x201, WM_LBUTTONDOWN)
    OnMessage(0x202, WM_LBUTTONUP)
    ToolTip("Drag the rectangle to position the area. Use arrow keys to resize. Press F2 to save the " currentArea " area.")
}

DrawRect() {
    global selX, selY, selW, selH, rectHwnd, borderWidth
    Width := selW, Height := selH

    hbm := CreateDIBSection(Width, Height)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    Gdip_SetSmoothingMode(G, 4)

    pBrushFill := Gdip_BrushCreateSolid(0x01000000)
    Gdip_FillRectangle(G, pBrushFill, 0, 0, Width, Height)
    Gdip_DeleteBrush(pBrushFill)

    pPen := Gdip_CreatePen(0xFFFF0000, borderWidth)
    Gdip_DrawRectangle(G, pPen, borderWidth//2, borderWidth//2, Width - borderWidth, Height - borderWidth)
    Gdip_DeletePen(pPen)

    UpdateLayeredWindow(rectHwnd, hdc, selX, selY, Width, Height)

    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(G)
}

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global rectHwnd, isDragging, dragOffsetX, dragOffsetY
    if (hwnd == rectHwnd) {
        isDragging := true
        MouseGetPos(&startX, &startY)
        WinGetPos(&winX, &winY, , , "ahk_id " rectHwnd)
        dragOffsetX := startX - winX
        dragOffsetY := startY - winY
        SetTimer(MoveScreenshotRect, 10)
    }
}

WM_LBUTTONUP(wParam, lParam, msg, hwnd) {
    global isDragging
    if (hwnd == rectHwnd) {
        isDragging := false
        SetTimer(MoveScreenshotRect, 0)
    }
}

MoveScreenshotRect() {
    global isDragging, dragOffsetX, dragOffsetY, rectHwnd, selX, selY
    if isDragging {
        if !GetKeyState("LButton") {
            isDragging := false
            SetTimer(MoveScreenshotRect, 0)
            return
        }
        MouseGetPos(&currX, &currY)
        selX := currX - dragOffsetX
        selY := currY - dragOffsetY
        WinMove(selX, selY, , , "ahk_id " rectHwnd)
    }
}

#HotIf IsSet(rectHwnd) && rectHwnd
Right:: {
try{
    global selW
    selW += 10
    DrawScreenshotRect()
}
catch {
    }
}
Left:: {
try {
    global selW
    selW := Max(selW - 10, 20)
    DrawScreenshotRect()
}
catch {
    }
}
Down:: {
try{
    global selH
    selH += 10
    DrawScreenshotRect()
}
catch {
    }
}
Up:: {
try{
    global selH
    selH := Max(selH - 10, 20)
    DrawScreenshotRect()
}
catch {
    }
}
#HotIf

F2:: {
    global selX, selY, selW, selH, rectHwnd, borderWidth, currentScreenshotType, screenshotModeActive
    if !screenshotModeActive {
        ToolTip()
        return
    }
    if rectHwnd && WinExist("ahk_id " rectHwnd) {

        innerX := selX + borderWidth
        innerY := selY + borderWidth
        innerW := selW - 2 * borderWidth
        innerH := selH - 2 * borderWidth

        WinClose("ahk_id " rectHwnd)
        rectHwnd := 0

        if (currentScreenshotType = "caught") {
            filePath := A_ScriptDir "\FishCaught.png"
            msg := "Fish Caught screenshot saved as FishCaught.png"
        } else if (currentScreenshotType = "trigger") {
            filePath := A_ScriptDir "\FishTrigger.png"
            msg := "Fish Trigger screenshot saved as FishTrigger.png"
        } else {
            ToolTip("Unknown screenshot type!")
            Sleep(2000)
            ToolTip()
            return
        }
        
        ImagePutFile([innerX, innerY, innerW, innerH], filePath)
        ToolTip(msg)
        Sleep(2000)
        ToolTip()
        
        currentScreenshotType := ""
        screenshotModeActive := false
    } else {
        ToolTip("No selection rectangle active!")
        Sleep(2000)
        ToolTip()
    }
}

WaitForImageInArea(imagePath, x1, y1, x2, y2) {
    global fish_trigger_confidence, wait1Timeout
    local Confidence := Round((100 - fish_trigger_confidence) * 255 / 100)
    ToolTip("Searching in area (" x1 "," y1 ") to (" x2 "," y2 ") with Confidence *" Confidence " (confidence " fish_trigger_confidence "%)...")
    wait1Timeout := false
    SetTimer(Wait1TimeoutHandler, -120000)
    Loop {
        if wait1Timeout {
            wait1Timeout := false
            SetTimer(Wait1TimeoutHandler, 0)
            ToolTip("Timeout: Image not found within 2 Minutes. Restarting...")
            Sleep(150)
            ToolTip()
	    Send(current_key)
            Sleep(250)
            return false
        }
        if ImageSearch(&Px, &Py, x1, y1, x2, y2, "*" Confidence " " imagePath) {
            SetTimer(Wait1TimeoutHandler, 0)
            ToolTip("Image found at (" Px "," Py ") with Confidence *" Confidence "!")
            Sleep(150)
            ToolTip()
            return true
        }
        Sleep(10)
    }
}

Wait1TimeoutHandler() {
    global wait1Timeout
    wait1Timeout := true
}

WaitTimeoutHandler() {
    global waitTimeout
    waitTimeout := true
}

IsImageInArea(imagePath, x1, y1, x2, y2) {
    if InStr(imagePath, "FishTrigger") {
        global fish_trigger_confidence
        local confidence := fish_trigger_confidence
    }
local Confidence := Round((100 - confidence) * 255 / 100)
    ToolTip("Checking for " imagePath " in area (" x1 "," y1 ") to (" x2 "," y2 ") with Confidence *" Confidence " (confidence " confidence "%)...")
    local result := ImageSearch(&Px, &Py, x1, y1, x2, y2, "*" Confidence " " imagePath)
    if result {
        ToolTip("Image found at (" Px "," Py ") with Confidence *" Confidence "!")
    } else {
        ToolTip("Image NOT found with Confidence *" Confidence ".")
    }
    Sleep(1000)
    ToolTip()
    return result
}

LoadAllSettings() {
    global current_method, current_key, current_secondary_key, fish_trigger_confidence, fish_caught_confidence, xpos_fish_caught, ypos_fish_caught, xpos_fish_trigger, ypos_fish_trigger, fish_caught_x1, fish_caught_y1, fish_caught_x2, fish_caught_y2, fish_trigger_x1, fish_trigger_y1, fish_trigger_x2, fish_trigger_y2, bait_x1, bait_y1, bait_x2, bait_y2, toggleSecondary
    current_method := IniRead(A_ScriptDir "\Settings.ini", "Settings", "current_method", "normal")
    current_key := IniRead(A_ScriptDir "\Settings.ini", "Settings", "current_key", "0")
    current_secondary_key := IniRead(A_ScriptDir "\Settings.ini", "Settings", "current_secondary_key", "0")
    toggleSecondary := (IniRead(A_ScriptDir "\Settings.ini", "Settings", "toggleSecondary", 0) = "1")
    fish_trigger_confidence := IniRead(A_ScriptDir "\Settings.ini", "Confidence", "fish_trigger_confidence", 60)
    fish_caught_confidence := IniRead(A_ScriptDir "\Settings.ini", "Confidence", "fish_caught_confidence", 90)
    xpos_fish_caught := IniRead(A_ScriptDir "\Settings.ini", "Positions", "xpos_fish_caught", 0)
    ypos_fish_caught := IniRead(A_ScriptDir "\Settings.ini", "Positions", "ypos_fish_caught", 0)
    xpos_fish_trigger := IniRead(A_ScriptDir "\Settings.ini", "Positions", "xpos_fish_trigger", 0)
    ypos_fish_trigger := IniRead(A_ScriptDir "\Settings.ini", "Positions", "ypos_fish_trigger", 0)

    if FileExist(A_ScriptDir "\FishCaughtArea.txt") {
        try {
            areaData := FileRead(A_ScriptDir "\FishCaughtArea.txt")
            area := StrSplit(areaData, "|")
            fish_caught_x1 := area[1]
            fish_caught_y1 := area[2]
            fish_caught_x2 := area[3]
            fish_caught_y2 := area[4]
            ; Note: positions 5 and 6 are backups (modtime and trialtime) - they're ignored during normal load
        } catch {
            FileAppend("Error loading FishCaughtArea.txt`n", A_ScriptDir "\Debug.log")
        }
    }
    if FileExist(A_ScriptDir "\FishTriggerArea.txt") {
        try {
            areaData := FileRead(A_ScriptDir "\FishTriggerArea.txt")
            area := StrSplit(areaData, "|")
            fish_trigger_x1 := area[1]
            fish_trigger_y1 := area[2]
            fish_trigger_x2 := area[3]
            fish_trigger_y2 := area[4]
        } catch {
            FileAppend("Error loading FishTriggerArea.txt`n", A_ScriptDir "\Debug.log")
        }
    }
    if FileExist(A_ScriptDir "\BaitArea.txt") {
        try {
            areaData := FileRead(A_ScriptDir "\BaitArea.txt")
            area := StrSplit(areaData, "|")
            bait_x1 := area[1]
            bait_y1 := area[2]
            bait_x2 := area[3]
            bait_y2 := area[4]
        } catch {
            FileAppend("Error loading BaitArea.txt`n", A_ScriptDir "\Debug.log")
        }
    }
    static logged := false
    if !logged {
        FileAppend("Settings loaded: method=" current_method ", key=" current_key ", secondary_key=" current_secondary_key ", toggleSecondary=" toggleSecondary ", confidence=" fish_trigger_confidence "`n", A_ScriptDir "\Debug.log")
        logged := true
    }
    if !VerifySettingsHMAC(false) {
        WriteDebug("LoadAllSettings: settings HMAC mismatch detected")
        try {
            MyWindow.ExecuteScript("if(window.showHostToast) window.showHostToast('Settings file integrity check failed. Consider restoring defaults.', 'error');")
        } catch {

        }
    }
}

UpdateFishTriggerConfidence(confidence) {
    global fish_trigger_confidence
    fish_trigger_confidence := confidence
    IniWrite(fish_trigger_confidence, A_ScriptDir "\Settings.ini", "Confidence", "fish_trigger_confidence")
    UpdateSettingsHMAC()
} 

UpdateKey(key) {
    global current_key
    current_key := key
    IniWrite(current_key, A_ScriptDir "\Settings.ini", "Settings", "current_key")
    UpdateSettingsHMAC()
} 

UpdateSecondaryKey(key) {  
    global current_secondary_key
    current_secondary_key := key
    IniWrite(current_secondary_key, A_ScriptDir "\Settings.ini", "Settings", "current_secondary_key")
    UpdateSettingsHMAC()
} 

UpdateToggleSecondary(toggleState) {
    global toggleSecondary
    toggleSecondary := toggleState
    IniWrite(toggleSecondary ? 1 : 0, A_ScriptDir "\Settings.ini", "Settings", "toggleSecondary")
    UpdateSettingsHMAC()
}

UpdateMethod(method) {  
    global current_method
    current_method := method
    IniWrite(current_method, A_ScriptDir "\Settings.ini", "Settings", "current_method")
    UpdateSettingsHMAC()
}

GetCurrentMethod() {
    global current_method
    return current_method
}

GetCurrentKey() {
    global current_key
    return current_key
}

GetCurrentSecondaryKey() {
    global current_secondary_key
    return current_secondary_key
}

GetFishTriggerConfidence() {
    global fish_trigger_confidence
    return fish_trigger_confidence
}

WriteDebug(msg) {
    try {
        logfile := A_ScriptDir "\Debug.log"
        if FileExist(logfile) {
            size := FileGetSize(logfile)
            if (size > 1048576) {
                try {
                    FileMove(logfile, A_ScriptDir "\Debug.log.1", true)
                } catch {
                }
            }
        }
        FileAppend(A_Now " - " msg "`n", logfile)
    } catch {

    }
}

EnsureEnglishOCR() {
    try {
        availableLangs := OCR.GetAvailableLanguages()
        if !InStr(availableLangs, "en") {
            FileAppend("English OCR language not detected. Attempting to install...`n", A_ScriptDir "\Debug.log")
            try {
                RunWait('powershell.exe -Command "Add-WindowsCapability -Online -Name Language.OCR~~~en-US~0.0.1.0"'
                    , , "Hide")
                FileAppend("English OCR language pack installed successfully.`n", A_ScriptDir "\Debug.log")
            } catch as e {
                FileAppend("Error installing English OCR: " e.What "`n", A_ScriptDir "\Debug.log")
            }
        } else {
            FileAppend("English OCR language already present.`n", A_ScriptDir "\Debug.log")
        }
    } catch as e {
        FileAppend("Error checking OCR languages: " e.What "`n", A_ScriptDir "\Debug.log")
    }
}

;///////////////////////////////////////////////////////////////////////////////////////////
;@Ahk2Exe-AddResource Lib\32bit\WebView2Loader.dll, 32bit\WebView2Loader.dll
;@Ahk2Exe-AddResource Lib\64bit\WebView2Loader.dll, 64bit\WebView2Loader.dll
;///////////////////////////////////////////////////////////////////////////////////////////