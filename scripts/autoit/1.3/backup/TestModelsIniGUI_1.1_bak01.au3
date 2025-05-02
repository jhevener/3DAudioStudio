#include <Array.au3>
#include <File.au3>
#include <GUIConstantsEx.au3>
#include <MsgBoxConstants.au3>
#include <StringConstants.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
#include <GUITab.au3>
#include <EditConstants.au3>
#include <GuiEdit.au3>
#include <ScrollBarsConstants.au3>
#include <WinAPI.au3>
Global $g_sIniPath = "C:\Git\3DAudioStudio\config\testmodels.ini"
Global $g_sOutputPath = "C:\Git\3DAudioStudio\output"
Global $g_sPythonPath = "C:\Git\3DAudioStudio\venv\Scripts\python.exe"
Global $g_sSeparatePyPath = "C:\Git\3DAudioStudio\scripts\autoit\1.3\separate.py"
Global $g_sOutExt = "wav"
Global $g_sLogPath = "C:\Git\3DAudioStudio\output\log.txt"
Global $g_iMaxLogSize = 10485760
Global $g_sModelFile = "UVR_MDXNET_1_420k.pth"
Global $g_sModelName = "UVR-MDXNET_1_420k"
Global $g_iChunks = 15
Global $g_iMargin = 44100
Global $g_bDenoise = False
Global $g_iFFTSize = 6144
Global $g_iFreqDim = 2048
Global $g_iTimeDim = 8
Global $g_sInputFile = ""
Global $g_sOutputDir = ""
Global $g_hGUI = 0
Global $g_idTab = 0
Global $g_idOutputList = 0
Global $g_idModelCombo = 0
Global $g_idInputBrowse = 0
Global $g_idOutputBrowse = 0
Global $g_idRunButton = 0
Global $g_idChunksInput = 0
Global $g_idDenoiseCheckbox = 0
Global $g_idMarginInput = 0
Global $g_idFFTSizeInput = 0
Global $g_idFreqDimInput = 0
Global $g_idTimeDimInput = 0
Global $g_aModels[0]
Global $g_aModelFiles[0]
Global $g_bRunning = False
Global $g_iLastLineCount = 0
Func LogMessage($sLevel, $sMessage)
    Local $sTimeStamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $hFile = FileOpen($g_sLogPath, $FO_APPEND)
    FileWriteLine($hFile, $sTimeStamp & " [" & $sLevel & "] " & $sMessage)
    FileClose($hFile)
    Local $iFileSize = FileGetSize($g_sLogPath)
    If $iFileSize > $g_iMaxLogSize Then
        Local $aLines
        _FileReadToArray($g_sLogPath, $aLines)
        Local $iLinesToKeep = $aLines[0] / 2
        Local $hNewFile = FileOpen($g_sLogPath, $FO_OVERWRITE)
        For $i = $iLinesToKeep + 1 To $aLines[0]
            FileWriteLine($hNewFile, $aLines[$i])
        Next
        FileClose($hNewFile)
    EndIf
    _GUICtrlEdit_AppendText($g_idOutputList, $sTimeStamp & " [" & $sLevel & "] " & $sMessage & @CRLF)
    Local $iLines = _GUICtrlEdit_GetLineCount($g_idOutputList)
    If $iLines > 1000 Then
        Local $sText = _GUICtrlEdit_GetText($g_idOutputList)
        Local $aTextLines = StringSplit($sText, @CRLF, $STR_NOCOUNT)
        Local $iLinesToRemove = $iLines - 500
        Local $sNewText = ""
        For $i = $iLinesToRemove + 1 To $aTextLines[0]
            $sNewText &= $aTextLines[$i] & @CRLF
        Next
        _GUICtrlEdit_SetText($g_idOutputList, $sNewText)
    EndIf
EndFunc
Func CheckStems()
    Local $aStems = StringSplit(IniRead($g_sIniPath, "models", "OutputStems", "vocals_no_vocals|*"), "|", $STR_NOCOUNT)
    Local $sFilename = StringRegExpReplace($g_sInputFile, "^.*\\", "")
    Local $sResult = ""
    For $i = 1 To $aStems[0]
        Local $sStemFile = $g_sOutputDir & "\" & StringRegExpReplace($sFilename, "\.[^.]+$", "") & "_" & $aStems[$i] & "." & $g_sOutExt
        If FileExists($sStemFile) Then
            $sResult &= $aStems[$i] & @CRLF
        Else
            LogMessage("INFO", "Generated stem: " & $sStemFile)
            LogMessage("ERROR", "Missing! " & $sStemFile)
        EndIf
    Next
    $sResult &= @CRLF & "Full Command Line:" & @CRLF & $g_sPythonPath & " " & $g_sSeparatePyPath & " " & $g_sInputFile & " --output " & $g_sOutputDir & " --model_path " & $g_sModelFile & " --denoise " & $g_bDenoise & " --margin " & $g_iMargin & " --chunks " & $g_iChunks & " --n_fft " & $g_iFFTSize & " --dim_t " & $g_iTimeDim & " --dim_f " & $g_iFreqDim
    GUICtrlSetData($g_idOutputList, $sResult)
EndFunc
Func RunSeparation()
    LogMessage("INFO", "Starting separation process...")
    Local $sCommand = $g_sPythonPath & " " & $g_sSeparatePyPath & " " & $g_sInputFile & " --output " & $g_sOutputDir & " --model_path " & $g_sModelFile & " --denoise " & $g_bDenoise & " --margin " & $g_iMargin & " --chunks " & $g_iChunks & " --n_fft " & $g_iFFTSize & " --dim_t " & $g_iTimeDim & " --dim_f " & $g_iFreqDim
    LogMessage("INFO", "Command: " & $sCommand)
    Local $iPID = Run($sCommand, "", @SW_HIDE, $STDERR_MERGED)
    If $iPID = 0 Then
        LogMessage("ERROR", "Failed to run command: " & $sCommand)
        $g_bRunning = False
        Return
    EndIf
    Local $sOutput = ""
    While ProcessExists($iPID)
        $sOutput &= StdoutRead($iPID)
        If @error Then ExitLoop
        Local $sErrOutput = StderrRead($iPID)
        If $sErrOutput <> "" Then
            LogMessage("ERROR", "STDERR: " & $sErrOutput)
        EndIf
        If $sOutput <> "" Then
            Local $aLines = StringSplit($sOutput, @CRLF, $STR_NOCOUNT)
            For $i = 1 To $aLines[0]
                If $aLines[$i] <> "" Then
                    LogMessage("INFO", "STDOUT: " & $aLines[$i])
                EndIf
            Next
            $sOutput = ""
        EndIf
        Sleep(100)
    WEnd
    $sOutput &= StdoutRead($iPID)
    If $sOutput <> "" Then
        Local $aLines = StringSplit($sOutput, @CRLF, $STR_NOCOUNT)
        For $i = 1 To $aLines[0]
            If $aLines[$i] <> "" Then
                LogMessage("INFO", "STDOUT: " & $aLines[$i])
            EndIf
        Next
    EndIf
    Local $iExitCode = ProcessWaitClose($iPID)
    LogMessage("INFO", "Separation process completed with exit code: " & $iExitCode)
    If $iExitCode = 0 Then
        CheckStems()
    Else
        LogMessage("ERROR", "Separation failed with exit code: " & $iExitCode)
    EndIf
    $g_bRunning = False
EndFunc
Func UpdateModelInfo()
    Local $sSelectedModel = GUICtrlRead($g_idModelCombo)
    For $i = 1 To $g_aModels[0]
        If $sSelectedModel = $g_aModels[$i] Then
            $g_sModelFile = $g_aModelFiles[$i]
            $g_sModelName = $g_aModels[$i]
            ExitLoop
        EndIf
    Next
EndFunc
Func CreateGUI()
    $g_hGUI = GUICreate("Test Models.ini GUI", 800, 600)
    $g_idTab = GUICtrlCreateTab(10, 10, 780, 580)
    GUICtrlCreateTabItem("Separation")
    $g_idModelCombo = GUICtrlCreateCombo("", 30, 50, 300, 25)
    GUICtrlSetData($g_idModelCombo, _ArrayToString($g_aModels, "|", 1), $g_aModels[1])
    GUICtrlCreateLabel("Model:", 30, 80, 100, 20)
    GUICtrlCreateLabel("Input File:", 30, 110, 100, 20)
    $g_idInputBrowse = GUICtrlCreateButton("Browse", 350, 110, 80, 25)
    GUICtrlCreateLabel("Output Directory:", 30, 140, 100, 20)
    $g_idOutputBrowse = GUICtrlCreateButton("Browse", 350, 140, 80, 25)
    $g_idOutputList = GUICtrlCreateEdit("", 30, 170, 740, 300, $ES_AUTOVSCROLL + $ES_READONLY + $WS_VSCROLL)
    GUICtrlCreateLabel("Chunk Size (seconds):", 30, 480, 120, 20)
    $g_idChunksInput = GUICtrlCreateInput($g_iChunks, 150, 480, 50, 20)
    $g_idDenoiseCheckbox = GUICtrlCreateCheckbox("Enable Denoise", 220, 480, 100, 20)
    GUICtrlCreateLabel("Margin (samples):", 30, 510, 120, 20)
    $g_idMarginInput = GUICtrlCreateInput($g_iMargin, 150, 510, 50, 20)
    GUICtrlCreateLabel("FFT Size:", 330, 480, 50, 20)
    $g_idFFTSizeInput = GUICtrlCreateInput($g_iFFTSize, 380, 480, 50, 20)
    GUICtrlCreateLabel("Freq Dim:", 450, 480, 50, 20)
    $g_idFreqDimInput = GUICtrlCreateInput($g_iFreqDim, 500, 480, 50, 20)
    GUICtrlCreateLabel("Time Dim:", 570, 480, 50, 20)
    $g_idTimeDimInput = GUICtrlCreateInput($g_iTimeDim, 620, 480, 50, 20)
    $g_idRunButton = GUICtrlCreateButton("Run Separation", 680, 480, 90, 30)
    GUICtrlCreateTabItem("")
    GUISetState(@SW_SHOW)
EndFunc
Func LoadModels()
    Local $aSections = IniReadSectionNames($g_sIniPath)
    If @error Then
        LogMessage("ERROR", "Failed to read models from INI file: " & $g_sIniPath)
        Return
    EndIf
    Local $iModelCount = 0
    For $i = 1 To $aSections[0]
        If $aSections[$i] <> "models" Then
            $iModelCount += 1
        EndIf
    Next
    ReDim $g_aModels[$iModelCount + 1]
    ReDim $g_aModelFiles[$iModelCount + 1]
    $g_aModels[0] = $iModelCount
    $g_aModelFiles[0] = $iModelCount
    Local $iIndex = 1
    For $i = 1 To $aSections - 1
        If $aSections[$i] <> "models" Then
            $iModelCount += 1
        EndIf
    Next
    ReDim $g_aModels[$iModelCount + 1]
    ReDim $g_aModelFiles[$iModelCount + 1]
    $g_aModels[0] = $iModelCount
    $g_aModelFiles[0] = $iModelCount
    Local $iIndex = 1
    For $i = 1 To $aSections[0]
        If $aSections[$i] <> "models" Then
            $g_aModels[$iIndex] = $aSections[$i]
            $g_aModelFiles[$iIndex] = IniRead($g_sIniPath, $aSections[$i], "ModelFile", "")
            $iIndex += 1
        EndIf
    Next
    LogMessage("INFO", "Loaded " & $iModelCount & " models from INI file.")
EndFunc
LoadModels()
CreateGUI()
LogMessage("INFO", "Starting Test Models.ini GUI...")
While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            LogMessage("INFO", "Exiting GUI...")
            Exit
        Case $g_idModelCombo
            UpdateModelInfo()
        Case $g_idInputBrowse
            $g_sInputFile = FileOpenDialog("Select Input File", "", "Audio Files (*.wav;*.mp3;*.flac)", 1)
            If Not @error Then
                LogMessage("INFO", "Selected input file: " & $g_sInputFile)
            EndIf
        Case $g_idOutputBrowse
            $g_sOutputDir = FileSelectFolder("Select Output Directory", "")
            If Not @error Then
                LogMessage("INFO", "Selected output directory: " & $g_sOutputDir)
            EndIf
        Case $g_idRunButton
            If Not $g_bRunning Then
                $g_iChunks = GUICtrlRead($g_idChunksInput)
                $g_iMargin = GUICtrlRead($g_idMarginInput)
                $g_bDenoise = (GUICtrlRead($g_idDenoiseCheckbox) = $GUI_CHECKED)
                $g_iFFTSize = GUICtrlRead($g_idFFTSizeInput)
                $g_iFreqDim = GUICtrlRead($g_idFreqDimInput)
                $g_iTimeDim = GUICtrlRead($g_idTimeDimInput)
                If $g_sInputFile = "" Then
                    LogMessage("ERROR", "No input file selected!")
                    ContinueLoop
                EndIf
                If $g_sOutputDir = "" Then
                    LogMessage("ERROR", "No output directory selected!")
                    ContinueLoop
                EndIf
                $g_bRunning = True
                RunSeparation()
            Else
                LogMessage("INFO", "Separation already in progress...")
            EndIf
    EndSwitch
WEnd