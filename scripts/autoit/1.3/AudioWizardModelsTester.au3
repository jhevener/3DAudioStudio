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
Global $idOutputDir = GUICtrlCreateInput("", 20, 190, 480, 25)
Global $idOutputBrowse = GUICtrlCreateButton("Browse", 510, 190, 70, 25)
Global $idChunks = GUICtrlCreateInput("512", 20, 220, 80, 25)
GUICtrlCreateLabel("Chunks", 110, 225, 50, 20)
Global $idMargin = GUICtrlCreateInput("10", 160, 220, 80, 25)
GUICtrlCreateLabel("Margin", 250, 225, 50, 20)
Global $idN_FFT = GUICtrlCreateInput("6144", 300, 220, 80, 25)
GUICtrlCreateLabel("N_FFT", 390, 225, 50, 20)
Global $idDim_T = GUICtrlCreateInput("256", 20, 250, 80, 25)
GUICtrlCreateLabel("Dim_T", 110, 255, 50, 20)
Global $idDim_F = GUICtrlCreateInput("2048", 160, 250, 80, 25)
GUICtrlCreateLabel("Dim_F", 250, 255, 50, 20)
Global $idDenoise = GUICtrlCreateCheckbox("Denoise", 300, 250, 80, 25)
GUICtrlSetState($idDenoise, $GUI_CHECKED)
Global $idRunButton = GUICtrlCreateButton("Run Separation", 20, 290, 560, 30)
Global $idOutputList = GUICtrlCreateEdit("", 20, 330, 560, 150, BitOR($ES_READONLY, $WS_VSCROLL))
Global $g_sIniPath = @ScriptDir & "\installs\models.ini"
Global $g_sLogPath = @ScriptDir & "\logs\gui_log.txt"
Global $g_aModels[1][10] ; [Name, Focus, Stems, Path, Description, Comments, OutputStems, CommandLine, Chunks, Denoise]

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
    ReDim $g_aModels[$aSections[0] + 1][10]
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
        $g_aModels[$i][8] = IniRead($g_sIniPath, $aSections[$i], "Chunks", "512")
        $g_aModels[$i][9] = IniRead($g_sIniPath, $aSections[$i], "Denoise", "--denoise")
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
            GUICtrlSetData($idChunks, IniRead($g_sIniPath, $sModel, "Chunks", "512"))
            GUICtrlSetData($idMargin, IniRead($g_sIniPath, $sModel, "Margin", "10"))
            GUICtrlSetData($idN_FFT, IniRead($g_sIniPath, $sModel, "N_FFT", "6144"))
            GUICtrlSetData($idDim_T, IniRead($g_sIniPath, $sModel, "Dim_T", "256"))
            GUICtrlSetData($idDim_F, IniRead($g_sIniPath, $sModel, "Dim_F", "2048"))
            If IniRead($g_sIniPath, $sModel, "Denoise", "--denoise") = "--denoise" Then
                GUICtrlSetState($idDenoise, $GUI_CHECKED)
            Else
                GUICtrlSetState($idDenoise, $GUI_UNCHECKED)
            EndIf
            LogMessage("INFO", "Updated parameters for " & $sModel & ": Chunks=" & GUICtrlRead($idChunks) & _
                       ", Margin=" & GUICtrlRead($idMargin) & ", N_FFT=" & GUICtrlRead($idN_FFT) & _
                       ", Dim_T=" & GUICtrlRead($idDim_T) & ", Dim_F=" & GUICtrlRead($idDim_F) & _
                       ", Denoise=" & (GUICtrlRead($idDenoise) = $GUI_CHECKED ? "--denoise" : ""))
            ExitLoop
        EndIf
    Next
EndFunc

; Browse for input file
Func BrowseInput()
    Local $sFile = FileOpenDialog("Select Audio File", @ScriptDir, "Audio Files (*.mp3;*.wav;*.flac)", 1)
    If Not @error Then
        GUICtrlSetData($idInputFile, $sFile)
        LogMessage("INFO", "Selected input file: " & $sFile)
    EndIf
EndFunc

; Browse for output directory
Func BrowseOutput()
    Local $sDir = FileSelectFolder("Select Output Directory", @ScriptDir)
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
    Local $sChunks = GUICtrlRead($idChunks)
    Local $sMargin = GUICtrlRead($idMargin)
    Local $sN_FFT = GUICtrlRead($idN_FFT)
    Local $sDim_T = GUICtrlRead($idDim_T)
    Local $sDim_F = GUICtrlRead($idDim_F)
    Local $sDenoise = GUICtrlRead($idDenoise) = $GUI_CHECKED ? "--denoise" : ""

    LogMessage("INFO", "Starting separation for model: " & $sModel & ", Input: " & $sInput & ", Output: " & $sOutput)
    LogMessage("INFO", "Parameters: Chunks=" & $sChunks & ", Margin=" & $sMargin & ", N_FFT=" & $sN_FFT & _
               ", Dim_T=" & $sDim_T & ", Dim_F=" & $sDim_F & ", Denoise=" & $sDenoise)

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

    ; Substitute parameters and resolve @ScriptDir@
    $sCmd = StringReplace($sCmd, "@ScriptDir@", @ScriptDir)
    $sCmd = StringReplace($sCmd, "@SongPath@", $sInput)
    $sCmd = StringReplace($sCmd, "@OutputDir@", $sOutput)
    $sCmd = StringReplace($sCmd, "@Chunks@", $sChunks)
    $sCmd = StringReplace($sCmd, "@Margin@", $sMargin)
    $sCmd = StringReplace($sCmd, "@N_FFT@", $sN_FFT)
    $sCmd = StringReplace($sCmd, "@Dim_T@", $sDim_T)
    $sCmd = StringReplace($sCmd, "@Dim_F@", $sDim_F)
    $sCmd = StringReplace($sCmd, "@Denoise@", $sDenoise)
    LogMessage("INFO", "Resolved command: " & $sCmd)

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

    ; Run command
    GUICtrlSetData($idOutputList, "Running separation for " & $sModel & "..." & @CRLF)
    Local $iPID = Run($sCmd, "", @SW_HIDE, $STDERR_MERGED)
    Local $sOutputText = ""
    While ProcessExists($iPID)
        $sOutputText &= StdoutRead($iPID)
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