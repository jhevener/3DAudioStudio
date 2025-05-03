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

Global $g_sIniPath = @ScriptDir & "\models.INI"
Global $g_sLogPath = @ScriptDir & "\logs\gui_log.txt"
Global $g_aModels[1][15]
Global $idModelCombo, $idQualityCombo, $idInputFile, $idOutputDir, $idNFFT, $idDimF, $idDimT, $idOutputList, $idRunButton
Global $idInputBrowseButton, $idOutputBrowseButton

Func LogMessage($sLevel, $sMessage)
    Local $sLogEntry = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & " - " & $sLevel & " - " & $sMessage & @CRLF
    FileWrite($g_sLogPath, $sLogEntry)
EndFunc

Func CreateGUI()
    GUICreate("Audio Separation", 600, 400)
    GUICtrlCreateLabel("Select Model:", 10, 10, 100, 20)
    $idModelCombo = GUICtrlCreateCombo("", 110, 10, 200, 20)
    GUICtrlCreateLabel("Quality:", 10, 40, 100, 20)
    $idQualityCombo = GUICtrlCreateCombo("Balanced", 110, 40, 100, 20)
    GUICtrlSetData($idQualityCombo, "Fast|Quality")
    GUICtrlCreateLabel("Input Audio File:", 10, 70, 100, 20)
    $idInputFile = GUICtrlCreateInput("", 110, 70, 400, 20)
    $idInputBrowseButton = GUICtrlCreateButton("Browse", 520, 70, 60, 20)
    GUICtrlCreateLabel("Output Directory:", 10, 100, 100, 20)
    $idOutputDir = GUICtrlCreateInput(@ScriptDir & "\stems", 110, 100, 400, 20)
    $idOutputBrowseButton = GUICtrlCreateButton("Browse", 520, 100, 60, 20)
    GUICtrlCreateLabel("NFFT:", 10, 130, 50, 20)
    $idNFFT = GUICtrlCreateInput("6144", 60, 130, 50, 20)
    GUICtrlCreateLabel("DimF:", 120, 130, 50, 20)
    $idDimF = GUICtrlCreateInput("2048", 170, 130, 50, 20)
    GUICtrlCreateLabel("DimT:", 230, 130, 50, 20)
    $idDimT = GUICtrlCreateInput("8", 280, 130, 50, 20)
    GUICtrlSetTip($idDimT, "Actual dim_t = 2^DimT")  ; Initial tooltip
    $idOutputList = GUICtrlCreateEdit("", 10, 160, 580, 200, BitOR($ES_AUTOVSCROLL, $ES_READONLY, $WS_VSCROLL))
    $idRunButton = GUICtrlCreateButton("Run Separation", 250, 370, 100, 20)
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
        $g_aModels[$i][3] = IniRead($g_sIniPath, $aSections[$i], "SegmentSize", "15")
        $g_aModels[$i][4] = IniRead($g_sIniPath, $aSections[$i], "Overlap", "44100")
        $g_aModels[$i][5] = IniRead($g_sIniPath, $aSections[$i], "Denoise", "True")
        $g_aModels[$i][6] = IniRead($g_sIniPath, $aSections[$i], "NFFT", "6144")
        $g_aModels[$i][7] = IniRead($g_sIniPath, $aSections[$i], "DimF", "2048")
        $g_aModels[$i][8] = IniRead($g_sIniPath, $aSections[$i], "DimT", "8")
        $g_aModels[$i][9] = IniRead($g_sIniPath, $aSections[$i], "OutputStems", "vocals,no_vocals")
        $g_aModels[$i][10] = IniRead($g_sIniPath, $aSections[$i], "EnvPath", "")
        $g_aModels[$i][11] = IniRead($g_sIniPath, $aSections[$i], "PythonScript", "")
        $g_aModels[$i][12] = IniRead($g_sIniPath, $aSections[$i], "OutputFormat", "wav")
        $sModels &= $aSections[$i] & "|"
    Next

    $sModels = StringTrimRight($sModels, 1)
    GUICtrlSetData($idModelCombo, $sModels, $aSections[1])
    UpdateModelSettings($aSections[1])
EndFunc

Func UpdateModelSettings($sModel)
    For $i = 1 To $g_aModels[0][0]
        If $g_aModels[$i][0] = $sModel Then
            GUICtrlSetData($idNFFT, $g_aModels[$i][6])
            GUICtrlSetData($idDimF, $g_aModels[$i][7])
            GUICtrlSetData($idDimT, $g_aModels[$i][8])
            Local $sStems = $g_aModels[$i][9]
            ; Compute self.dim_t = 2^DimT
            Local $iDimT = Number($g_aModels[$i][8])
            Local $iSelfDimT = 2 ^ $iDimT
            GUICtrlSetTip($idDimT, "Actual dim_t = " & $iSelfDimT)
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
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc

Func RunSeparation()
    Local $sModel = GUICtrlRead($idModelCombo)
    Local $sQuality = GUICtrlRead($idQualityCombo)
    Local $sInput = GUICtrlRead($idInputFile)
    Local $sOutput = GUICtrlRead($idOutputDir)
    Local $sNFFT = GUICtrlRead($idNFFT)
    Local $sDimF = GUICtrlRead($idDimF)
    Local $sDimT = GUICtrlRead($idDimT)

    Local $sSegmentSize, $sOverlap, $sDenoise
    Switch $sQuality
        Case "Fast"
            $sSegmentSize = 10
            $sOverlap = 22050
            $sDenoise = "False"
        Case "Balanced"
            $sSegmentSize = 15
            $sOverlap = 44100
            $sDenoise = "True"
        Case "Quality"
            $sSegmentSize = 20
            $sOverlap = 88200
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
            $sEnvPath = $g_aModels[$i][10]
            $sPythonScript = $g_aModels[$i][11]
            $sOutputFormat = $g_aModels[$i][12]
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
    Local $iPID = Run($sCmd, "", @SW_HIDE, $STDERR_MERGED)

    Local $sOutput = ""
    Local $sLastProgress = "Processing:   0%|          |"
    While ProcessExists($iPID)
        Local $sLine = StdoutRead($iPID)
        If $sLine <> "" Then
            $sOutput &= $sLine
            Local $aMatch = StringRegExp($sLine, "(Processing:\s+\d+%\|[#\s]+\|)", 1)
            If Not @error Then
                Local $sCurrentText = GUICtrlRead($idOutputList)
                Local $sNewText = StringRegExpReplace($sCurrentText, "(Processing:\s+\d+%\|[#\s]+\|)", $aMatch[0])
                GUICtrlSetData($idOutputList, $sNewText)
                $sLastProgress = $aMatch[0]
            EndIf
        EndIf
        Sleep(100)
    WEnd
    $sOutput &= StdoutRead($iPID)
    LogMessage("INFO", "Separation output: " & $sOutput)

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
        Case $idInputBrowseButton
            Local $sFile = FileOpenDialog("Select File", @ScriptDir, "Audio files (*.flac;*.mp3;*.wav)")
            If Not @error Then GUICtrlSetData($idInputFile, $sFile)
        Case $idOutputBrowseButton
            Local $sDir = FileSelectFolder("Select Output Directory", @ScriptDir)
            If Not @error Then GUICtrlSetData($idOutputDir, $sDir)
    EndSwitch
    Sleep(10)
WEnd