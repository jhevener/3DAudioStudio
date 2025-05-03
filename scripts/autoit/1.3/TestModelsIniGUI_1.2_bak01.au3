#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <FileConstants.au3>
#include <Array.au3>
#include <MsgBoxConstants.au3>
#include <File.au3>

; GUI Setup
Global $hGUI = GUICreate("Test Models.ini GUI", 600, 400)
Global $idModelCombo = GUICtrlCreateCombo("", 20, 20, 560, 25, $CBS_DROPDOWNLIST)
Global $idModelInfo = GUICtrlCreateEdit("", 20, 50, 560, 100, BitOR($ES_READONLY, $WS_VSCROLL))
Global $idInputFile = GUICtrlCreateInput("", 20, 160, 480, 25)
Global $idInputBrowse = GUICtrlCreateButton("Browse", 510, 160, 70, 25)
Global $idOutputDir = GUICtrlCreateInput(@ScriptDir & "\stems", 20, 190, 480, 25)
Global $idOutputBrowse = GUICtrlCreateButton("Browse", 510, 190, 70, 25)
Global $idRunButton = GUICtrlCreateButton("Run Separation", 20, 220, 560, 30)
Global $idOutputList = GUICtrlCreateEdit("", 20, 260, 560, 130, BitOR($ES_READONLY, $WS_VSCROLL))
Global $g_sIniPath = @ScriptDir & "\models.ini"
Global $g_sLogPath = @ScriptDir & "\logs\gui_log.txt"
Global $g_aModels[1][8] ; [Name, Focus, Stems, Path, Description, Comments, OutputStems, CommandLine]

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
    ReDim $g_aModels[$aSections[0] + 1][8]
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
                          "Comments: " & $g_aModels[$i][5]
            GUICtrlSetData($idModelInfo, $sInfo)
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

    LogMessage("INFO", "Starting separation for model: " & $sModel & ", Input: " & $sInput & ", Output: " & $sOutput)

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

    ; Get CommandLine
    Local $sCmd = ""
    For $i = 1 To $g_aModels[0][0]
        If $g_aModels[$i][0] = $sModel Then
            $sCmd = $g_aModels[$i][7]
            ExitLoop
        EndIf
    Next
    If $sCmd = "" Then
        LogMessage("ERROR", "CommandLine not found for model: " & $sModel)
        MsgBox($MB_ICONERROR, "Error", "CommandLine not found for model: " & $sModel)
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

    ; Get and validate the config path
    Local $sConfigPath = IniRead($g_sIniPath, $sModel, "Config", "")
    If $sConfigPath = "" Then
        LogMessage("ERROR", "Config path not found for model: " & $sModel)
        MsgBox($MB_ICONERROR, "Error", "Config path not found for model: " & $sModel)
        Return
    EndIf
    Local $sResolvedConfigPath = StringReplace($sConfigPath, "@ScriptDir@", @ScriptDir)
    If Not FileExists($sResolvedConfigPath) Then
        LogMessage("ERROR", "Config file not found: " & $sResolvedConfigPath)
        MsgBox($MB_ICONERROR, "Error", "Config file not found: " & $sResolvedConfigPath)
        Return
    EndIf

    ; Substitute placeholders in the CommandLine
    $sCmd = StringReplace($sCmd, "@ScriptDir@", @ScriptDir)
    $sCmd = StringReplace($sCmd, "@SongPath@", $sInput)
    $sCmd = StringReplace($sCmd, "@OutputDir@", $sOutput)

    ; Validate critical paths in the command
    Local $sEnvPath = @ScriptDir & "\installs\UVR\uvr_env\Scripts\activate.bat"
    Local $sPyPath = @ScriptDir & "\installs\UVR\uvr-main\separate.py"
    If Not FileExists($sEnvPath) Then
        LogMessage("ERROR", "Virtual environment not found: " & $sEnvPath)
        MsgBox($MB_ICONERROR, "Error", "Virtual environment not found: " & $sEnvPath)
        Return
    EndIf
    If Not FileExists($sPyPath) Then
        LogMessage("ERROR", "separate.py not found: " & $sPyPath)
        MsgBox($MB_ICONERROR, "Error", "separate.py not found: " & $sPyPath)
        Return
    EndIf

    ; Run command with progress monitoring
    LogMessage("INFO", "Resolved command: " & $sCmd)
    GUICtrlSetData($idOutputList, "Running separation for " & $sModel & "..." & @CRLF)
    Local $iPID = Run($sCmd, "", @SW_HIDE, $STDERR_MERGED)
    Local $sOutputText = ""
    Local $sProgress = "Progress: 0%"
    While ProcessExists($iPID)
        Local $sLine = StdoutRead($iPID)
        If @error Then
            ContinueLoop
        EndIf
        If $sLine <> "" Then
            $sOutputText &= $sLine
            ; Parse progress percentage from lines like "Processing:  95%|#########5| 20/21 [04:17<00:13, 13.33s/it]"
            If StringInStr($sLine, "Processing:") Then
                Local $aMatch = StringRegExp($sLine, "Processing:\s+(\d+)%", 1)
                If Not @error Then
                    $sProgress = "Progress: " & $aMatch[0] & "%"
                EndIf
            EndIf
            ; Update GUI with progress
            GUICtrlSetData($idOutputList, "Running separation for " & $sModel & "..." & @CRLF & $sProgress & @CRLF & $sOutputText)
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