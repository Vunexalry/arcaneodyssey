#Requires AutoHotkey v2.0
#include Lib\OCR.ahk

if !A_IsAdmin {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
        ExitApp()
    } catch {
        MsgBox("Administrator rights required.")
        ExitApp()
    }
}

; Check available OCR languages
availableLangs := OCR.GetAvailableLanguages()

; Check if English is available
if InStr(availableLangs, "en") {
    ; Try to load English OCR
    OCR.LoadLanguage("en")
    MsgBox("English OCR language pack is ready!", "Success")
} else {
    ; Ask for permission to download
    result := MsgBox("English OCR language pack is not installed.`n`nWould you like to download and install it automatically?`n`nThis will require administrator privileges.", "OCR Language Pack Missing", "YesNo")
    
    if (result = "Yes") {
        ; Run PowerShell to download English language pack
        RunWait(A_ComSpec ' /c powershell -Command "Add-WindowsCapability -Online -Name Language.Basic~~~en-US~0.0.1.0 | Out-Null; Add-WindowsCapability -Online -Name Language.OCR~~~en-US~0.0.1.0"', , "Hide")
        
        ; Wait a moment and check againh
        Sleep(2000)
        
        ; Refresh available languages
        availableLangs := OCR.GetAvailableLanguages()
        
        if InStr(availableLangs, "en") {
            OCR.LoadLanguage("en")
            MsgBox("English OCR language pack installed successfully!", "Success")
        } else {
            MsgBox("Installation started. Please restart your computer and run this script again.", "Installation In Progress")
        }
    }
}