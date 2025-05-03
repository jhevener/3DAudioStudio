#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <EditConstants.au3>
#include <StringConstants.au3>
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>
#include <String.au3>
#include <Array.au3>
#include <File.au3>
#include <ComboConstants.au3>
#include <ProgressConstants.au3>
#include <StaticConstants.au3>

Global $g_sIniPath = @ScriptDir & "\models.INI"
Global $g_sUserSettingsPath = @ScriptDir & "\usersettings.ini"
Global $g_sLogPath = @ScriptDir & "\logs\gui_log.txt"
Global $g_aModels[1][15]
Global $idModelCombo, $idQualityCombo, $idInputFile, $idOutputDir, $idOutputList, $idRunButton
Global $idInputBrowseButton, $idOutputBrowseButton
Global $idComboChunks, $idComboMargin, $idComboNFFT, $idComboDimF, $idComboDimT
Global $idBtnSaveSettings, $idBtnLoadSettings
Global $idProgressLabel, $idProgressBar

Func LogMessage($sLevel, $sMessage)
    Local $sLogEntry = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & " - " & $sLevel & " - " & $sMessage & @CRLF
    FileWrite($g_sLogPath, $sLogEntry)
EndFunc

Func CreateGUI()
    GUICreate("Audio Separation", 900, 600)
    Local $iFontSize = 13
    GUICtrlCreateLabel("Select Model:", 15, 15, 150, 30)
    GUICtrlSetFont(-1, $iFontSize)
    $idModelCombo = GUICtrlCreateCombo("", 165, 15, 300, 30, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlCreateLabel("Quality:", 15, 60, 150, 30)
    GUICtrlSetFont(-1, $iFontSize)
    $idQualityCombo = GUICtrlCreateCombo("Normal", 165, 60, 150, 30, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idQualityCombo, "Fast|Normal|High")
    GUICtrlCreateLabel("Input Audio File:", 15, 105, 150, 30)
    GUICtrlSetFont(-1, $iFontSize)
    $idInputFile = GUICtrlCreateInput("", 165, 105, 600, 30, $ES_READONLY)
    GUICtrlSetFont(-1, $iFontSize)
    $idInputBrowseButton = GUICtrlCreateButton("Browse", 780, 105, 90, 30)
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlCreateLabel("Output Directory:", 15, 150, 150, 30)
    GUICtrlSetFont(-1, $iFontSize)
    $idOutputDir = GUICtrlCreateInput(@ScriptDir & "\stems", 165, 150, 600, 30, $ES_READONLY)
    GUICtrlSetFont(-1, $iFontSize)
    $idOutputBrowseButton = GUICtrlCreateButton("Browse", 780, 150, 90, 30)
    GUICtrlSetFont(-1, $iFontSize)
    ; Parameters row: Chunks, Margin, NFFT, DimF, DimT (evenly distributed, reduced spacing)
    GUICtrlCreateLabel("Chunks:", 15, 195, 75, 30)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboChunks = GUICtrlCreateCombo("", 102, 195, 90, 30, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboChunks, "100|250|500|1000|2000", "500")
    GUICtrlCreateLabel("Margin:", 189, 195, 75, 30)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboMargin = GUICtrlCreateCombo("", 276, 195, 75, 30, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboMargin, "76800|192000|384000|768000|1536000", "384000")
    GUICtrlCreateLabel("NFFT:", 363, 195, 75, 30)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboNFFT = GUICtrlCreateCombo("", 450, 195, 75, 30, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboNFFT, "2048|4096|6144|8192|16384", "6144")
    GUICtrlCreateLabel("DimF:", 537, 195, 75, 30)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboDimF = GUICtrlCreateCombo("", 624, 195, 75, 30, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboDimF, "1024|2048|3072|4096", "2048")
    GUICtrlCreateLabel("DimT:", 711, 195, 75, 30)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboDimT = GUICtrlCreateCombo("", 798, 195, 45, 30, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboDimT, "4|6|8|10|12", "8")
    GUICtrlSetTip($idComboDimT, "Actual dim_t = 2^DimT")
    $idOutputList = GUICtrlCreateEdit("", 15, 240, 870, 260, BitOR($ES_AUTOVSCROLL, $ES_READONLY, $WS_VSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    $idBtnSaveSettings = GUICtrlCreateButton("Save Settings", 225, 510, 150, 30)
    GUICtrlSetFont(-1, $iFontSize)
    $idRunButton = GUICtrlCreateButton("Run Separation", 375, 510, 150, 30)
    GUICtrlSetFont(-1, $iFontSize)
    $idBtnLoadSettings = GUICtrlCreateButton("Load Settings", 525, 510, 150, 30)
    GUICtrlSetFont(-1, $iFontSize)
    $idProgressLabel = GUICtrlCreateLabel("0%", 15, 555, 50, 30, $SS_CENTER)
    GUICtrlSetFont(-1, $iFontSize)
    $idProgressBar = GUICtrlCreateProgress(65, 555, 820, 30)
    GUICtrlSetFont(-1, $iFontSize)
    GUISetState(@SW_SHOW)

    LoadModels()
    GUIRegisterMsg($WM_COMMAND, "WM_COMMAND")
EndFunc

Func LoadModels()
    Local $aSections = IniReadSectionNames($g_sIniPath)
    If @error Then
        GUICtrlSetData($idModelCombo, "No models found")
        Return
    EndIf

    Local $sModels = ""
    ReDim $g_aModels[$aSections[0] + 1][15]
    $g_aModels[0][0] = $aSections[0]

    For $i = 1 To $aSections[0]
        $g_aModels[$i][0] = $aSections[$i]
        $g_aModels[$i][1] = IniRead($g_sIniPath, $aSections[$i], "Path", "")
        $g_aModels[$i][2] = IniRead($g_sIniPath, $aSections[$i], "CommandLine", "")
        $g_aModels[$i][3] = IniRead($g_sIniPath, $aSections[$i], "FastSettings", "100,76800,2048,1024,4")
        $g_aModels[$i][4] = IniRead($g_sIniPath, $aSections[$i], "NormalSettings", "500,384000,6144,2048,8")
        $g_aModels[$i][5] = IniRead($g_sIniPath, $aSections[$i], "HighSettings", "1000,768000,16384,4096,12")
        $g_aModels[$i][6] = IniRead($g_sIniPath, $aSections[$i], "Denoise", "True")
        $g_aModels[$i][7] = IniRead($g_sIniPath, $aSections[$i], "OutputStems", "vocals,no_vocals")
        $g_aModels[$i][8] = IniRead($g_sIniPath, $aSections[$i], "EnvPath", "")
        $g_aModels[$i][9] = IniRead($g_sIniPath, $aSections[$i], "PythonScript", "")
        $g_aModels[$i][10] = IniRead($g_sIniPath, $aSections[$i], "OutputFormat", "wav")
        $sModels &= $aSections[$i] & "|"
    Next

    $sModels = StringTrimRight($sModels, 1)
    GUICtrlSetData($idModelCombo, $sModels, $aSections[1])
    UpdateModelSettings($aSections[1])
EndFunc

Func UpdateModelSettings($sModel)
    For $i = 1 To $g_aModels[0][0]
        If $g_aModels[$i][0] = $sModel Then
            Local $sQuality = GUICtrlRead($idQualityCombo)
            Local $sSettingsKey = $sQuality & "Settings"
            Local $sSettings = IniRead($g_sIniPath, $sModel, $sSettingsKey, "")
            Local $aSettings = StringSplit($sSettings, ",", $STR_NOCOUNT)
            If UBound($aSettings) < 5 Then
                $sSettings = $g_aModels[$i][4] ; Default to NormalSettings
                $aSettings = StringSplit($sSettings, ",", $STR_NOCOUNT)
            EndIf
            GUICtrlSetData($idComboChunks, "100|250|500|1000|2000", $aSettings[0])
            GUICtrlSetData($idComboMargin, "76800|192000|384000|768000|1536000", $aSettings[1])
            GUICtrlSetData($idComboNFFT, "2048|4096|6144|8192|16384", $aSettings[2])
            GUICtrlSetData($idComboDimF, "1024|2048|3072|4096", $aSettings[3])
            GUICtrlSetData($idComboDimT, "4|6|8|10|12", $aSettings[4])
            Local $iDimT = Number($aSettings[4])
            Local $iSelfDimT = 2 ^ $iDimT
            GUICtrlSetTip($idComboDimT, "Actual dim_t = " & $iSelfDimT)
            Local $sStems = $g_aModels[$i][7]
            GUICtrlSetData($idOutputList, "Expected stems for " & $sModel & ": " & $sStems & @CRLF)
            ExitLoop
        EndIf
    Next
EndFunc

Func WM_COMMAND($hWnd, $iMsg, $wParam, $lParam)
    Local $iControlID = BitAND($wParam, 0xFFFF)
    Local $iCode = BitShift($wParam, 16)

    If $iControlID = $idModelCombo And $iCode = $CBN_SELCHANGE Then
        Local $sModel = GUICtrlRead($idModelCombo)
        UpdateModelSettings($sModel)
    ElseIf $iControlID = $idQualityCombo And $iCode = $CBN_SELCHANGE Then
        Local $sModel = GUICtrlRead($idModelCombo)
        UpdateModelSettings($sModel)
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

Func SaveSettings()
    Local $sModel = GUICtrlRead($idModelCombo)
    If $sModel = "" Or $sModel = "No models found" Then
        MsgBox($MB_ICONERROR, "Error", "Please select a model.")
        Return
    EndIf

    Local $sQuality = GUICtrlRead($idQualityCombo)
    Local $sSegmentSize = GUICtrlRead($idComboChunks)
    Local $sOverlap = GUICtrlRead($idComboMargin)
    Local $sNFFT = GUICtrlRead($idComboNFFT)
    Local $sDimF = GUICtrlRead($idComboDimF)
    Local $sDimT = GUICtrlRead($idComboDimT)

    Local $sSettings = $sSegmentSize & "," & $sOverlap & "," & $sNFFT & "," & $sDimF & "," & $sDimT
    Local $sChoice = MsgBox($MB_YESNOCANCEL + $MB_ICONQUESTION, "Save Settings", "Save to default '" & $sQuality & "' settings in models.ini? (Yes)\nOr save as a custom setting in usersettings.ini? (No)")

    If $sChoice = $IDYES Then
        Local $sSettingsKey = $sQuality & "Settings"
        IniWrite($g_sIniPath, $sModel, $sSettingsKey, $sSettings)
        LogMessage("INFO", "Saved default settings for " & $sModel & " (" & $sQuality & "): " & $sSettings)
        MsgBox($MB_ICONINFORMATION, "Success", "Default settings saved to models.ini.")
    ElseIf $sChoice = $IDNO Then
        Local $sCustomName = InputBox("Custom Settings", "Enter a name for these settings:", "MySettings")
        If @error Then Return
        Local $sSection = $sModel & "_" & $sCustomName
        IniWrite($g_sUserSettingsPath, $sSection, "Settings", $sSettings)
        LogMessage("INFO", "Saved custom settings for " & $sSection & ": " & $sSettings)
        MsgBox($MB_ICONINFORMATION, "Success", "Custom settings saved to usersettings.ini as " & $sCustomName & ".")
    EndIf
EndFunc

Func LoadSettings()
    Local $sModel = GUICtrlRead($idModelCombo)
    If $sModel = "" Or $sModel = "No models found" Then
        MsgBox($MB_ICONERROR, "Error", "Please select a model.")
        Return
    EndIf

    Local $aCustomSections = IniReadSectionNames($g_sUserSettingsPath)
    If @error Then
        MsgBox($MB_ICONINFORMATION, "Info", "No custom settings found in usersettings.ini.")
        Return
    EndIf

    Local $sCustomList = ""
    For $i = 1 To $aCustomSections[0]
        If StringInStr($aCustomSections[$i], $sModel & "_") Then
            $sCustomList &= StringReplace($aCustomSections[$i], $sModel & "_", "") & "|"
        EndIf
    Next
    If $sCustomList = "" Then
        MsgBox($MB_ICONINFORMATION, "Info", "No custom settings found for this model.")
        Return
    EndIf

    $sCustomList = StringTrimRight($sCustomList, 1)
    Local $sCustomName = InputBox("Load Settings", "Select a custom setting to load:", "", "", -1, -1, 0, 0, 0, $sCustomList)
    If @error Then Return

    Local $sSection = $sModel & "_" & $sCustomName
    Local $sSettings = IniRead($g_sUserSettingsPath, $sSection, "Settings", "")
    If $sSettings = "" Then
        MsgBox($MB_ICONERROR, "Error", "Failed to load settings for " & $sCustomName & ".")
        Return
    EndIf

    Local $aSettings = StringSplit($sSettings, ",", $STR_NOCOUNT)
    GUICtrlSetData($idComboChunks, "100|250|500|1000|2000", $aSettings[0])
    GUICtrlSetData($idComboMargin, "76800|192000|384000|768000|1536000", $aSettings[1])
    GUICtrlSetData($idComboNFFT, "2048|4096|6144|8192|16384", $aSettings[2])
    GUICtrlSetData($idComboDimF, "1024|2048|3072|4096", $aSettings[3])
    GUICtrlSetData($idComboDimT, "4|6|8|10|12", $aSettings[4])
    LogMessage("INFO", "Loaded custom settings for " & $sSection & ": " & $sSettings)
    MsgBox($MB_ICONINFORMATION, "Success", "Loaded custom settings: " & $sCustomName & ".")
EndFunc

Func RunSeparation()
    Local $sModel = GUICtrlRead($idModelCombo)
    Local $sQuality = GUICtrlRead($idQualityCombo)
    Local $sInput = GUICtrlRead($idInputFile)
    Local $sOutput = GUICtrlRead($idOutputDir)
    Local $sSegmentSize = GUICtrlRead($idComboChunks)
    Local $sOverlap = GUICtrlRead($idComboMargin)
    Local $sNFFT = GUICtrlRead($idComboNFFT)
    Local $sDimF = GUICtrlRead($idComboDimF)
    Local $sDimT = GUICtrlRead($idComboDimT)

    Local $sDenoise
    Switch $sQuality
        Case "Fast"
            If $sSegmentSize = "" Then $sSegmentSize = 100
            If $sOverlap = "" Then $sOverlap = 76800
            If $sNFFT = "" Then $sNFFT = 2048
            If $sDimF = "" Then $sDimF = 1024
            If $sDimT = "" Then $sDimT = 4
            $sDenoise = "False"
        Case "Normal"
            If $sSegmentSize = "" Then $sSegmentSize = 500
            If $sOverlap = "" Then $sOverlap = 384000
            If $sNFFT = "" Then $sNFFT = 6144
            If $sDimF = "" Then $sDimF = 2048
            If $sDimT = "" Then $sDimT = 8
            $sDenoise = "True"
        Case "High"
            If $sSegmentSize = "" Then $sSegmentSize = 1000
            If $sOverlap = "" Then $sOverlap = 768000
            If $sNFFT = "" Then $sNFFT = 16384
            If $sDimF = "" Then $sDimF = 4096
            If $sDimT = "" Then $sDimT = 12
            $sDenoise = "True"
    EndSwitch

    LogMessage("INFO", "Starting separation for model: " & $sModel & ", Quality: " & $sQuality & ", Input: " & $sInput & _
               ", Output: " & $sOutput & ", SegmentSize: " & $sSegmentSize & ", Overlap: " & $sOverlap & _
               ", Denoise: " & $sDenoise & ", NFFT: " & $sNFFT & ", DimF: " & $sDimF & ", DimT: " & $sDimT)

    If $sModel = "" Or $sModel = "No models found" Then
        LogMessage("ERROR", "No model selected")
        MsgBox($MB_ICONERROR, "Error", "Please select a model.")
        Return
    EndIf
    If $sInput = "" Or Not FileExists($sInput) Then
        LogMessage("ERROR", "Invalid input audio file: " & $sInput)
        MsgBox($MB_ICONERROR, "Error", "Please select a valid input audio file.")
        Return
    EndIf
    If $sOutput = "" Then
        LogMessage("ERROR", "Invalid output directory: " & $sOutput)
        MsgBox($MB_ICONERROR, "Error", "Please select a valid output directory.")
        Return
    EndIf
    If Not StringIsInt($sSegmentSize) Or $sSegmentSize <= 0 Then
        LogMessage("ERROR", "Invalid SegmentSize: " & $sSegmentSize)
        MsgBox($MB_ICONERROR, "Error", "SegmentSize must be a positive integer.")
        Return
    EndIf
    If Not StringIsInt($sOverlap) Or $sOverlap <= 0 Then
        LogMessage("ERROR", "Invalid Overlap: " & $sOverlap)
        MsgBox($MB_ICONERROR, "Error", "Overlap must be a positive integer.")
        Return
    EndIf

    Local $sCmd = ""
    Local $sEnvPath = ""
    Local $sPythonScript = ""
    Local $sOutputFormat = "wav"
    For $i = 1 To $g_aModels[0][0]
        If $g_aModels[$i][0] = $sModel Then
            $sCmd = $g_aModels[$i][2]
            $sEnvPath = $g_aModels[$i][8]
            $sPythonScript = $g_aModels[$i][9]
            $sOutputFormat = $g_aModels[$i][10]
            ExitLoop
        EndIf
    Next
    If $sCmd = "" Then
        LogMessage("ERROR", "CommandLine not found for model: " & $sModel)
        MsgBox($MB_ICONERROR, "Error", "CommandLine not found for model: " & $sModel)
        Return
    EndIf

    Local $sModelPath = IniRead($g_sIniPath, $sModel, "Path", "")
    Local $sResolvedModelPath = StringReplace($sModelPath, "@ScriptDir@", @ScriptDir)
    If Not FileExists($sResolvedModelPath) Then
        LogMessage("ERROR", "Model file not found: " & $sResolvedModelPath)
        MsgBox($MB_ICONERROR, "Error", "Model file not found: " & $sResolvedModelPath)
        Return
    EndIf

    Local $sResolvedEnvPath = StringReplace($sEnvPath, "@ScriptDir@", @ScriptDir)
    Local $sResolvedPythonScript = StringReplace($sPythonScript, "@ScriptDir@", @ScriptDir)
    Local $sFullPythonScriptPath = @ScriptDir & "\" & $sResolvedPythonScript
    If Not FileExists($sFullPythonScriptPath) Then
        LogMessage("ERROR", "Python script not found: " & $sFullPythonScriptPath)
        MsgBox($MB_ICONERROR, "Error", "Python script not found: " & $sFullPythonScriptPath)
        Return
    EndIf

    If Not FileExists($sOutput) Then
        DirCreate($sOutput)
        LogMessage("INFO", "Created output directory: " & $sOutput)
    EndIf

    LogMessage("DEBUG", "Original command: " & $sCmd)
    $sCmd = StringReplace($sCmd, "@ScriptDir@", @ScriptDir)
    $sCmd = StringReplace($sCmd, "@SongPath@", $sInput)
    $sCmd = StringReplace($sCmd, "@OutputDir@", $sOutput)
    $sCmd = StringReplace($sCmd, "@SegmentSize@", $sSegmentSize)
    $sCmd = StringReplace($sCmd, "@Overlap@", $sOverlap)
    $sCmd = StringReplace($sCmd, "@NFFT@", $sNFFT)
    $sCmd = StringReplace($sCmd, "@DimF@", $sDimF)
    $sCmd = StringReplace($sCmd, "@DimT@", $sDimT)
    $sCmd = StringReplace($sCmd, "@Path@", $sResolvedModelPath)
    $sCmd = StringReplace($sCmd, "@EnvPath@", $sResolvedEnvPath)
    $sCmd = StringReplace($sCmd, "@PythonScript@", $sResolvedPythonScript)
    $sCmd = StringReplace($sCmd, "--format @OutputFormat@", "")

    If $sDenoise = "False" Then
        $sCmd = StringReplace($sCmd, "-d", "")
    EndIf

    LogMessage("INFO", "Resolved command: " & $sCmd)
    GUICtrlSetData($idOutputList, "Running separation for " & $sModel & " (" & $sQuality & ")..." & @CRLF & "Processing:   0%|          |")
    GUICtrlSetData($idProgressLabel, "0%")
    GUICtrlSetData($idProgressBar, 0)
    Local $iPID = Run($sCmd, "", @SW_HIDE, $STDERR_MERGED)

    Local $sOutput = ""
    Local $iLastProgress = 0
    While ProcessExists($iPID)
        Local $sLine = StdoutRead($iPID)
        If $sLine <> "" Then
            $sOutput &= $sLine
            Local $aMatch = StringRegExp($sLine, "Processing:\s+(\d+)%\|[#\s]+\|", 1)
            If Not @error Then
                Local $iProgress = Number($aMatch[0])
                GUICtrlSetData($idProgressLabel, $iProgress & "%")
                GUICtrlSetData($idProgressBar, $iProgress)
                Local $sProgressText = "Processing: " & StringFormat("%3d%%|%-10s|", $iProgress, StringLeft("##########", Ceiling($iProgress / 10)))
                Local $sCurrentText = GUICtrlRead($idOutputList)
                Local $sNewText = StringRegExpReplace($sCurrentText, "Processing:\s+\d+%\|[#\s]+\|", $sProgressText)
                GUICtrlSetData($idOutputList, $sNewText)
                $iLastProgress = $iProgress
            EndIf
        EndIf
        Sleep(100)
    WEnd
    $sOutput &= StdoutRead($iPID)
    LogMessage("INFO", "Separation output: " & $sOutput)

    GUICtrlSetData($idProgressLabel, "100%")
    GUICtrlSetData($idProgressBar, 100)

    If StringInStr($sOutput, "Traceback") Or StringInStr($sOutput, "ModuleNotFoundError") Then
        LogMessage("ERROR", "Python error occurred: " & $sOutput)
        GUICtrlSetData($idOutputList, "Error: Python script failed. Check logs for details.")
        Return
    EndIf

    Local $sStems = IniRead($g_sIniPath, $sModel, "OutputStems", "vocals,no_vocals")
    Local $aStems = StringSplit($sStems, ",")
    Local $sFilename = StringRegExpReplace($sInput, "^.*\\", "")
    $sFilename = StringRegExpReplace($sFilename, "\.[^.]+$", "")
    Local $sResult = "Separation complete. Generated stems:" & @CRLF
    If StringRight($sOutput, 1) <> "\" Then $sOutput &= "\"
    For $i = 1 To $aStems[0]
        Local $sStemFile = $sOutput & $sFilename & "_" & $aStems[$i] & "." & $sOutputFormat
        If FileExists($sStemFile) Then
            $sResult &= "- " & $sStemFile & @CRLF
            LogMessage("INFO", "Generated stem: " & $sStemFile)
        Else
            $sResult &= "- [Missing] " & $sStemFile & @CRLF
            LogMessage("ERROR", "Failed to generate stem: " & $sStemFile)
        EndIf
    Next

    ; Task 1: Save successful values to models.ini if separation was successful
    If Not StringInStr($sOutput, "Traceback") And Not StringInStr($sOutput, "ModuleNotFoundError") Then
        Local $sSettings = $sSegmentSize & "," & $sOverlap & "," & $sNFFT & "," & $sDimF & "," & $sDimT
        Local $sSettingsKey = $sQuality & "Settings"
        IniWrite($g_sIniPath, $sModel, $sSettingsKey, $sSettings)
        LogMessage("INFO", "Saved successful values to models.ini for model: " & $sModel & " (" & $sQuality & "): " & $sSettings)
        $sResult &= "Saved successful values to models.ini." & @CRLF
    Else
        $sResult &= "Separation failed; values not saved." & @CRLF
    EndIf

    GUICtrlSetData($idOutputList, $sResult)
EndFunc

CreateGUI()
While 1
    Local $msg = GUIGetMsg()
    Switch $msg
        Case $GUI_EVENT_CLOSE
            Exit
        Case $idRunButton
            RunSeparation()
        Case $idBtnSaveSettings
            SaveSettings()
        Case $idBtnLoadSettings
            LoadSettings()
        Case $idInputBrowseButton
            Local $sFile = FileOpenDialog("Select File", @ScriptDir, "Audio files (*.flac;*.mp3;*.wav)")
            If Not @error Then GUICtrlSetData($idInputFile, $sFile)
        Case $idOutputBrowseButton
            Local $sDir = FileSelectFolder("Select Output Directory", @ScriptDir)
            If Not @error Then GUICtrlSetData($idOutputDir, $sDir)
    EndSwitch
    Sleep(10)
WEnd