#include <File.au3>
#include <Date.au3>

; Get the parent directory of a given path
Func _GetParentDir($sPath)
    Local $aPath = _PathSplit($sPath, "", "", "", "")
    Local $sDir = $aPath[2]
    Local $iLastSlash = StringInStr($sDir, "\", 0, -2)
    If $iLastSlash > 0 Then
        $sDir = StringLeft($sDir, $iLastSlash)
    Else
        $sDir = "\"
    EndIf
    Return $aPath[1] & $sDir
EndFunc

; Log messages to console
Func _Log($sMessage)
    Local $sPrefix = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $sLogLine = "[" & $sPrefix & "] INFO: " & $sMessage
    ConsoleWrite($sLogLine & @CRLF)
EndFunc

; Main script
_Log("Starting TestPaths.au3")

; Compute the parent directory (one level up from the script's folder)
Global $sParentDir = _GetParentDir(@ScriptDir)
_Log("Parent Directory: " & $sParentDir)

; Define paths to shared resources
Global $sModelsIni = $sParentDir & "\models.ini"
Global $sModelsDb = $sParentDir & "\models.db"
Global $sSettingsIni = $sParentDir & "\settings.ini"
Global $sUserIni = $sParentDir & "\user.ini"
Global $sSongsDir = $sParentDir & "\songs"
Global $sStemsDir = $sParentDir & "\stems"
Global $sLogsDir = $sParentDir & "\logs"
Global $sBassDll = $sParentDir & "\bass.dll"
Global $sFFmpegExe = $sParentDir & "\installs\uvr\ffmpeg\bin\ffmpeg.exe"

; Log the resolved paths
_Log("models.ini: " & $sModelsIni)
_Log("models.db: " & $sModelsDb)
_Log("settings.ini: " & $sSettingsIni)
_Log("user.ini: " & $sUserIni)
_Log("Songs Directory: " & $sSongsDir)
_Log("Stems Directory: " & $sStemsDir)
_Log("Logs Directory: " & $sLogsDir)
_Log("bass.dll: " & $sBassDll)
_Log("FFmpeg: " & $sFFmpegExe)

; Check if resources exist
_Log("Checking if resources exist...")
_Log("models.ini exists: " & (FileExists($sModelsIni) ? "Yes" : "No"))
_Log("models.db exists: " & (FileExists($sModelsDb) ? "Yes" : "No"))
_Log("settings.ini exists: " & (FileExists($sSettingsIni) ? "Yes" : "No"))
_Log("user.ini exists: " & (FileExists($sUserIni) ? "Yes" : "No"))
_Log("Songs Directory exists: " & (FileExists($sSongsDir) ? "Yes" : "No"))
_Log("Stems Directory exists: " & (FileExists($sStemsDir) ? "Yes" : "No"))
_Log("Logs Directory exists: " & (FileExists($sLogsDir) ? "Yes" : "No"))
_Log("bass.dll exists: " & (FileExists($sBassDll) ? "Yes" : "No"))
_Log("FFmpeg exists: " & (FileExists($sFFmpegExe) ? "Yes" : "No"))

_Log("TestPaths.au3 completed")