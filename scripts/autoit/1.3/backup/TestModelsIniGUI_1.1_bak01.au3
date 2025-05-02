#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <FileConstants.au3>
#include <Array.au3>
#include <MsgBoxConstants.au3>
#include <File.au3>

; GUI Setup
Global $hGUI = GUICreate("Test Models.ini GUI", 600, 500)
Global $idModelCombo = GUICtrlCreateCombo("", 20, 20, 560, 25, $CBS_DROPDOWNLIST)
Global $idModelInfo = GUICtrlCreateEdit("", 20, 50, 560, 100, BitOR($ES_READONLY, $WS_VSCROLL))
Global $idInputFile = GUICtrlCreateInput("", 20, 160, 480, 25)
Global $idInputBrowse = GUICtrlCreateButton("Browse", 510, 160, 70, 25)
Global $idOutputDir = GUICtrlCreateInput(@ScriptDir & "\stems", 20, 190, 480, 25)
Global $idOutputBrowse = GUICtrlCreateButton("Browse", 510, 190, 70, 25)

; First column: SegmentSize, Overlap
Global $idSegmentSizeLabel = GUICtrlCreateLabel("Segment Size (seconds):", 20, 220, 120, 20)
Global $idSegmentSize = GUICtrlCreateCombo("15", 150, 220, 100, 20)
GUICtrlSetData($idSegmentSize, "10|15|20")
Global $idOverlapLabel = GUICtrlCreateLabel("Overlap (samples):", 20, 250, 120, 20)
Global $idOverlap = GUICtrlCreateInput("44100", 150, 250, 100, 20, $ES_NUMBER)

; Second column: Denoise, NFFT, DimF, DimT
Global $idDenoiseLabel = GUICtrlCreateLabel("Denoise:", 300, 220, 120, 20)
Global $idDenoise = GUICtrlCreateCheckbox("Enable Denoise", 430, 220, 100, 20)
GUICtrlSetState($idDenoise, $GUI_CHECKED)
Global $idNFFTLabel = GUICtrlCreateLabel("FFT Size:", 300, 250, 120, 20)
Global $idNFFT = GUICtrlCreateCombo("6144", 430, 250, 100, 20)
GUICtrlSetData($idNFFT, "4096|6144|8192")
Global $idDimFLabel = GUICtrlCreateLabel("Freq Dim:", 300, 280, 120, 20)
Global $idDimF = GUICtrlCreateInput("2048", 430, 280, 100, 20, $ES_NUMBER)
Global $idDimTLabel = GUICtrlCreateLabel("Time Dim:", 300, 310, 120, 20)
Global $idDimT = GUICtrlCreateInput("8", 430, 310, 100, 20, $ES_NUMBER)

Global $idRunButton = GUICtrlCreateButton("Run Separation", 20, 340, 560, 30)
Global $idOutputList = GUICtrlCreateEdit("", 20, 380, 560, 110, BitOR($ES_READONLY, $WS_VSCROLL))
Global $g_sIniPath = @ScriptDir & "\models.ini"
Global $g_sLogPath = @ScriptDir & "\logs\gui_log.txt"
Global $g_aModels[1][15] ; [Name, Focus, Stems, Path, Description, Comments, OutputStems, CommandLine, SegmentSize, Overlap, Denoise, NFFT, DimT, EnvPath, PythonScript]

; Create log directory
DirCreate(@ScriptDir & "\logs")

; Logging function
Func LogMessage($sLevel, $sMessage)
    Local $sTimestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $sLogLine = "[" & $sTimestamp & "] " & $sLevel & " GUI: " & $sMessage & @CRLF
    FileWrite($g_sLogPath, $sLogLine)
EndFunc

; Load models.ini
Func LoadModels()
    LogMessage("INFO", "Loading models.ini from " & $g_sIniPath)
    Local $aSections = IniReadSectionNames($g_sIniPath)
    If @error Then
        LogMessage("ERROR", "Failed to read models.ini at " & $g_sIniPath)
        MsgBox($MB_ICONERROR, "Error", "Failed to read models.ini at " & $g_sIniPath)
        Exit
    EndIf
    ReDim $g_aModels[$aSections[0] + 1][15]
    $g_aModels[0][0] = $aSections[0]
    Local $sComboData = ""
    For $i = 1 To $aSections[0]
        $g_aModels[$i][0] = $aSections[$i] ; Name
        $g_aModels[$i][1] = IniRead($g_sIniPath, $aSections[$i], "Focus", "")
        $g_aModels[$i][2] = IniRead($g_sIniPath, $aSections[$i], "Stems", "2")
        $g_aModels[$i][3] = IniRead($g_sIniPath, $aSections[$i], "Path", "")
        $g_aModels[$i][4] = IniRead($g_sIniPath, $aSections[$i], "Description", "")
        $g_aModels[$i][5] = IniRead($g_sIniPath, $aSections[$i], "Comments", "")
        $g_aModels[$i][6] = IniRead($g_sIniPath, $aSections[$i], "OutputStems", "vocals,no_vocals")
        $g_aModels[$i][7] = IniRead($g_sIniPath, $aSections[$i], "CommandLine", "")
        $g_aModels[$i][8] = IniRead($g_sIniPath, $aSections[$i], "SegmentSize", "15")
        $g_aModels[$i][9] = IniRead($g_sIniPath, $aSections[$i], "Overlap", "44100")
        $g_aModels[$i][10] = IniRead($g_sIniPath, $aSections[$i], "Denoise", "True")
        $g_aModels[$i][11] = IniRead($g_sIniPath, $aSections[$i], "NFFT", "6144")
        $g_aModels[$i][12] = IniRead($g_sIniPath, $aSections[$i], "DimT", "8")
        $g_aModels[$i][13] = IniRead($g_sIniPath, $aSections[$i], "EnvPath", "")
        $g_aModels[$i][14] = IniRead($g_sIniPath, $aSections[$i], "PythonScript", "separate.py")
        $sComboData &= $aSections[$i] & "|"
    Next
    GUICtrlSetData($idModelCombo, $sComboData)
    GUICtrlSetData($idModelCombo, $aSections[1]) ; Select first model
    LogMessage("INFO", "Loaded " & $aSections[0] & " models from models.ini")
    UpdateModelInfo()
EndFunc

; Update model info display
Func UpdateModelInfo()
    Local $sModel = GUICtrlRead($idModelCombo)
    LogMessage("INFO", "Selected model: " & $sModel)
    For $i = 1 To $g_aModels[0][0]
        If $g_aModels[$i][0] = $sModel Then
            Local $sInfo = "Name: " & $g_aModels[$i][0] & @CRLF & _
                          "Focus: " & $g_aModels[$i][1] & @CRLF & _
                          "Stems: " & $g_aModels[$i][2] & @CRLF & _
                          "Output Stems: " & $g_aModels[$i][6] & @CRLF & _
                          "Description: " & $g_aModels[$i][4] & @CRLF & _
                          "Comments: " & $g_aModels[$i][5] & @CRLF & _
                          "Default Segment Size: " & $g_aModels[$i][8] & " seconds" & @CRLF & _
                          "Default Overlap: " & $g_aModels[$i][9] & " samples" & @CRLF & _
                          "Default Denoise: " & $g_aModels[$i][10] & @CRLF & _
                          "Default FFT Size: " & $g_aModels[$i][11] & @CRLF & _
                          "Default Freq Dim: " & IniRead($g_sIniPath, $sModel, "DimF", "2048") & @CRLF & _
                          "Default Time Dim: " & $g_aModels[$i][12]
            GUICtrlSetData($idModelInfo, $sInfo)
            GUICtrlSetData($idSegmentSize, $g_aModels[$i][8])
            GUICtrlSetData($idOverlap, $g_aModels[$i][9])
            If $g_aModels[$i][10] = "True" Then
                GUICtrlSetState($idDenoise, $GUI_CHECKED)
            Else
                GUICtrlSetState($idDenoise, $GUI_UNCHECKED)
            EndIf
            GUICtrlSetData($idNFFT, $g_aModels[$i][11])
            GUICtrlSetData($idDimF, IniRead($g_sIniPath, $sModel, "DimF", "2048"))
            GUICtrlSetState($idDimF, $GUI_ENABLE)
            GUICtrlSetData($idDimT, $g_aModels[$i][12])
            GUICtrlSetState($idDimT, $GUI_ENABLE)
            LogMessage("INFO", "Updated model info for " & $sModel)
            ExitLoop
        EndIf
    Next
EndFunc

; Browse for input file
Func BrowseInput()
    Local $sFile = FileOpenDialog("Select Audio File", @ScriptDir & "\songs", "Audio Files (*.mp3;*.wav;*.flac)", 1)
    If Not @error Then
        GUICtrlSetData($idInputFile, $sFile)
        LogMessage("INFO", "Selected input file: " & $sFile)
    EndIf
EndFunc

; Browse for output directory
Func BrowseOutput()
    Local $sDir = FileSelectFolder("Select Output Directory", @ScriptDir & "\stems")
    If Not @error Then
        GUICtrlSetData($idOutputDir, $sDir)
        LogMessage("INFO", "Selected output directory: " & $sDir)
    EndIf
EndFunc

; Run separation
Func RunSeparation()
    Local $sModel = GUICtrlRead($idModelCombo)
    Local $sInput = GUICtrlRead($idInputFile)
    Local $sOutput = GUICtrlRead($idOutputDir)
    Local $sSegmentSize = GUICtrlRead($idSegmentSize)
    Local $sOverlap = GUICtrlRead($idOverlap)
    Local $sDenoise = (GUICtrlRead($idDenoise) = $GUI_CHECKED) ? "True" : "False"
    Local $sNFFT = GUICtrlRead($idNFFT)
    Local $sDimF = GUICtrlRead($idDimF)
    Local $sDimT = GUICtrlRead($idDimT)

    LogMessage("INFO", "Starting separation for model: " & $sModel & ", Input: " & $sInput & ", Output: " & $sOutput & _
               ", SegmentSize: " & $sSegmentSize & ", Overlap: " & $sOverlap & ", Denoise: " & $sDenoise & _
               ", NFFT: " & $sNFFT & ", DimF: " & $sDimF & ", DimT: " & $sDimT)

    ; Validate inputs
    If $sInput = "" Or Not FileExists($sInput) Then
        LogMessage("ERROR", "Invalid input audio file: " & $sInput)
        MsgBox($MB_ICONERROR, "Error", "Please select a valid input audio file.")
        Return
    EndIf
    If $sOutput = "" Or Not FileExists($sOutput) Then
        LogMessage("ERROR", "Invalid output directory: " & $sOutput)
        MsgBox($MB_ICONERROR, "Error", "Please select a valid output directory.")
        Return
    EndIf
    If $sSegmentSize = "" Or Not StringIsInt($sSegmentSize) Or Int($sSegmentSize) <= 0 Then
        LogMessage("ERROR", "Invalid Segment Size: " & $sSegmentSize)
        MsgBox($MB_ICONERROR, "Error", "Segment Size must be a positive integer.")
        Return
    EndIf
    If $sOverlap = "" Or Not StringIsInt($sOverlap) Or Int($sOverlap) <= 0 Then
        LogMessage("ERROR", "Invalid Overlap: " & $sOverlap)
        MsgBox($MB_ICONERROR, "Error", "Overlap must be a positive integer.")
        Return
    EndIf
    If $sNFFT = "" Or Not StringIsInt($sNFFT) Or Int($sNFFT) <= 0 Then
        LogMessage("ERROR", "Invalid FFT Size: " & $sNFFT)
        MsgBox($MB_ICONERROR, "Error", "FFT Size must be a positive integer.")
        Return
    EndIf
    If $sDimF = "" Or Not StringIsInt($sDimF) Or Int($sDimF) <= 0 Then
        LogMessage("ERROR", "Invalid Freq Dim: " & $sDimF)
        MsgBox($MB_ICONERROR, "Error", "Freq Dim must be a positive integer.")
        Return
    EndIf
    If $sDimT = "" Or Not StringIsInt($sDimT) Or Int($sDimT) <= 0 Then
        LogMessage("ERROR", "Invalid Time Dim: " & $sDimT)
        MsgBox($MB_ICONERROR, "Error", "Time Dim must be a positive integer.")
        Return
    EndIf

    ; Get CommandLine
    Local $sCmd = ""
    Local $sEnvPath = ""
    Local $sPythonScript = ""
    For $i = 1 To $g_aModels[0][0]
        If $g_aModels[$i][0] = $sModel Then
            $sCmd = $g_aModels[$i][7]
            $sEnvPath = $g_aModels[$i][13]
            $sPythonScript = $g_aModels[$i][14]
            ExitLoop
        EndIf
    Next
    If $sCmd = "" Then
        LogMessage("ERROR", "CommandLine not found for model: " & $sModel)
        MsgBox($MB_ICONERROR, "Error", "CommandLine not found for model: " & $sModel)
        Return
    EndIf
    If $sEnvPath = "" Then
        LogMessage("ERROR", "EnvPath not found for model: " & $sModel)
        MsgBox($MB_ICONERROR, "Error", "EnvPath not found for model: " & $sModel)
        Return
    EndIf
    If $sPythonScript = "" Then
        LogMessage("ERROR", "PythonScript not found for model: " & $sModel)
        MsgBox($MB_ICONERROR, "Error", "PythonScript not found for model: " & $sModel)
        Return
    EndIf

    ; Get and validate the model path
    Local $sModelPath = IniRead($g_sIniPath, $sModel, "Path", "")
    If $sModelPath = "" Then
        LogMessage("ERROR", "Model path not found for model: " & $sModel)
        MsgBox($MB_ICONERROR, "Error", "Model path not found for model: " & $sModel)
        Return
    EndIf
    Local $sResolvedModelPath = StringReplace($sModelPath, "@ScriptDir@", @ScriptDir)
    If Not FileExists($sResolvedModelPath) Then
        LogMessage("ERROR", "Model file not found: " & $sResolvedModelPath)
        MsgBox($MB_ICONERROR, "Error", "Model file not found: " & $sResolvedModelPath)
        Return
    EndIf

    ; Resolve and validate EnvPath and PythonScript
    Local $sResolvedEnvPath = StringReplace($sEnvPath, "@ScriptDir@", @ScriptDir)
    Local $sResolvedPythonScript = StringReplace($sPythonScript, "@ScriptDir@", @ScriptDir)
    Local $sFullPythonScriptPath = @ScriptDir & "\" & $sResolvedPythonScript
    If Not FileExists($sResolvedEnvPath & "\activate.bat") Then
        LogMessage("ERROR", "Virtual environment not found: " & $sResolvedEnvPath & "\activate.bat")
        MsgBox($MB_ICONERROR, "Error", "Virtual environment not found: " & $sResolvedEnvPath & "\activate.bat")
        Return
    EndIf
    If Not FileExists($sFullPythonScriptPath) Then
        LogMessage("ERROR", "Python script not found: " & $sFullPythonScriptPath)
        MsgBox($MB_ICONERROR, "Error", "Python script not found: " & $sFullPythonScriptPath)
        Return
    EndIf

    ; Substitute placeholders in the CommandLine
    $sCmd = StringReplace($sCmd, "@ScriptDir@", @ScriptDir)
    $sCmd = StringReplace($sCmd, "@SongPath@", $sInput)
    $sCmd = StringReplace($sCmd, "@OutputDir@", $sOutput)
    $sCmd = StringReplace($sCmd, "@SegmentSize@", $sSegmentSize)
    $sCmd = StringReplace($sCmd, "@Overlap@", $sOverlap)
    $sCmd = StringReplace($sCmd, "@Denoise@", $sDenoise)
    $sCmd = StringReplace($sCmd, "@NFFT@", $sNFFT)
    $sCmd = StringReplace($sCmd, "@DimF@", $sDimF)
    $sCmd = StringReplace($sCmd, "@DimT@", $sDimT)
    $sCmd = StringReplace($sCmd, "@Path@", $sResolvedModelPath)
    $sCmd = StringReplace($sCmd, "@EnvPath@", $sResolvedEnvPath)
    $sCmd = StringReplace($sCmd, "@PythonScript@", $sResolvedPythonScript)

    ; Run command with progress monitoring
    LogMessage("INFO", "Resolved command: " & $sCmd)
    GUICtrlSetData($idOutputList, "Running separation for " & $sModel & "..." & @CRLF & "Processing:   0%|          |")
    Local $sOutputText = ""
    Local $sProgress = "Processing:   0%|          |"
    Local $iPID = Run($sCmd, "", @SW_HIDE, $STDERR_MERGED)
    While ProcessExists($iPID)
        Local $sLine = StdoutRead($iPID)
        If @error Then
            ContinueLoop
        EndIf
        If $sLine <> "" Then
            $sOutputText &= $sLine
            If StringInStr($sLine, "Processing:") Then
                Local $aMatch = StringRegExp($sLine, "(Processing:\s+\d+%\|[#\s]+\|)", 1)
                If Not @error Then
                    $sProgress = $aMatch[0]
                EndIf
            EndIf
            GUICtrlSetData($idOutputList, "Running separation for " & $sModel & "..." & @CRLF & $sProgress)
        EndIf
        Sleep(100)
    WEnd
    $sOutputText &= StdoutRead($iPID)
    If @error Then
        LogMessage("ERROR", "Error reading command output for " & $sModel)
        $sOutputText &= "Error reading output." & @CRLF
    EndIf
    LogMessage("INFO", "Command output: " & $sOutputText)

    ; Check generated stems
    Local $aStems = StringSplit(IniRead($g_sIniPath, $sModel, "OutputStems", "vocals,no_vocals"), ",")
    Local $sFilename = StringRegExpReplace($sInput, "^.*\\", "")
    $sFilename = StringRegExpReplace($sFilename, "\.[^.]+$", "")
    Local $sResult = "Separation complete. Generated stems:" & @CRLF
    For $i = 1 To $aStems[0]
        Local $sStemFile = $sOutput & "\" & $sFilename & "_" & $aStems[$i] & ".wav"
        If FileExists($sStemFile) Then
            $sResult &= "- " & $sStemFile & @CRLF
            LogMessage("INFO", "Generated stem: " & $sStemFile)
        Else
            $sResult &= "- [Missing] " & $sStemFile & @CRLF
            LogMessage("ERROR", "Failed to generate stem: " & $sStemFile)
        EndIf
    Next
    $sResult &= @CRLF & "Full Command Line:" & @CRLF & $sCmd & @CRLF
    $sResult &= @CRLF & "Command Output:" & @CRLF & $sOutputText
    GUICtrlSetData($idOutputList, $sResult)
EndFunc

; Main loop
LogMessage("INFO", "Starting Test Models.ini GUI")
LoadModels()
GUISetState(@SW_SHOW)

While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            LogMessage("INFO", "Exiting GUI")
            Exit
        Case $idModelCombo
            UpdateModelInfo()
        Case $idInputBrowse
            BrowseInput()
        Case $idOutputBrowse
            BrowseOutput()
        Case $idRunButton
            RunSeparation()
    EndSwitch
WEnd