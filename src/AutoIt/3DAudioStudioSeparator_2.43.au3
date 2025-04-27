;**************************************************
;******************** Part 1 **********************
;**************************************************
#Region Part1
#Region ;**** Directives and Includes ****
; 3DAudioStudioSeparator_2.43.au3
; Version: 0.2.43
; Last Updated: 2025-04-27 16:29
; Changelog:version test
; - Initial version with SQLite integration
; - three separation routines and MDX params added.
; - Tagged as v2.43 in Git.
#AutoIt3Wrapper_Res_Description=3DAudioStudioSeparator
#AutoIt3Wrapper_Res_Fileversion=0.2.4.3
#AutoIt3Wrapper_Res_CompanyName=FretzCapo
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=None
#AutoIt3Wrapper_Run_AU3Check=Y
#AutoIt3Wrapper_AU3Check_Parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6 -w 7

; Includes for GUI, database, and file operations
#include <Array.au3>
#include <Constants.au3>
#include <File.au3>
#include <GDIPlus.au3>
#include <GuiListView.au3>
#include <GuiTab.au3>
#include <SQLite.au3>
#include <SQLite.dll.au3>
#include <StringConstants.au3>
#include <WindowsConstants.au3>
#include <GUIConstantsEx.au3>
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <ComboConstants.au3>
#include <ListViewConstants.au3>
#include <StaticConstants.au3>
#include <TabConstants.au3>
#include <WinAPI.au3>
#include <WinAPIFiles.au3>
#include <WinAPISys.au3>
#include <Date.au3>
#EndRegion ;**** Directives and Includes ****

Opt("GUIOnEventMode", 1)

#Region ;**** Global Variables and Constants ****
; Database and process variables
Global $sModelsDb = @ScriptDir & "\models.db"
Global $iPID = 0 ; Process ID for separation tasks

; Color constants for GUI elements
Global Const $GOOGLE_GREEN = 0xFF34C759
Global Const $GOOGLE_YELLOW = 0xFFF4B400
Global Const $GOOGLE_BLUE = 0xFF4285F4
Global Const $GOOGLE_RED = 0xFFDB4437
Global Const $GOOGLE_PURPLE = 0xFF673AB7
Global Const $GOOGLE_ORANGE = 0xFFF57C00
Global Const $GOOGLE_BROWN = 0xFF795548
Global Const $GOOGLE_TEAL = 0xFF26A69A
Global Const $GOOGLE_BLACK = 0xFF000000
Global Const $GRAY = 0xFF808080

; GUI elements (quadrants: input, model details, output, process list)
Global $hGUI, $hInputListView, $hOutputListView, $hBatchList, $hModelCombo, $hTab
Global $hInputDirButton, $hOutputDirButton, $hAddButton, $hClearButton, $hDeleteButton, $hSeparateButton, $hSaveSettingsButton
Global $hModelNameLabel, $hStemsLabel, $hStemsDisplay, $hFocusLabel, $hFocusDisplay
Global $hComments, $hCommentsLabel, $hCommentsEdit, $hDescEdit, $hDescLabel
Global $hProgressLabel, $hCountLabel, $hGraphic
Global $hGraphicGUI, $hDC, $hGraphics, $hBrushGray, $hBrushGreen, $hBrushYellow, $hPen
Global $iGuiWidth, $iGuiHeight
Global $hDb, $sDbFile
Global $sSettingsIni = @ScriptDir & "\settings.ini"
Global $sModelsIni = @ScriptDir & "\models.ini"
Global $sUserIni = @ScriptDir & "\user.ini"

; Paths for input and output
Global $sInputPath = @ScriptDir & "\songs"
Global $sOutputPath = @ScriptDir & "\stems"
Global $hAggressivenessLabel, $hAggressivenessInput, $hTTACheckbox, $hHighEndProcessLabel, $hHighEndProcessCombo

; UVR5 controls
Global $hInputList, $hOutputList
Global $hDemucsModelCombo, $hDemucsStemsLabel, $hDemucsStems, $hDemucsFocusLabel, $hDemucsFocus
Global $hSpleeterModelCombo, $hSpleeterStemsLabel, $hSpleeterStems, $hSpleeterFocusLabel, $hSpleeterFocus
Global $hUVR5ModelCombo, $hUVR5StemsLabel, $hUVR5Stems, $hUVR5FocusLabel, $hUVR5Focus, $hDescription, $hDescriptionLabel
Global $hSegmentSizeLabel, $hSegmentSizeInput, $hOverlapLabel, $hOverlapInput, $hDenoiseCheckbox, $hBatchSizeLabel, $hBatchSizeInput

; Initialize settings.ini with defaults if it doesn’t exist
If Not FileExists($sSettingsIni) Then
    _Log("Creating settings.ini with default values")
    ; GUI defaults
    IniWrite($sSettingsIni, "GUI", "Width", @DesktopWidth * 0.75)
    IniWrite($sSettingsIni, "GUI", "Height", @DesktopHeight * 0.75)
    IniWrite($sSettingsIni, "GUI", "LastModel", "htdemucs")
    IniWrite($sSettingsIni, "GUI", "LastTab", "0")
    IniWrite($sSettingsIni, "GUI", "LastSong", @ScriptDir & "\songs\song5.flac")
    ; Paths
    IniWrite($sSettingsIni, "Paths", "DbFile", @ScriptDir & "\models.db")
    IniWrite($sSettingsIni, "Paths", "LogDir", @ScriptDir & "\logs")
    IniWrite($sSettingsIni, "Paths", "InputDir", @ScriptDir & "\songs")
    IniWrite($sSettingsIni, "Paths", "OutputDir", @ScriptDir & "\stems")
    IniWrite($sSettingsIni, "Paths", "FFmpegPath", @ScriptDir & "\installs\uvr\ffmpeg\bin\ffmpeg.exe")
    ; MDXNet/UVR5 defaults
    IniWrite($sSettingsIni, "MDXNet", "SegmentSize", "256")
    IniWrite($sSettingsIni, "MDXNet", "Overlap", "0.25")
    IniWrite($sSettingsIni, "MDXNet", "Denoise", "false")
    IniWrite($sSettingsIni, "MDXNet", "BatchSize", "1")
    IniWrite($sSettingsIni, "MDXNet", "Aggressiveness", "10")
    IniWrite($sSettingsIni, "MDXNet", "TTA", "false")
    IniWrite($sSettingsIni, "MDXNet", "HighEndProcess", "mirroring")
    ; MDX settings (legacy or alternate)
    IniWrite($sSettingsIni, "MDX", "SegmentSize", "256")
    IniWrite($sSettingsIni, "MDX", "Overlap", "0.25")
    IniWrite($sSettingsIni, "MDX", "Denoise", "0")
    IniWrite($sSettingsIni, "MDX", "BatchSize", "1")
    IniWrite($sSettingsIni, "MDX", "Aggressiveness", "10")
    IniWrite($sSettingsIni, "MDX", "TTA", "0")
    IniWrite($sSettingsIni, "MDX", "HighEndProcess", "mirroring")
    ; Defaults
    IniWrite($sSettingsIni, "Defaults", "DefaultModel", "htdemucs")
    IniWrite($sSettingsIni, "Defaults", "DefaultTab", "0")
    IniWrite($sSettingsIni, "Defaults", "DefaultSong", @ScriptDir & "\songs\song5.flac")
EndIf

; Read GUI dimensions from settings.ini
$iGuiWidth = Int(IniRead($sSettingsIni, "GUI", "Width", @DesktopWidth * 0.75))
$iGuiHeight = Int(IniRead($sSettingsIni, "GUI", "Height", @DesktopHeight * 0.75))
_Log("GUI dimensions set: Width=" & $iGuiWidth & ", Height=" & $iGuiHeight)

; Ensure logs directory exists
If Not FileExists(@ScriptDir & "\logs") Then
    DirCreate(@ScriptDir & "\logs")
    _Log("Created logs directory: " & @ScriptDir & "\logs")
EndIf

; Define log file path with timestamp
Global $sLogFile = @ScriptDir & "\logs\StemSeparator_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & ".log.txt"
Global $hLogFile = 0 ; Initialize log file handle
_Log("Log file path set to: " & $sLogFile)
#EndRegion ;**** Global Variables and Constants ****

#Region ;**** Logging Functions ****
; Initialize the log file
Func _InitializeLog()
    Local $sLogDir = IniRead($sSettingsIni, "Paths", "LogDir", @ScriptDir & "\logs")
    If Not FileExists($sLogDir) Then
        DirCreate($sLogDir)
        _Log("Created log directory: " & $sLogDir)
    EndIf
    $sLogFile = $sLogDir & "\StemSeparator_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & ".log.txt"
    $hLogFile = FileOpen($sLogFile, $FO_OVERWRITE + $FO_CREATEPATH)
    If $hLogFile = -1 Then
        MsgBox($MB_ICONERROR, "Error", "Unable to open log file: " & $sLogFile)
        Exit
    EndIf
    FileWriteLine($hLogFile, @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & ": Script started")
    _Log("Log file initialized: " & $sLogFile)
EndFunc

; Write log messages to file and console
Func _Log($sMessage, $bError = False)
    Local $sPrefix = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    Local $sLevel = $bError ? "ERROR" : "INFO"
    Local $sLogLine = "[" & $sPrefix & "] " & $sLevel & ": " & $sMessage
    If $hLogFile = 0 Then
        $hLogFile = FileOpen($sLogFile, $FO_APPEND + $FO_CREATEPATH)
        If $hLogFile = -1 Then
            ConsoleWrite("Error: Unable to open log file: " & $sLogFile & @CRLF)
            ConsoleWrite($sLogLine & @CRLF)
            Return
        EndIf
        FileWriteLine($hLogFile, "=== Log Started: " & $sPrefix & " ===")
    EndIf
    FileWriteLine($hLogFile, $sLogLine)
    ConsoleWrite($sLogLine & @CRLF)
EndFunc

; Log startup information
Func _LogStartupInfo()
    _Log("Entering _LogStartupInfo")
    _Log("Script started")
    _Log("Script Directory: " & @ScriptDir)
    _Log("Working Directory: " & @WorkingDir)
    _Log("OS: " & @OSVersion & " (" & @OSArch & ")")
    _Log("User: " & @UserName)
    _Log("FFmpeg Path: " & IniRead($sSettingsIni, "Paths", "FFmpegPath", @ScriptDir & "\installs\uvr\ffmpeg\bin\ffmpeg.exe"))
    _Log("Models Database File: " & $sModelsDb)
    _Log("Settings INI: " & $sSettingsIni)
    _Log("Models INI: " & $sModelsIni)
    _Log("User INI: " & $sUserIni)
    _Log("Exiting _LogStartupInfo")
EndFunc
#EndRegion ;**** Logging Functions ****

#Region ;**** Initialization Functions ****
; Update model dropdown based on selected tab
Func _UpdateModelDroplist()
    _Log("Entering _UpdateModelDroplist")
    Local $iTabIndex = _GUICtrlTab_GetCurSel($hTab)
    Local $sAppFilter
    Switch $iTabIndex
        Case 0
            $sAppFilter = "Demucs"
        Case 1
            $sAppFilter = "Spleeter"
        Case 2
            $sAppFilter = "UVR5"
        Case Else
            _Log("Error: Invalid tab index: " & $iTabIndex, True)
            GUICtrlSetData($hModelCombo, "|No models available")
            Return
    EndSwitch

    Local $aResult, $iRows, $iCols
    Local $sQuery = "SELECT Models.Name FROM Models INNER JOIN ModelApps ON Models.ModelID = ModelApps.ModelID WHERE ModelApps.App = '" & $sAppFilter & "' ORDER BY Models.Name;"
    _Log("Executing query: " & $sQuery)
    Local $iRet = _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRet <> $SQLITE_OK Then
        _Log("Error: Failed to query models: " & _SQLite_ErrMsg(), True)
        GUICtrlSetData($hModelCombo, "|No models available")
        Return
    EndIf

    GUICtrlSetData($hModelCombo, "")
    Local $sModelList = ""
    If $iRows > 0 And IsArray($aResult) And UBound($aResult, 1) >= 2 Then
        For $i = 1 To $iRows
            Local $sModelName = $aResult[$i][0]
            If $sModelName <> "" Then
                $sModelList &= $sModelName & "|"
            EndIf
        Next
    EndIf

    If $sModelList <> "" Then
        $sModelList = StringTrimRight($sModelList, 1)
        _Log("Model list string: " & $sModelList)
        GUICtrlSetData($hModelCombo, "|" & $sModelList)
        ; Set default model for the tab
        Local $sDefaultModel = ($iTabIndex = 0) ? "htdemucs" : ($iTabIndex = 1) ? "2stems" : "UVR-MDX-NET-Inst-1"
        GUICtrlSetData($hModelCombo, $sDefaultModel)
    Else
        _Log("No models found for " & $sAppFilter)
        GUICtrlSetData($hModelCombo, "|No models available")
    EndIf

    ; Update model description and comments
    Local $sSelectedModel = GUICtrlRead($hModelCombo)
    If $sSelectedModel And $sSelectedModel <> "No models available" Then
        Local $aDetails = _GetModelDetails($sSelectedModel)
        If Not @error Then
            Local $sDescription = $aDetails[6]
            Local $sComments = $aDetails[7]
            GUICtrlSetData($hDescription, $sDescription <> "" ? $sDescription : "No description available.")
            GUICtrlSetData($hComments, $sComments <> "" ? $sComments : "No comments available.")
            _Log("Updated description and comments for model " & $sSelectedModel)
        Else
            GUICtrlSetData($hDescription, "Error retrieving description.")
            GUICtrlSetData($hComments, "Error retrieving comments.")
            _Log("Error: Failed to update description and comments for model " & $sSelectedModel, True)
        EndIf
    Else
        GUICtrlSetData($hDescription, "No model selected.")
        GUICtrlSetData($hComments, "No model selected.")
        _Log("No model selected to update description and comments")
    EndIf
    _Log("Exiting _UpdateModelDroplist")
EndFunc

; Retrieve model details from database
Func _GetModelDetails($sModel)
    _Log("Entering _GetModelDetails for model: " & $sModel)
    If $sModel = "" Then
        _Log("Error: Model name is empty", True)
        Return SetError(3, 0, 0)
    EndIf
    Local $aResult, $iRows, $iCols
    Local $sQuery = "SELECT ModelApps.App, ModelFocuses.Focus, Models.Name, ModelFocuses.Stems, Models.Path, Models.CommandLine, Models.Description, Models.Comments " & _
                    "FROM Models LEFT JOIN ModelApps ON Models.ModelID = ModelApps.ModelID " & _
                    "LEFT JOIN ModelFocuses ON Models.ModelID = ModelFocuses.ModelID " & _
                    "WHERE Models.Name = '" & $sModel & "';"
    _Log("Executing query: " & $sQuery)
    Local $iRet = _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRet <> $SQLITE_OK Then
        _Log("Error: SQLite query failed for model " & $sModel & ": " & _SQLite_ErrMsg(), True)
        Return SetError(1, 0, 0)
    EndIf
    If $iRows = 0 Or Not IsArray($aResult) Or UBound($aResult, 1) < 2 Then
        _Log("Error: No details found for model " & $sModel, True)
        Return SetError(2, 0, 0)
    EndIf
    Local $aReturn[8]
    For $i = 0 To 7
        $aReturn[$i] = $aResult[1][$i] = Null ? "" : $aResult[1][$i]
    Next
    _Log("Retrieved details for model " & $sModel)
    Return $aReturn
EndFunc

; Initialize models database from models.ini
Func _InitializeModels()
    _Log("Entering _InitializeModels")
    If Not FileExists($sModelsIni) Then
        _Log("Error: models.ini not found at " & $sModelsIni, True)
        MsgBox($MB_ICONERROR, "Error", "Models configuration file not found: " & $sModelsIni)
        Exit
    EndIf

    ; Check if models.db exists and if models.ini is newer
    Local $bRebuildDb = False
    If Not FileExists($sModelsDb) Then
        _Log("models.db not found, creating new database")
        $bRebuildDb = True
    Else
        Local $aIniTime = FileGetTime($sModelsIni, $FT_MODIFIED)
        Local $aDbTime = FileGetTime($sModelsDb, $FT_MODIFIED)
        If IsArray($aIniTime) And IsArray($aDbTime) Then
            Local $sIniTime = $aIniTime[0] & $aIniTime[1] & $aIniTime[2] & $aIniTime[3] & $aIniTime[4] & $aIniTime[5]
            Local $sDbTime = $aDbTime[0] & $aDbTime[1] & $aDbTime[2] & $aDbTime[3] & $aDbTime[4] & $aDbTime[5]
            If $sIniTime > $sDbTime Then
                _Log("models.ini is newer than models.db, rebuilding database")
                $bRebuildDb = True
            EndIf
        EndIf
    EndIf

    If $bRebuildDb Then
        ; Delete existing database if it exists
        If FileExists($sModelsDb) Then
            FileDelete($sModelsDb)
            _Log("Deleted existing models.db for rebuild")
        EndIf

        ; Create database and tables
        Local $iRet = _SQLite_Exec($hDb, "CREATE TABLE Models (ModelID INTEGER PRIMARY KEY, Name TEXT, Path TEXT, CommandLine TEXT, Description TEXT, Comments TEXT);")
        If $iRet <> $SQLITE_OK Then
            _Log("Error: Failed to create Models table: " & _SQLite_ErrMsg(), True)
            Return
        EndIf
        $iRet = _SQLite_Exec($hDb, "CREATE TABLE ModelApps (ModelID INTEGER, App TEXT, FOREIGN KEY(ModelID) REFERENCES Models(ModelID));")
        If $iRet <> $SQLITE_OK Then
            _Log("Error: Failed to create ModelApps table: " & _SQLite_ErrMsg(), True)
            Return
        EndIf
        $iRet = _SQLite_Exec($hDb, "CREATE TABLE ModelFocuses (ModelID INTEGER, Focus TEXT, Stems INTEGER, FOREIGN KEY(ModelID) REFERENCES Models(ModelID));")
        If $iRet <> $SQLITE_OK Then
            _Log("Error: Failed to create ModelFocuses table: " & _SQLite_ErrMsg(), True)
            Return
        EndIf
        $iRet = _SQLite_Exec($hDb, "CREATE TABLE ModelParams (ModelID INTEGER, SegmentSize INTEGER, Overlap REAL, Denoise INTEGER, BatchSize INTEGER, FOREIGN KEY(ModelID) REFERENCES Models(ModelID));")
        If $iRet <> $SQLITE_OK Then
            _Log("Error: Failed to create ModelParams table: " & _SQLite_ErrMsg(), True)
            Return
        EndIf

        ; Read models.ini and populate database
        Local $aSections = IniReadSectionNames($sModelsIni)
        If @error Then
            _Log("Error: Failed to read models.ini sections", True)
            Return
        EndIf
        For $i = 1 To $aSections[0]
            Local $sModelName = $aSections[$i]
            Local $sApp = IniRead($sModelsIni, $sModelName, "App", "")
            Local $sPath = IniRead($sModelsIni, $sModelName, "Path", "")
            Local $sCommandLine = IniRead($sModelsIni, $sModelName, "CommandLine", "")
            Local $sDescription = IniRead($sModelsIni, $sModelName, "Description", "")
            Local $sComments = IniRead($sModelsIni, $sModelName, "Comments", "")
            Local $sFocus = IniRead($sModelsIni, $sModelName, "Focus", "")
            Local $iStems = Int(IniRead($sModelsIni, $sModelName, "Stems", "2"))
            Local $iSegmentSize = Int(IniRead($sModelsIni, $sModelName, "SegmentSize", "256"))
            Local $fOverlap = Number(IniRead($sModelsIni, $sModelName, "Overlap", "0.25"))
            Local $iDenoise = Int(IniRead($sModelsIni, $sModelName, "Denoise", "0"))
            Local $iBatchSize = Int(IniRead($sModelsIni, $sModelName, "BatchSize", "1"))

            ; Insert into Models table
            $iRet = _SQLite_Exec($hDb, "INSERT INTO Models (Name, Path, CommandLine, Description, Comments) VALUES (" & _
                _SQLite_FastEscape($sModelName) & "," & _SQLite_FastEscape($sPath) & "," & _SQLite_FastEscape($sCommandLine) & "," & _
                _SQLite_FastEscape($sDescription) & "," & _SQLite_FastEscape($sComments) & ");")
            If $iRet <> $SQLITE_OK Then
                _Log("Error: Failed to insert model " & $sModelName & ": " & _SQLite_ErrMsg(), True)
                ContinueLoop
            EndIf
            Local $iModelID = _SQLite_LastInsertRowID($hDb)

            ; Insert into ModelApps table
            $iRet = _SQLite_Exec($hDb, "INSERT INTO ModelApps (ModelID, App) VALUES (" & $iModelID & "," & _SQLite_FastEscape($sApp) & ");")
            If $iRet <> $SQLITE_OK Then
                _Log("Error: Failed to insert app for model " & $sModelName & ": " & _SQLite_ErrMsg(), True)
            EndIf

            ; Insert into ModelFocuses table
            $iRet = _SQLite_Exec($hDb, "INSERT INTO ModelFocuses (ModelID, Focus, Stems) VALUES (" & $iModelID & "," & _SQLite_FastEscape($sFocus) & "," & $iStems & ");")
            If $iRet <> $SQLITE_OK Then
                _Log("Error: Failed to insert focus for model " & $sModelName & ": " & _SQLite_ErrMsg(), True)
            EndIf

            ; Insert into ModelParams table (UVR5-specific)
            $iRet = _SQLite_Exec($hDb, "INSERT INTO ModelParams (ModelID, SegmentSize, Overlap, Denoise, BatchSize) VALUES (" & _
                $iModelID & "," & $iSegmentSize & "," & $fOverlap & "," & $iDenoise & "," & $iBatchSize & ");")
            If $iRet <> $SQLITE_OK Then
                _Log("Error: Failed to insert params for model " & $sModelName & ": " & _SQLite_ErrMsg(), True)
            EndIf
        Next
        _Log("Database rebuilt successfully from models.ini")
    Else
        _Log("Using existing models.db, no rebuild needed")
    EndIf
    _Log("Exiting _InitializeModels")
EndFunc

; Set default GUI and file settings
Func SetDefaults()
    _Log("Entering SetDefaults")
    Local $iDefaultTab = 0
    _Log("Setting default tab to Demucs (index " & $iDefaultTab & ")")
    _GUICtrlTab_SetCurSel($hTab, $iDefaultTab)
    _Log("Triggering _TabHandler to initialize Demucs tab controls")
    _TabHandler()

    Local $sDrive, $sDir, $sFileName, $sExtension, $sDisplayName
    $sInputPath = IniRead($sSettingsIni, "Paths", "InputDir", @ScriptDir & "\songs")
    _Log("Setting default input path to " & $sInputPath)
    If FileExists($sInputPath) Then
        _GUICtrlListView_DeleteAllItems($hInputListView)
        Local $aInputFiles = _FileListToArrayRec($sInputPath, "*.wav;*.mp3;*.flac", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)
        If Not @error Then
            _Log("Found " & $aInputFiles[0] & " audio files in " & $sInputPath)
            For $i = 1 To $aInputFiles[0]
                _PathSplit($aInputFiles[$i], $sDrive, $sDir, $sFileName, $sExtension)
                $sDisplayName = $sFileName & $sExtension
                _GUICtrlListView_AddItem($hInputListView, $sDisplayName)
            Next
        Else
            _Log("No audio files found in " & $sInputPath)
        EndIf
    Else
        _Log("Error: Default input path " & $sInputPath & " does not exist", True)
    EndIf

    $sOutputPath = IniRead($sSettingsIni, "Paths", "OutputDir", @ScriptDir & "\stems")
    _Log("Setting default output path to " & $sOutputPath)
    If FileExists($sOutputPath) Then
        _GUICtrlListView_DeleteAllItems($hOutputListView)
        Local $aOutputFiles = _FileListToArrayRec($sOutputPath, "*.wav;*.mp3;*.flac", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)
        If Not @error Then
            _Log("Found " & $aOutputFiles[0] & " audio files in " & $sOutputPath)
            For $i = 1 To $aOutputFiles[0]
                _PathSplit($aOutputFiles[$i], $sDrive, $sDir, $sFileName, $sExtension)
                $sDisplayName = $sFileName & $sExtension
                _GUICtrlListView_AddItem($hOutputListView, $sDisplayName)
            Next
        Else
            _Log("No audio files found in " & $sOutputPath)
        EndIf
    Else
        _Log("Error: Default output path " & $sOutputPath & " does not exist", True)
    EndIf

    Local $sDefaultSong = IniRead($sSettingsIni, "GUI", "LastSong", @ScriptDir & "\songs\song5.flac")
    _Log("Adding default song " & $sDefaultSong & " to Process Queue")
    If FileExists($sDefaultSong) Then
        _GUICtrlListView_DeleteAllItems($hBatchList)
        _PathSplit($sDefaultSong, $sDrive, $sDir, $sFileName, $sExtension)
        $sDisplayName = $sFileName & $sExtension
        _GUICtrlListView_AddItem($hBatchList, $sDisplayName)
        _GUICtrlListView_SetItemChecked($hBatchList, 0, True)
        _Log("Default song " & $sDefaultSong & " added and checked successfully")
    Else
        _Log("Error: Default song " & $sDefaultSong & " does not exist", True)
    EndIf
    _Log("Exiting SetDefaults")
EndFunc

; Main application entry point
Func _Main()
    _Log("Entering _Main")
    ; Initialize logging
    _InitializeLog()
    _LogStartupInfo()

    ; Initialize GDIPlus
    _GDIPlus_Startup()
    If @error Then
        _Log("Error: Failed to initialize GDIPlus", True)
        MsgBox($MB_ICONERROR, "Error", "Failed to initialize GDIPlus")
        Exit
    EndIf
    _Log("GDIPlus initialized successfully")

    ; Initialize SQLite and open database
    _SQLite_Startup()
    If @error Then
        _Log("Error: Failed to initialize SQLite. Error code: " & @error, True)
        MsgBox($MB_ICONERROR, "Error", "Failed to initialize SQLite. Error code: " & @error)
        Exit
    EndIf
    $hDb = _SQLite_Open($sModelsDb)
    If @error Then
        _Log("Error: Failed to open database: " & $sModelsDb & ". Error code: " & @error, True)
        MsgBox($MB_ICONERROR, "Error", "Failed to open database: " & $sModelsDb & @CRLF & "Error code: " & @error)
        _SQLite_Shutdown()
        Exit
    EndIf
    _Log("Database opened successfully: " & $sModelsDb)

    ; Initialize models (rebuild database if needed)
    _InitializeModels()

    ; Create GUI
    _CreateGUI()
    If Not WinExists($hGUI) Then
        _Log("Error: Failed to create GUI", True)
        MsgBox($MB_ICONERROR, "Error", "Failed to create GUI")
        _Exit()
    EndIf
    _Log("GUI created successfully")

    ; Set event handlers
    GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit", $hGUI)
    GUICtrlSetOnEvent($hInputDirButton, "_InputDirButtonHandler")
    GUICtrlSetOnEvent($hOutputDirButton, "_OutputDirButtonHandler")
    GUICtrlSetOnEvent($hAddButton, "_AddButtonHandler")
    GUICtrlSetOnEvent($hClearButton, "_ClearButtonHandler")
    GUICtrlSetOnEvent($hDeleteButton, "_DeleteButtonHandler")
    GUICtrlSetOnEvent($hSeparateButton, "_SeparateButtonHandler")
    GUICtrlSetOnEvent($hSaveSettingsButton, "_SaveSettingsButtonHandler")
    GUICtrlSetOnEvent($hTab, "_TabHandler")

    ; Set defaults
    SetDefaults()

    ; Initialize progress bar graphics
    $hGraphicGUI = GUICreate("", $iGuiWidth - 20, 20, 10, $iGuiHeight - 30, $WS_POPUP, $WS_EX_MDICHILD, $hGUI)
    GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit", $hGraphicGUI)
    $hDC = _WinAPI_GetDC($hGraphicGUI)
    $hGraphics = _GDIPlus_GraphicsCreateFromHDC($hDC)
    $hBrushGray = _GDIPlus_BrushCreateSolid($GRAY)
    $hBrushGreen = _GDIPlus_BrushCreateSolid($GOOGLE_GREEN)
    $hBrushYellow = _GDIPlus_BrushCreateSolid($GOOGLE_YELLOW)
    $hPen = _GDIPlus_PenCreate($GOOGLE_BLUE, 2)
    _GDIPlus_GraphicsFillRect($hGraphics, 0, 0, $iGuiWidth - 20, 20, $hBrushGray)
    GUISetState(@SW_SHOW, $hGraphicGUI)
    $hProgressLabel = GUICtrlCreateLabel("Task Progress: 0%", 10, $iGuiHeight - 50, 120, 20)
    _ResetProgressBar()

    _Log("Entering main event loop")
    While 1
        If Not WinExists($hGUI) Then
            _Log("Main GUI closed, exiting")
            _Exit()
        EndIf
        Sleep(100)
    WEnd
EndFunc

; Reset progress bar to initial state
Func _ResetProgressBar()
    _Log("Resetting progress bar")
    _GDIPlus_GraphicsFillRect($hGraphics, 0, 0, $iGuiWidth - 20, 20, $hBrushGray)
    GUICtrlSetData($hProgressLabel, "Task Progress: 0%")
EndFunc

; Application exit cleanup
Func _Exit()
    _Log("Entering _Exit")
    _GDIPlus_BrushDispose($hBrushGray)
    _GDIPlus_BrushDispose($hBrushGreen)
    _GDIPlus_BrushDispose($hBrushYellow)
    _GDIPlus_PenDispose($hPen)
    _GDIPlus_GraphicsDispose($hGraphics)
    _WinAPI_ReleaseDC($hGraphicGUI, $hDC)
    _GDIPlus_Shutdown()
    _SQLite_Close($hDb)
    _SQLite_Shutdown()
    If $hLogFile <> 0 Then
        FileClose($hLogFile)
    EndIf
    _Log("Script terminated")
    Exit
EndFunc

; Start the application
_Main()
#EndRegion ;**** Initialization Functions ****
#EndRegion Part1



;**************************************************
; AudioWizardSeparator.au3 - Part 2
;**************************************************
#Region Part2
#Region ;**** GUI Creation ****
Func _CreateGUI()
    _Log("Entering _CreateGUI")
    $hGUI = GUICreate("AudioWizardSeparator", $iGuiWidth, $iGuiHeight, -1, -1, BitOR($WS_MINIMIZEBOX, $WS_MAXIMIZEBOX, $WS_SIZEBOX))
    GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
    GUISetBkColor(0xFFFFFF)
    Local $iMargin = 10
    Local $iButtonWidth = 100
    Local $iButtonHeight = 30
    Local $iListViewWidth = ($iGuiWidth - 3 * $iMargin) / 2
    Local $iListViewHeight = 150
    Local $iControlWidth = $iListViewWidth
    Local $iLabelHeight = 20
    Local $iComboHeight = 25
    Local $iQuadrantHeight = 120
    Local $iDescEditHeight = 40
    Local $iCommentsHeight = 60
    Local $iBottomControlsHeight = $iButtonHeight + $iLabelHeight + 20 + $iMargin
    $hTab = GUICtrlCreateTab($iMargin, $iMargin, $iGuiWidth - 2 * $iMargin, $iGuiHeight - 2 * $iMargin)
    GUICtrlCreateTabItem("Demucs")
    GUICtrlCreateTabItem("Spleeter")
    GUICtrlCreateTabItem("UVR5")
    GUICtrlCreateTabItem("")
    GUICtrlSetOnEvent($hTab, "_TabHandler")
    $hInputListView = GUICtrlCreateListView("Input Files", $iMargin, $iMargin + 30, $iListViewWidth, $iListViewHeight)
    _GUICtrlListView_SetExtendedListViewStyle($hInputListView, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_CHECKBOXES, $LVS_EX_DOUBLEBUFFER, $LVS_EX_INFOTIP))
    GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
    Local $hContextMenu = GUICtrlCreateContextMenu($hInputListView)
    Local $hAddMenuItem = GUICtrlCreateMenuItem("Add to Queue", $hContextMenu)
    GUICtrlSetOnEvent(-1, "_AddButtonHandler")
    $hOutputListView = GUICtrlCreateListView("Output Files", $iMargin + $iListViewWidth + $iMargin, $iMargin + 30, $iListViewWidth, $iListViewHeight)
    _GUICtrlListView_SetExtendedListViewStyle($hOutputListView, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_DOUBLEBUFFER))
    GUICtrlSetResizing(-1, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
    $hInputDirButton = GUICtrlCreateButton("Select Input Dir", $iMargin, $iMargin + $iListViewHeight + $iMargin + 30, $iButtonWidth, $iButtonHeight)
    GUICtrlSetOnEvent(-1, "_InputDirButtonHandler")
    GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
    $hOutputDirButton = GUICtrlCreateButton("Select Output Dir", $iMargin + $iListViewWidth + $iMargin, $iMargin + $iListViewHeight + $iMargin + 30, $iButtonWidth, $iButtonHeight)
    GUICtrlSetOnEvent(-1, "_OutputDirButtonHandler")
    GUICtrlSetResizing(-1, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
    $hAddButton = GUICtrlCreateButton("Add Files", $iMargin + $iButtonWidth + $iMargin, $iMargin + $iListViewHeight + $iMargin + 30, $iButtonWidth, $iButtonHeight)
    GUICtrlSetOnEvent(-1, "_AddButtonHandler")
    GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
    $hClearButton = GUICtrlCreateButton("Clear Queue", $iMargin + $iListViewWidth + $iMargin + $iButtonWidth + $iMargin, $iMargin + $iListViewHeight + $iMargin + 30, $iButtonWidth, $iButtonHeight)
    GUICtrlSetOnEvent(-1, "_ClearButtonHandler")
    GUICtrlSetResizing(-1, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
    $hDeleteButton = GUICtrlCreateButton("Delete Selected", $iMargin + $iListViewWidth + $iMargin + 2 * $iButtonWidth + 2 * $iMargin, $iMargin + $iListViewHeight + $iMargin + 30, $iButtonWidth, $iButtonHeight)
    GUICtrlSetOnEvent(-1, "_DeleteButtonHandler")
    GUICtrlSetResizing(-1, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
    $hBatchList = GUICtrlCreateListView("Process Queue|Selected", $iMargin, $iMargin + $iListViewHeight + 2 * $iMargin + $iButtonHeight + 30, $iGuiWidth - 2 * $iMargin, $iListViewHeight, BitOR($LVS_REPORT, $LVS_SHOWSELALWAYS))
    _GUICtrlListView_SetExtendedListViewStyle($hBatchList, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_CHECKBOXES, $LVS_EX_DOUBLEBUFFER))
    GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
    $hAppCombo = GUICtrlCreateCombo("", $iMargin + $iListViewWidth + $iMargin, $iMargin + 2 * $iListViewHeight + 3 * $iMargin + $iButtonHeight + 30, $iControlWidth, $iComboHeight, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetData(-1, "Demucs|Spleeter|UVR5", "Demucs")
    GUICtrlSetOnEvent(-1, "_AppComboHandler")
    GUICtrlSetResizing(-1, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
    Local $iBaseY = $iMargin + 2 * $iListViewHeight + 4 * $iMargin + $iButtonHeight + $iComboHeight + 30
    $hSettingsCombo = GUICtrlCreateCombo("", $iMargin + $iListViewWidth + $iMargin, $iBaseY, $iControlWidth, $iComboHeight, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetOnEvent(-1, "_LoadSettings")
    GUICtrlSetResizing(-1, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
    $hModelCombo = GUICtrlCreateCombo("", $iMargin + $iListViewWidth + $iMargin, $iBaseY + $iComboHeight + $iMargin, $iControlWidth, $iComboHeight, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetOnEvent(-1, "_ModelComboHandler")
    GUICtrlSetResizing(-1, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
    Local $iParamY = $iBaseY + 2 * $iComboHeight + 2 * $iMargin
    If GUICtrlRead($hAppCombo) = "UVR5" Then
        $hSegmentSizeLabel = GUICtrlCreateLabel("Segment Size:", $iMargin + $iControlWidth + $iMargin, $iParamY, 80, $iLabelHeight)
        $hSegmentSizeCombo = GUICtrlCreateCombo("", $iMargin + $iControlWidth + $iMargin + 80, $iParamY, 80, $iComboHeight, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
        GUICtrlSetData(-1, "256|512|1024", "512")
        $hOverlapLabel = GUICtrlCreateLabel("Overlap:", $iMargin + $iControlWidth + $iMargin + 160, $iParamY, 80, $iLabelHeight)
        $hOverlapInput = GUICtrlCreateInput("", $iMargin + $iControlWidth + $iMargin + 240, $iParamY, 80, $iComboHeight)
        GUICtrlSetLimit($hOverlapInput, 4, 1)
        GUICtrlSetResizing($hSegmentSizeLabel, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        GUICtrlSetResizing($hSegmentSizeCombo, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        GUICtrlSetResizing($hOverlapLabel, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        GUICtrlSetResizing($hOverlapInput, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        $iParamY += $iComboHeight + $iMargin
        $hAggressivenessLabel = GUICtrlCreateLabel("Aggressiveness:", $iMargin + $iControlWidth + $iMargin, $iParamY, 80, $iLabelHeight)
        $hAggressivenessInput = GUICtrlCreateInput("", $iMargin + $iControlWidth + $iMargin + 80, $iParamY, 80, $iComboHeight)
        GUICtrlSetLimit($hAggressivenessInput, 2, 1)
        $hDenoiseCheckbox = GUICtrlCreateCheckbox("Denoise", $iMargin + $iControlWidth + $iMargin + 160, $iParamY, 60, $iLabelHeight)
        $hTTACheckbox = GUICtrlCreateCheckbox("TTA", $iMargin + $iControlWidth + $iMargin + 220, $iParamY, 60, $iLabelHeight)
        GUICtrlSetResizing($hAggressivenessLabel, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        GUICtrlSetResizing($hAggressivenessInput, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        GUICtrlSetResizing($hDenoiseCheckbox, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        GUICtrlSetResizing($hTTACheckbox, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        _Log("Created UVR5 parameter controls at Y=" & $iParamY)
    EndIf
    Local $iLowerControlsY = $iBaseY + $iQuadrantHeight + $iMargin
    $hModelNameLabel = GUICtrlCreateLabel("Model Name:", $iMargin, $iLowerControlsY, $iControlWidth, $iLabelHeight)
    $hStemsLabel = GUICtrlCreateLabel("Stems:", $iMargin, $iLowerControlsY + $iLabelHeight + $iMargin, $iControlWidth / 2, $iLabelHeight)
    $hStemsDisplay = GUICtrlCreateLabel("", $iMargin + $iControlWidth / 2, $iLowerControlsY + $iLabelHeight + $iMargin, $iControlWidth / 2, $iLabelHeight)
    $hFocusLabel = GUICtrlCreateLabel("Focus:", $iMargin, $iLowerControlsY + 2 * ($iLabelHeight + $iMargin), $iControlWidth / 2, $iLabelHeight)
    $hFocusDisplay = GUICtrlCreateLabel("", $iMargin + $iControlWidth / 2, $iLowerControlsY + 2 * ($iLabelHeight + $iMargin), $iControlWidth / 2, $iLabelHeight)
    $hDescLabel = GUICtrlCreateLabel("Description:", $iMargin, $iLowerControlsY + 3 * ($iLabelHeight + $iMargin), $iControlWidth, $iLabelHeight)
    $hDescEdit = GUICtrlCreateEdit("", $iMargin, $iLowerControlsY + 4 * ($iLabelHeight + $iMargin), $iControlWidth, $iDescEditHeight, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $WS_VSCROLL))
    GUICtrlSetOnEvent(-1, "_DescEditHandler")
    Local $iCommentsY = $iLowerControlsY + 4 * ($iLabelHeight + $iMargin) + $iDescEditHeight + $iMargin
    $hCommentsLabel = GUICtrlCreateLabel("Comments:", $iMargin, $iCommentsY, $iControlWidth, $iLabelHeight)
    $hCommentsEdit = GUICtrlCreateEdit("", $iMargin, $iCommentsY + $iLabelHeight, $iControlWidth, $iCommentsHeight, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL, $WS_VSCROLL))
    GUICtrlSetOnEvent(-1, "_CommentsEditHandler")
    $hSeparateButton = GUICtrlCreateButton("Separate", $iMargin, $iGuiHeight - $iBottomControlsHeight + $iMargin, $iButtonWidth, $iButtonHeight)
    GUICtrlSetOnEvent(-1, "_SeparateButtonHandler")
    $hSaveSettingsButton = GUICtrlCreateButton("Save Settings", $iMargin + $iButtonWidth + $iMargin, $iGuiHeight - $iBottomControlsHeight + $iMargin, $iButtonWidth, $iButtonHeight)
    GUICtrlSetOnEvent(-1, "_SaveSettingsButtonHandler")
    $hProgressLabel = GUICtrlCreateLabel("Progress: 0%", $iGuiWidth - $iMargin - $iControlWidth / 2, $iGuiHeight - $iLabelHeight - 20 - $iMargin, $iControlWidth / 2, $iLabelHeight)
    $hCountLabel = GUICtrlCreateLabel("0 of 0", $iGuiWidth - $iMargin - $iControlWidth / 2, $iGuiHeight - 20 - $iMargin, $iControlWidth / 2, $iLabelHeight)
    $hGraphic = GUICtrlCreateGraphic($iMargin, $iGuiHeight - 20 - $iMargin, $iGuiWidth - 2 * $iMargin, 20)
    _GDIPlus_Startup()
    $hGraphicGUI = _GDIPlus_GraphicsCreateFromHWND(GUICtrlGetHandle($hGraphic))
    $hDC = _WinAPI_GetDC(GUICtrlGetHandle($hGraphic))
    $hGraphics = _GDIPlus_GraphicsCreateFromHDC($hDC)
    $hBrushGray = _GDIPlus_BrushCreateSolid(0xFF808080)
    $hBrushGreen = _GDIPlus_BrushCreateSolid($GOOGLE_GREEN)
    $hBrushYellow = _GDIPlus_BrushCreateSolid($GOOGLE_YELLOW)
    $hPen = _GDIPlus_PenCreate(0xFF000000, 1)
    GUIRegisterMsg($WM_NOTIFY, "_WM_NOTIFY")
    GUISetState(@SW_SHOW)
    _UpdateAppControls($iListViewWidth, $iListViewHeight, $iButtonHeight, $iMargin, $iControlWidth, $iComboHeight)
    _Log("GUI created successfully")
    _Log("Exiting _CreateGUI")
EndFunc
#EndRegion ;**** GUI Creation ****

#Region ;**** Model Management ****
Func _UpdateAppControls($iListViewWidth, $iListViewHeight, $iButtonHeight, $iMargin, $iControlWidth, $iComboHeight)
    _Log("Entering _UpdateAppControls")
    Local $sApp = GUICtrlRead($hAppCombo)
    _Log("Selected app: " & $sApp)
    If $hSettingsCombo <> 0 Then
        _Log("Deleting control: hSettingsCombo")
        GUICtrlDelete($hSettingsCombo)
    EndIf
    If $hModelCombo <> 0 Then
        _Log("Deleting control: hModelCombo")
        GUICtrlDelete($hModelCombo)
    EndIf
    If $hSegmentSizeLabel <> 0 Then
        _Log("Deleting control: hSegmentSizeLabel")
        GUICtrlDelete($hSegmentSizeLabel)
    EndIf
    If $hSegmentSizeCombo <> 0 Then
        _Log("Deleting control: hSegmentSizeCombo")
        GUICtrlDelete($hSegmentSizeCombo)
    EndIf
    If $hOverlapLabel <> 0 Then
        _Log("Deleting control: hOverlapLabel")
        GUICtrlDelete($hOverlapLabel)
    EndIf
    If $hOverlapInput <> 0 Then
        _Log("Deleting control: hOverlapInput")
        GUICtrlDelete($hOverlapInput)
    EndIf
    If $hDenoiseCheckbox <> 0 Then
        _Log("Deleting control: hDenoiseCheckbox")
        GUICtrlDelete($hDenoiseCheckbox)
    EndIf
    If $hAggressivenessLabel <> 0 Then
        _Log("Deleting control: hAggressivenessLabel")
        GUICtrlDelete($hAggressivenessLabel)
    EndIf
    If $hAggressivenessInput <> 0 Then
        _Log("Deleting control: hAggressivenessInput")
        GUICtrlDelete($hAggressivenessInput)
    EndIf
    If $hTTACheckbox <> 0 Then
        _Log("Deleting control: hTTACheckbox")
        GUICtrlDelete($hTTACheckbox)
    EndIf
    $hSettingsCombo = 0
    $hModelCombo = 0
    $hSegmentSizeLabel = 0
    $hSegmentSizeCombo = 0
    $hOverlapLabel = 0
    $hOverlapInput = 0
    $hDenoiseCheckbox = 0
    $hAggressivenessLabel = 0
    $hAggressivenessInput = 0
    $hTTACheckbox = 0
    Local $iLabelHeight = 20
    Local $iInputHeight = 25
    Local $iBaseY = $iMargin + 2 * $iListViewHeight + 4 * $iMargin + $iButtonHeight + $iComboHeight + 30
    $hSettingsCombo = GUICtrlCreateCombo("", $iMargin + $iListViewWidth + $iMargin, $iBaseY, $iControlWidth, $iComboHeight, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetOnEvent(-1, "_LoadSettings")
    GUICtrlSetResizing(-1, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
    _Log("Created SettingsCombo at Y=" & $iBaseY)
    $hModelCombo = GUICtrlCreateCombo("", $iMargin + $iListViewWidth + $iMargin, $iBaseY + $iComboHeight + $iMargin, $iControlWidth, $iComboHeight, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetOnEvent(-1, "_ModelComboHandler")
    GUICtrlSetResizing(-1, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
    _Log("Created ModelCombo at Y=" & $iBaseY + $iComboHeight + $iMargin)
    If $sApp = "UVR5" Then
        Local $iParamY = $iBaseY + 2 * $iComboHeight + 2 * $iMargin
        $hSegmentSizeLabel = GUICtrlCreateLabel("Segment Size:", $iMargin + $iControlWidth + $iMargin, $iParamY, 80, $iLabelHeight)
        $hSegmentSizeCombo = GUICtrlCreateCombo("", $iMargin + $iControlWidth + $iMargin + 80, $iParamY, 80, $iComboHeight, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
        GUICtrlSetData(-1, "256|512|1024", "512")
        $hOverlapLabel = GUICtrlCreateLabel("Overlap:", $iMargin + $iControlWidth + $iMargin + 160, $iParamY, 80, $iLabelHeight)
        $hOverlapInput = GUICtrlCreateInput("", $iMargin + $iControlWidth + $iMargin + 240, $iParamY, 80, $iInputHeight)
        GUICtrlSetLimit($hOverlapInput, 4, 1)
        GUICtrlSetResizing($hSegmentSizeLabel, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        GUICtrlSetResizing($hSegmentSizeCombo, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        GUICtrlSetResizing($hOverlapLabel, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        GUICtrlSetResizing($hOverlapInput, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        $iParamY += $iInputHeight + $iMargin
        $hAggressivenessLabel = GUICtrlCreateLabel("Aggressiveness:", $iMargin + $iControlWidth + $iMargin, $iParamY, 80, $iLabelHeight)
        $hAggressivenessInput = GUICtrlCreateInput("", $iMargin + $iControlWidth + $iMargin + 80, $iParamY, 80, $iInputHeight)
        GUICtrlSetLimit($hAggressivenessInput, 2, 1)
        $hDenoiseCheckbox = GUICtrlCreateCheckbox("Denoise", $iMargin + $iControlWidth + $iMargin + 160, $iParamY, 60, $iLabelHeight)
        $hTTACheckbox = GUICtrlCreateCheckbox("TTA", $iMargin + $iControlWidth + $iMargin + 220, $iParamY, 60, $iLabelHeight)
        GUICtrlSetResizing($hAggressivenessLabel, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        GUICtrlSetResizing($hAggressivenessInput, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        GUICtrlSetResizing($hDenoiseCheckbox, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        GUICtrlSetResizing($hTTACheckbox, $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
        _Log("Created UVR5 parameter controls at Y=" & $iParamY)
    EndIf
    _UpdateSettingsDroplist()
    _UpdateModelDroplist()
    Local $sCurrentModel = GUICtrlRead($hModelCombo)
    If $sCurrentModel <> "" And $sCurrentModel <> "No models available" Then
        _UpdateModelDetails($sCurrentModel)
    Else
        _UpdateModelDetails("")
    EndIf
    _Log("Exiting _UpdateAppControls")
EndFunc

Func _UpdateSettingsDroplist()
    _Log("Entering _UpdateSettingsDroplist")
    Local $sQuery = "SELECT Name FROM SavedSettings ORDER BY Name;"
    Local $aResult, $iRows, $iCols
    Local $iRet = _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRet <> $SQLITE_OK Then
        _Log("Failed to query saved settings: " & _SQLite_ErrMsg(), True)
        GUICtrlSetData($hSettingsCombo, "|No settings available")
        Return
    EndIf
    GUICtrlSetData($hSettingsCombo, "")
    Local $sSettingsList = ""
    If $iRows > 0 And IsArray($aResult) And UBound($aResult, 1) >= 2 Then
        For $i = 1 To $iRows
            Local $sSettingName = $aResult[$i][0]
            If $sSettingName <> "" Then
                $sSettingsList &= $sSettingName & "|"
            EndIf
        Next
    EndIf
    If $sSettingsList <> "" Then
        $sSettingsList = StringTrimRight($sSettingsList, 1)
        _Log("Settings list string: " & $sSettingsList)
        GUICtrlSetData($hSettingsCombo, "|" & $sSettingsList)
    Else
        _Log("No saved settings found")
        GUICtrlSetData($hSettingsCombo, "|No settings available")
    EndIf
    _Log("Exiting _UpdateSettingsDroplist")
EndFunc

Func _UpdateModelDroplist()
    _Log("Entering _UpdateModelDroplist")
    Local $sAppFilter = GUICtrlRead($hAppCombo)
    If $sAppFilter = "" Then
        _Log("No app selected in AppCombo", True)
        GUICtrlSetData($hModelCombo, "|No models available")
        Return
    EndIf
    Local $aResult, $iRows, $iCols
    Local $sQuery = "SELECT Models.Name FROM Models INNER JOIN ModelApps ON Models.ModelID = ModelApps.ModelID WHERE ModelApps.App = '" & _SQLite_Escape($sAppFilter) & "' ORDER BY Models.Name;"
    _Log("Executing query: " & $sQuery)
    Local $iRet = _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRet <> $SQLITE_OK Then
        _Log("Failed to query models: " & _SQLite_ErrMsg(), True)
        GUICtrlSetData($hModelCombo, "|No models available")
        Return
    EndIf
    GUICtrlSetData($hModelCombo, "")
    Local $sModelList = ""
    If $iRows > 0 And IsArray($aResult) And UBound($aResult, 1) >= 2 Then
        For $i = 1 To $iRows
            Local $sModelName = $aResult[$i][0]
            If $sModelName <> "" Then
                $sModelList &= $sModelName & "|"
            EndIf
        Next
    EndIf
    If $sModelList <> "" Then
        $sModelList = StringTrimRight($sModelList, 1)
        _Log("Model list string: " & $sModelList)
        GUICtrlSetData($hModelCombo, "|" & $sModelList, StringSplit($sModelList, "|", $STR_NOCOUNT)[0])
    Else
        _Log("No models found for " & $sAppFilter)
        GUICtrlSetData($hModelCombo, "|No models available")
    EndIf
    _Log("Exiting _UpdateModelDroplist")
EndFunc

Func _UpdateModelDetails($sModel)
    _Log("Entering _UpdateModelDetails for model: " & $sModel)
    If $sModel = "" Then
        _Log("Model name is empty", True)
        GUICtrlSetData($hModelNameLabel, "Model Name: None")
        GUICtrlSetData($hStemsDisplay, "")
        GUICtrlSetData($hFocusDisplay, "")
        GUICtrlSetData($hDescEdit, "")
        GUICtrlSetData($hCommentsEdit, "")
        If $hSegmentSizeCombo <> 0 Then GUICtrlSetData($hSegmentSizeCombo, "512")
        If $hOverlapInput <> 0 Then GUICtrlSetData($hOverlapInput, "")
        If $hDenoiseCheckbox <> 0 Then GUICtrlSetState($hDenoiseCheckbox, $GUI_UNCHECKED)
        If $hAggressivenessInput <> 0 Then GUICtrlSetData($hAggressivenessInput, "")
        If $hTTACheckbox <> 0 Then GUICtrlSetState($hTTACheckbox, $GUI_UNCHECKED)
        Return
    EndIf
    Local $aDetails = _GetModelDetails($sModel)
    If @error Then
        _Log("Failed to get details for model " & $sModel, True)
        Return
    EndIf
    GUICtrlSetData($hModelNameLabel, "Model Name: " & $aDetails[2])
    GUICtrlSetData($hStemsDisplay, $aDetails[3])
    GUICtrlSetData($hFocusDisplay, $aDetails[1])
    GUICtrlSetData($hDescEdit, $aDetails[6])
    GUICtrlSetData($hCommentsEdit, $aDetails[7])
    Local $aParams = _GetModelParameters($sModel)
    If @error Or GUICtrlRead($hAppCombo) <> "UVR5" Then
        _Log("No parameters available for model " & $sModel & " or non-UVR5 app selected")
        If $hSegmentSizeCombo <> 0 Then GUICtrlSetData($hSegmentSizeCombo, "512")
        If $hOverlapInput <> 0 Then GUICtrlSetData($hOverlapInput, "")
        If $hDenoiseCheckbox <> 0 Then GUICtrlSetState($hDenoiseCheckbox, $GUI_UNCHECKED)
        If $hAggressivenessInput <> 0 Then GUICtrlSetData($hAggressivenessInput, "")
        If $hTTACheckbox <> 0 Then GUICtrlSetState($hTTACheckbox, $GUI_UNCHECKED)
        Return
    EndIf
    If $hSegmentSizeCombo <> 0 Then GUICtrlSetData($hSegmentSizeCombo, $aParams[0] = "" ? "512" : $aParams[0])
    If $hOverlapInput <> 0 Then GUICtrlSetData($hOverlapInput, $aParams[1] = "" ? "0.0" : $aParams[1])
    If $hDenoiseCheckbox <> 0 Then GUICtrlSetState($hDenoiseCheckbox, $aParams[2] = "True" ? $GUI_CHECKED : $GUI_UNCHECKED)
    If $hAggressivenessInput <> 0 Then GUICtrlSetData($hAggressivenessInput, $aParams[3] = "" ? "10" : $aParams[3])
    If $hTTACheckbox <> 0 Then GUICtrlSetState($hTTACheckbox, $aParams[4] = "True" ? $GUI_CHECKED : $GUI_UNCHECKED)
    _Log("Exiting _UpdateModelDetails")
EndFunc

Func _AppComboHandler()
    _Log("Entering _AppComboHandler")
    Local $iMargin = 10
    Local $iListViewWidth = ($iGuiWidth - 3 * $iMargin) / 2
    Local $iListViewHeight = 150
    Local $iButtonHeight = 30
    Local $iControlWidth = $iListViewWidth
    Local $iComboHeight = 25
    _UpdateAppControls($iListViewWidth, $iListViewHeight, $iButtonHeight, $iMargin, $iControlWidth, $iComboHeight)
    _Log("Exiting _AppComboHandler")
EndFunc
#EndRegion ;**** Model Management ****
#EndRegion Part2






#Region ;**** Model Management Functions ****
Func _CreateGUI()
    ; Read GUI size from settings.ini
    $iGuiWidth = Int(IniRead($sSettingsIni, "GUI", "Width", @DesktopWidth * 0.75))
    $iGuiHeight = Int(IniRead($sSettingsIni, "GUI", "Height", @DesktopHeight * 0.75))
    $hGUI = GUICreate("Stem Separator", $iGuiWidth, $iGuiHeight)

    ; Top buttons for user interaction
    $hInputDirButton = GUICtrlCreateButton("Input Dir", 10, 5, 60, 25)
    $hOutputDirButton = GUICtrlCreateButton("Output Dir", 80, 5, 60, 25)
    $hAddButton = GUICtrlCreateButton("Add", 150, 5, 60, 25)
    $hClearButton = GUICtrlCreateButton("Clear", 220, 5, 60, 25)
    $hDeleteButton = GUICtrlCreateButton("Delete", 290, 5, 60, 25)
    $hSeparateButton = GUICtrlCreateButton("Separate", 360, 5, 60, 25)
    $hSaveSettingsButton = GUICtrlCreateButton("Save Settings", 430, 5, 80, 25)

    ; Input and Output Lists to display files
    $hInputList = GUICtrlCreateListView("Input Files", 10, 40, 280, 300)
    $hInputListView = $hInputList  ; Assign the control ID to the global variable
    $hOutputList = GUICtrlCreateListView("Output Files", 10, 350, 280, 300)
    $hOutputListView = $hOutputList  ; Assign the control ID to the global variable

    ; Process Queue ListView (Lower Right)
    $hBatchList = GUICtrlCreateListView("Process Queue", 576, 350, 576, 300)  ; Positioned in the lower right quadrant

    ; Model Selection Tabs for Demucs, Spleeter, and UVR5
    $hTab = GUICtrlCreateTab(576, 10, 576, 300) ; Adjusted width to span remaining GUI width (1152 - 576 = 576)
    GUICtrlCreateTabItem("Demucs")
    ; Demucs controls (e.g., model dropdown, labels)
    $hDemucsModelCombo = GUICtrlCreateCombo("", 586, 40, 180, 20)
    $hDemucsStemsLabel = GUICtrlCreateLabel("Stems:", 586, 70, 50, 20)
    $hDemucsStems = GUICtrlCreateLabel("", 636, 70, 50, 20)
    $hDemucsFocusLabel = GUICtrlCreateLabel("Focus:", 586, 90, 50, 20)
    $hDemucsFocus = GUICtrlCreateLabel("", 636, 90, 130, 20)

    GUICtrlCreateTabItem("Spleeter")
    ; Spleeter controls
    $hSpleeterModelCombo = GUICtrlCreateCombo("", 586, 40, 180, 20)
    $hSpleeterStemsLabel = GUICtrlCreateLabel("Stems:", 586, 70, 50, 20)
    $hSpleeterStems = GUICtrlCreateLabel("", 636, 70, 50, 20)
    $hSpleeterFocusLabel = GUICtrlCreateLabel("Focus:", 586, 90, 50, 20)
    $hSpleeterFocus = GUICtrlCreateLabel("", 636, 90, 130, 20)

    GUICtrlCreateTabItem("UVR5")
    ; UVR5 controls
    $hUVR5ModelCombo = GUICtrlCreateCombo("", 586, 40, 180, 20)
    $hUVR5StemsLabel = GUICtrlCreateLabel("Stems:", 586, 70, 50, 20)
    $hUVR5Stems = GUICtrlCreateLabel("", 636, 70, 50, 20)
    $hUVR5FocusLabel = GUICtrlCreateLabel("Focus:", 586, 90, 50, 20)
    $hUVR5Focus = GUICtrlCreateLabel("", 636, 90, 130, 20)
    ; New UVR5-specific controls, adjusted to fit below existing controls
    $hSegmentSizeLabel = GUICtrlCreateLabel("Segment Size:", 776, 40, 80, 15)
    $hSegmentSizeInput = GUICtrlCreateInput("256", 876, 40, 40, 15)
    $hOverlapLabel = GUICtrlCreateLabel("Overlap:", 776, 55, 80, 15)
    $hOverlapInput = GUICtrlCreateInput("0.25", 876, 55, 40, 15)
    $hDenoiseCheckbox = GUICtrlCreateCheckbox("Denoise", 776, 70, 60, 15)
    $hBatchSizeLabel = GUICtrlCreateLabel("Batch Size:", 776, 85, 80, 15)
    $hBatchSizeInput = GUICtrlCreateInput("1", 876, 85, 40, 15)

    GUICtrlCreateTabItem("")

    ; Additional labels (e.g., Description, Comments) below tabs
    $hDescriptionLabel = GUICtrlCreateLabel("Description:", 586, 320, 70, 20)
    $hDescription = GUICtrlCreateLabel("", 656, 320, 200, 40)
    $hCommentsLabel = GUICtrlCreateLabel("Comments:", 586, 360, 70, 20)
    $hComments = GUICtrlCreateLabel("", 656, 360, 200, 40)

    ; Show the GUI
    GUISetState(@SW_SHOW)
    FileWriteLine($hLogFile, @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & ": Exiting _CreateGUI")
EndFunc

#EndRegion ;**** Model Management Functions ****




Func _InitializeModels()
    _Log("Entering _InitializeModels")
    _SQLite_Startup()
    If @error Then
        _Log("Failed to start SQLite: Error " & @error, True)
        MsgBox($MB_ICONERROR, "Error", "Unable to initialize SQLite.")
        Return SetError(1, 0, False)
    EndIf

    If Not FileExists($sDbFile) Then
        _Log("Database file does not exist: " & $sDbFile & ". Creating from Models.ini")
        $hDb = _SQLite_Open($sDbFile)
        If @error Then
            _Log("Failed to create database " & $sDbFile & ": " & _SQLite_ErrMsg(), True)
            _SQLite_Shutdown()
            MsgBox($MB_ICONERROR, "Error", "Unable to create models database.")
            Return SetError(2, 0, False)
        EndIf
        _Log("Created new database: " & $sDbFile)

        Local $sQuery
        $sQuery = "CREATE TABLE Models (ModelID INTEGER PRIMARY KEY, Name TEXT, Path TEXT, Description TEXT, Comments TEXT, CommandLine TEXT);"
        _SQLite_Exec($hDb, $sQuery)
        If @error Then
            _Log("Failed to create Models table: " & _SQLite_ErrMsg(), True)
            _SQLite_Close($hDb)
            _SQLite_Shutdown()
            Return SetError(3, 0, False)
        EndIf
        _Log("Models table created")

        $sQuery = "CREATE TABLE ModelApps (ModelID INTEGER, App TEXT, FOREIGN KEY(ModelID) REFERENCES Models(ModelID));"
        _SQLite_Exec($hDb, $sQuery)
        If @error Then
            _Log("Failed to create ModelApps table: " & _SQLite_ErrMsg(), True)
            _SQLite_Close($hDb)
            _SQLite_Shutdown()
            Return SetError(4, 0, False)
        EndIf
        _Log("ModelApps table created")

        $sQuery = "CREATE TABLE ModelFocuses (ModelID INTEGER, Focus TEXT, Stems INTEGER, FOREIGN KEY(ModelID) REFERENCES Models(ModelID));"
        _SQLite_Exec($hDb, $sQuery)
        If @error Then
            _Log("Failed to create ModelFocuses table: " & _SQLite_ErrMsg(), True)
            _SQLite_Close($hDb)
            _SQLite_Shutdown()
            Return SetError(5, 0, False)
        EndIf
        _Log("ModelFocuses table created")

        Local $aSections = IniReadSectionNames($sModelsIni)
        If @error Or Not IsArray($aSections) Then
            _Log("Failed to read Models.ini or file is missing: " & $sModelsIni, True)
            Local $iModelID = 4
            Local $sName = "htdemucs"
            Local $sApp = "Demucs"
            Local $sFocus = "Vocals, Drums, Bass, Other"
            Local $iStems = 4
            Local $sPath = "N/A"
            Local $sDescription = "Demucs model for separating audio into vocals, drums, bass, and other."
            Local $sComments = "Good for 4-stem separation but may muffle or phase audio in some genres; test with VR models for comparison."
            Local $sCommandLine = 'cmd /c "cd @ScriptDir@\installs\Demucs\demucs_env\Scripts && activate.bat && python.exe -m demucs -o "@OutputDir@" "@SongPath@" && deactivate"'

            $sQuery = "INSERT INTO Models (ModelID, Name, Path, Description, Comments, CommandLine) VALUES (" & $iModelID & ", '" & $sName & "', '" & $sPath & "', '" & $sDescription & "', '" & $sComments & "', '" & $sCommandLine & "');"
            _SQLite_Exec($hDb, $sQuery)
            If @error Then
                _Log("Failed to insert default model into Models: " & _SQLite_ErrMsg(), True)
                _SQLite_Close($hDb)
                _SQLite_Shutdown()
                Return SetError(6, 0, False)
            EndIf
            _Log("Inserted default ModelID " & $iModelID & " into Models")

            $sQuery = "INSERT INTO ModelApps (ModelID, App) VALUES (" & $iModelID & ", '" & $sApp & "');"
            _SQLite_Exec($hDb, $sQuery)
            If @error Then
                _Log("Failed to insert into ModelApps for default model: " & _SQLite_ErrMsg(), True)
                _SQLite_Close($hDb)
                _SQLite_Shutdown()
                Return SetError(7, 0, False)
            EndIf
            _Log("Inserted default ModelID " & $iModelID & " into ModelApps")

            $sQuery = "INSERT INTO ModelFocuses (ModelID, Focus, Stems) VALUES (" & $iModelID & ", '" & $sFocus & "', " & $iStems & ");"
            _SQLite_Exec($hDb, $sQuery)
            If @error Then
                _Log("Failed to insert into ModelFocuses for default model: " & _SQLite_ErrMsg(), True)
                _SQLite_Close($hDb)
                _SQLite_Shutdown()
                Return SetError(8, 0, False)
            EndIf
            _Log("Inserted default ModelID " & $iModelID & " into ModelFocuses")

            ; Add Spleeter model (2stems) as a default
            $iModelID = 2
            $sName = "2stems"
            $sApp = "Spleeter"
            $sFocus = "Vocals, Instrumental"
            $iStems = 2
            $sPath = "N/A"
            $sDescription = "Basic Spleeter model for separating audio into vocals and instrumental."
            $sComments = "Older model, less effective than UVR; good for quick separation but may leave artifacts."
            $sCommandLine = 'cmd /c "cd @ScriptDir@\installs\Spleeter\spleeter_env\Scripts && activate.bat && python.exe -m spleeter separate -o "@OutputDir@" "@SongPath@" && deactivate"'

            $sQuery = "INSERT INTO Models (ModelID, Name, Path, Description, Comments, CommandLine) VALUES (" & $iModelID & ", '" & $sName & "', '" & $sPath & "', '" & $sDescription & "', '" & $sComments & "', '" & $sCommandLine & "');"
            _SQLite_Exec($hDb, $sQuery)
            If @error Then
                _Log("Failed to insert Spleeter model into Models: " & _SQLite_ErrMsg(), True)
                _SQLite_Close($hDb)
                _SQLite_Shutdown()
                Return SetError(9, 0, False)
            EndIf
            _Log("Inserted Spleeter ModelID " & $iModelID & " into Models")

            $sQuery = "INSERT INTO ModelApps (ModelID, App) VALUES (" & $iModelID & ", '" & $sApp & "');"
            _SQLite_Exec($hDb, $sQuery)
            If @error Then
                _Log("Failed to insert into ModelApps for Spleeter model: " & _SQLite_ErrMsg(), True)
                _SQLite_Close($hDb)
                _SQLite_Shutdown()
                Return SetError(10, 0, False)
            EndIf
            _Log("Inserted Spleeter ModelID " & $iModelID & " into ModelApps")

            $sQuery = "INSERT INTO ModelFocuses (ModelID, Focus, Stems) VALUES (" & $iModelID & ", '" & $sFocus & "', " & $iStems & ");"
            _SQLite_Exec($hDb, $sQuery)
            If @error Then
                _Log("Failed to insert into ModelFocuses for Spleeter model: " & _SQLite_ErrMsg(), True)
                _SQLite_Close($hDb)
                _SQLite_Shutdown()
                Return SetError(11, 0, False)
            EndIf
            _Log("Inserted Spleeter ModelID " & $iModelID & " into ModelFocuses")
        Else
            _Log("Found " & $aSections[0] & " sections in Models.ini")
            For $i = 1 To $aSections[0]
                Local $sSection = $aSections[$i]
                If Not StringRegExp($sSection, "^Model_\d+$") Then ContinueLoop

                Local $sModelID = StringReplace($sSection, "Model_", "")
                Local $sModelApp = IniRead($sModelsIni, $sSection, "App", "")
                Local $sModelName = IniRead($sModelsIni, $sSection, "Name", "")
                Local $sModelFocus = IniRead($sModelsIni, $sSection, "Focus", "")
                Local $iModelStems = IniRead($sModelsIni, $sSection, "Stems", 0)
                Local $sModelPath = IniRead($sModelsIni, $sSection, "Path", "")
                Local $sModelDesc = IniRead($sModelsIni, $sSection, "Description", "")
                Local $sModelComments = IniRead($sModelsIni, $sSection, "Comments", "")
                Local $sModelCmd = IniRead($sModelsIni, $sSection, "CommandLine", "")

                If $sModelName = "" And $sModelID = 2 Then
                    $sModelName = "2stems"
                    _Log("Inferred Name '2stems' for Model_2")
                EndIf

                If $sModelApp = "" Or $sModelName = "" Then
                    _Log("Skipping invalid model entry: " & $sSection, True)
                    ContinueLoop
                EndIf

                $sQuery = "INSERT INTO Models (ModelID, Name, Path, Description, Comments, CommandLine) VALUES (" & $sModelID & ",'" & $sModelName & "','" & $sModelPath & "','" & $sModelDesc & "','" & $sModelComments & "','" & $sModelCmd & "')"
                _SQLite_Exec($hDb, $sQuery)
                If @error Then
                    _Log("Failed to insert model " & $sModelName & ": " & _SQLite_ErrMsg(), True)
                    ContinueLoop
                EndIf

                $sQuery = "INSERT INTO ModelApps (ModelID, App) VALUES (" & $sModelID & ",'" & $sModelApp & "')"
                _SQLite_Exec($hDb, $sQuery)
                If @error Then
                    _Log("Failed to insert app for model " & $sModelName & ": " & _SQLite_ErrMsg(), True)
                    ContinueLoop
                EndIf

                $sQuery = "INSERT INTO ModelFocuses (ModelID, Focus, Stems) VALUES (" & $sModelID & ",'" & $sModelFocus & "'," & $iModelStems & ")"
                _SQLite_Exec($hDb, $sQuery)
                If @error Then
                    _Log("Failed to insert focus for model " & $sModelName & ": " & _SQLite_ErrMsg(), True)
                    ContinueLoop
                EndIf

                _Log("Added model " & $sModelName & " (App: " & $sModelApp & ") to database")
            Next
        EndIf
    Else
        $hDb = _SQLite_Open($sDbFile)
        If @error Then
            _Log("Failed to open database " & $sDbFile & ": " & _SQLite_ErrMsg(), True)
            _SQLite_Shutdown()
            MsgBox($MB_ICONERROR, "Error", "Unable to open models database.")
            Return SetError(12, 0, False)
        EndIf
        _Log("Opened existing database: " & $sDbFile)
    EndIf

    Local $aResult, $iRows, $iCols
    $sQuery = "SELECT COUNT(*) FROM Models"
    _Log("Executing query: " & $sQuery)
    Local $iRet = _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRet <> $SQLITE_OK Or $iRows = 0 Or Not IsArray($aResult) Or UBound($aResult, 1) < 2 Then
        _Log("No models found in database", True)
        MsgBox($MB_ICONERROR, "Error", "No models found in database.")
        _SQLite_Close($hDb)
        _SQLite_Shutdown()
        Return SetError(13, 0, False)
    EndIf
    _Log("Found " & $aResult[1][0] & " models in database")

    $sQuery = "SELECT Name FROM Models WHERE Name = 'htdemucs'"
    _Log("Executing query: " & $sQuery)
    $iRet = _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRet <> $SQLITE_OK Or $iRows = 0 Then
        _Log("Default model 'htdemucs' not found in database", True)
        MsgBox($MB_ICONWARNING, "Warning", "Default model 'htdemucs' not found.")
    Else
        _Log("Confirmed default model 'htdemucs' exists")
    EndIf

    $sQuery = "SELECT Name FROM Models WHERE Name = '2stems'"
    _Log("Executing query: " & $sQuery)
    $iRet = _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRet <> $SQLITE_OK Or $iRows = 0 Then
        _Log("Spleeter model '2stems' not found in database", True)
        MsgBox($MB_ICONWARNING, "Warning", "Spleeter model '2stems' not found.")
    Else
        _Log("Confirmed Spleeter model '2stems' exists")
    EndIf

    _Log("Exiting _InitializeModels")
    Return True
EndFunc

Func _UpdateModelDetails($sModel)
    _Log("Entering _UpdateModelDetails for model: " & $sModel)
    If $sModel = "" Then
        GUICtrlSetData($hStemsDisplay, "")
        GUICtrlSetData($hFocusDisplay, "")
        GUICtrlSetData($hDescEdit, "")
        GUICtrlSetData($hCommentsEdit, "")
        _Log("Cleared model details display")
    Else
        Local $aDetails = _GetModelDetails($sModel)
        If Not @error Then
            _Log("Setting Stems: " & $aDetails[3])
            GUICtrlSetData($hStemsDisplay, $aDetails[3])
            _Log("Setting Focus: " & $aDetails[1])
            GUICtrlSetData($hFocusDisplay, $aDetails[1])
            _Log("Setting Description: " & $aDetails[6])
            GUICtrlSetData($hDescEdit, $aDetails[6])
            _Log("Setting Comments: " & $aDetails[7])
            GUICtrlSetData($hCommentsEdit, $aDetails[7])
            _Log("Updated model details display for " & $sModel)
        Else
            _Log("Failed to update details for " & $sModel, True)
            GUICtrlSetData($hStemsDisplay, "Error")
            GUICtrlSetData($hFocusDisplay, "Error")
            GUICtrlSetData($hDescEdit, "Error retrieving model details")
            GUICtrlSetData($hCommentsEdit, "Error retrieving model details")
        EndIf
    EndIf
    _Log("Exiting _UpdateModelDetails")
EndFunc

Func _SaveModelDetails($sModel, $sDescription, $sComments)
    _Log("Entering _SaveModelDetails for model: " & $sModel)
    Local $sQuery = "UPDATE Models SET Description = '" & $sDescription & "', Comments = '" & $sComments & "' WHERE Name = '" & $sModel & "'"
    _Log("Executing query: " & $sQuery)
    Local $iRet = _SQLite_Exec($hDb, $sQuery)
    If $iRet <> $SQLITE_OK Then
        _Log("Failed to save details for model " & $sModel & ": " & _SQLite_ErrMsg(), True)
        Return False
    EndIf
    _Log("Saved description and comments for " & $sModel)
    Return True
EndFunc

Func _IsModelCompatibleWithTab($sModel, $iTabIndex)
    _Log("Entering _IsModelCompatibleWithTab: Model=" & $sModel & ", TabIndex=" & $iTabIndex)
    Local $aDetails = _GetModelDetails($sModel)
    If @error Then
        _Log("Failed to get model details for compatibility check", True)
        Return False
    EndIf
    Local $sApp = $aDetails[0]
    Local $bCompatible = False
    Switch $iTabIndex
        Case 0
            $bCompatible = ($sApp = "Demucs")
        Case 1
            $bCompatible = ($sApp = "Spleeter")
        Case 2
            $bCompatible = ($sApp = "UVR5")
    EndSwitch
    _Log("Model compatibility check: " & $sModel & " (App: " & $sApp & ") is " & ($bCompatible ? "" : "not ") & "compatible with tab " & $iTabIndex)
    Return $bCompatible
EndFunc
#EndRegion ;**** Model Management Functions ****
#EndRegion Part2




;**************************************************
;******************** Part 3 **********************
;**************************************************
#Region Part3
#Region ;**** Separation Functions ****

; Unified function to separate audio using Demucs, Spleeter, or UVR5
Func _SeparateAudio($sInputFile, $sModel, $sOutputDir)
    ; Log entry for debugging
    _Log("Entering _SeparateAudio: Input=" & $sInputFile & ", Model=" & $sModel & ", OutputDir=" & $sOutputDir)
    ConsoleWrite("Separating audio: " & $sInputFile & " with model " & $sModel & " to " & $sOutputDir & @CRLF)

    ; Validate input file
    If Not FileExists($sInputFile) Then
        _Log("Error: Input file does not exist: " & $sInputFile, True)
        Return False
    EndIf

    ; Get model details from database or ini
    Local $aModelDetails = _GetModelDetails($sModel)
    If @error Then
        _Log("Error: Failed to get model details for " & $sModel, True)
        Return False
    EndIf
    Local $sApp = $aModelDetails[0] ; Application (Demucs, Spleeter, UVR5)

    ; Define output directory using global $sOutputPath
    Local $sOutputDir = $sOutputPath & "\" & $sModel & "\" & _PathGetFileNameWithoutExtension($sInputFile)
    DirCreate($sOutputDir) ; Create output directory if it doesn't exist
    _Log("Output directory created: " & $sOutputDir)

    ; Construct and validate separation command
    Local $sCommand, $sExePath
    Local $sLogFile = @ScriptDir & "\logs\demucs_log.txt"
    Switch $sApp
        Case "Demucs"
            $sExePath = @ScriptDir & "\installs\demucs\Scripts\demucs.exe"
            If Not FileExists($sExePath) Then
                _Log("Error: Demucs executable not found: " & $sExePath, True)
                Return False
            EndIf
            $sCommand = '"' & $sExePath & '" -n "' & $sModel & '" --out "' & $sOutputDir & '" "' & $sInputFile & '"'
        Case "Spleeter"
            $sExePath = "spleeter" ; Adjust to actual path (e.g., @ScriptDir & "\installs\spleeter\spleeter.exe")
            $sCommand = $sExePath & ' separate -p "' & $sModel & '" -o "' & $sOutputDir & '" "' & $sInputFile & '"'
        Case "UVR5"
            $sExePath = "uvr" ; Adjust to actual path (e.g., @ScriptDir & "\installs\uvr\uvr.exe")
            $sCommand = $sExePath & ' separate --model "' & $sModel & '" --output "' & $sOutputDir & '" "' & $sInputFile & '"'
        Case Else
            _Log("Error: Unknown application: " & $sApp, True)
            Return False
    EndSwitch
    _Log("Running command: " & $sCommand)

    ; Run the separation process
    Local $iPID = Run($sCommand, "", @SW_HIDE, $STDERR_MERGED)
    If $iPID = 0 Then
        _Log("Error: Failed to start separation process. Command: " & $sCommand, True)
        Return False
    EndIf
    _Log("Separation process started with PID: " & $iPID)

    ; Monitor progress
    Local $iProgress = 0
    While ProcessExists($iPID)
        Local $sOutput = StdoutRead($iPID)
        If Not @error And $sOutput <> "" Then
            _Log("Process output: " & $sOutput)
            ; Parse progress (e.g., "Progress: 50/100")
            Local $aProgress = StringRegExp($sOutput, "Progress: (\d+)/100", 1)
            If Not @error Then
                $iProgress = Int($aProgress[0])
                _UpdateProgressBar($iProgress)
            EndIf
            FileWrite($sLogFile, $sOutput) ; Log process output
        EndIf
        Sleep(100)
    WEnd

    ; Check process exit code
    ProcessWaitClose($iPID)
    Local $iExitCode = @error
    If $iExitCode <> 0 Then
        _Log("Error: Separation process failed with exit code: " & $iExitCode, True)
        Return False
    EndIf

    ; Verify output files
    Local $aExpectedStems = _GetExpectedStems($sModel)
    If Not IsArray($aExpectedStems) Then
        _Log("Error: Failed to get expected stems for model " & $sModel, True)
        Return False
    EndIf
    For $sStem In $aExpectedStems
        If Not FileExists($sOutputDir & "\" & $sStem) Then
            _Log("Error: Expected stem not found: " & $sOutputDir & "\" & $sStem, True)
            Return False
        EndIf
    Next

    _Log("Separation completed successfully for " & $sInputFile)
    _ResetProgressBar()
    Return True
EndFunc

; Extract filename without path or extension
Func _PathGetFileNameWithoutExtension($sPath)
    Local $sFileName = StringRegExpReplace($sPath, "^.*\\", "") ; Remove path
    Return StringRegExpReplace($sFileName, "\.[^.]*$", "") ; Remove extension
EndFunc

; Process a single audio file and verify output
Func _ProcessFile($sSong, $sModel, $sOutputDir)
    _Log("Entering _ProcessFile: File=" & $sSong & ", Model=" & $sModel & ", OutputDir=" & $sOutputDir)

    ; Call the unified separation function
    Local $bSuccess = _SeparateAudio($sSong, $sModel, $sOutputDir)
    If Not $bSuccess Then
        _Log("Error: Processing failed for " & $sSong & " with model " & $sModel, True)
        Return False
    EndIf

    ; Verify output files
    Local $sDrive, $sDir, $sFileName, $sExtension
    _PathSplit($sSong, $sDrive, $sDir, $sFileName, $sExtension)
    Local $sBaseName = $sFileName
    Local $sOutputVocals = $sOutputDir & "\output\" & $sBaseName & "_vocals.wav"
    Local $sOutputInstrumental = $sOutputDir & "\output\" & $sBaseName & "_instrumental.wav"

    If FileExists($sOutputVocals) Then
        _Log("Vocals file created: " & $sOutputVocals)
    Else
        _Log("Error: Vocals file not found: " & $sOutputVocals, True)
    EndIf

    If FileExists($sOutputInstrumental) Then
        _Log("Instrumental file created: " & $sOutputInstrumental)
    Else
        _Log("Error: Instrumental file not found: " & $sOutputInstrumental, True)
    EndIf

    ; Return True only if expected files exist
    If FileExists($sOutputVocals) And FileExists($sOutputInstrumental) Then
        Return True
    Else
        _Log("Error: Processing incomplete: Not all expected output files were created", True)
        Return False
    EndIf
EndFunc

; Return expected stem filenames based on model
Func _GetExpectedStems($sModel)
    Local $aModelDetails = _GetModelDetails($sModel)
    If @error Then
        _Log("Error: Failed to get model details for expected stems", True)
        Return SetError(1, 0, 0)
    EndIf
    Local $iStems = $aModelDetails[3] ; Stems field from _GetModelDetails
    Local $aStems
    Switch $iStems
        Case 2
            $aStems = ["vocals.wav", "instrumental.wav"]
        Case 4
            $aStems = ["vocals.wav", "drums.wav", "bass.wav", "other.wav"]
        Case 6
            $aStems = ["vocals.wav", "drums.wav", "bass.wav", "piano.wav", "guitar.wav", "other.wav"]
        Case Else
            _Log("Error: Unsupported number of stems for model " & $sModel & ": " & $iStems, True)
            Return SetError(1, 0, 0)
    EndSwitch
    _Log("Expected stems for " & $sModel & ": " & _ArrayToString($aStems))
    Return $aStems
EndFunc

; Update GUI progress bar
Func _UpdateProgressBar($iProgress)
    Local $iWidth = ($iGuiWidth - 20) * $iProgress / 100
    _GDIPlus_GraphicsFillRect($hGraphics, 0, 0, $iWidth, 20, $hBrushGreen)
    _GDIPlus_GraphicsFillRect($hGraphics, $iWidth, 0, $iGuiWidth - 20 - $iWidth, 20, $hBrushGray)
    GUICtrlSetData($hProgressLabel, "Task Progress: " & $iProgress & "%")
EndFunc

#EndRegion ;**** Separation Functions ****
#EndRegion ;**** Part3 ****



#Region Part4
#Region ;**** Event Handlers ****
Func _InputDirButtonHandler()
    _Log("Entering _InputDirButtonHandler")
    Local $sNewDir = FileSelectFolder("Select Input Directory", "", 7, $sInputPath)
    If Not @error Then
        $sInputPath = $sNewDir
        _Log("Selected input directory: " & $sInputPath)
        _GUICtrlListView_DeleteAllItems($hInputListView)
        If FileExists($sInputPath) Then
            Local $aInputFiles = _FileListToArrayRec($sInputPath, "*.wav;*.mp3;*.flac", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)
            If Not @error Then
                _Log("Found " & $aInputFiles[0] & " audio files in " & $sInputPath)
                For $i = 1 To $aInputFiles[0]
                    Local $sDrive, $sDir, $sFileName, $sExtension
                    _PathSplit($aInputFiles[$i], $sDrive, $sDir, $sFileName, $sExtension)
                    Local $sDisplayName = $sFileName & $sExtension
                    _GUICtrlListView_AddItem($hInputListView, $sDisplayName)
                Next
            Else
                _Log("No audio files found in " & $sInputPath)
            EndIf
        Else
            _Log("Selected input path " & $sInputPath & " does not exist", True)
        EndIf
    Else
        _Log("Input directory selection cancelled")
    EndIf
    _Log("Exiting _InputDirButtonHandler")
EndFunc



Func _OutputDirButtonHandler()
    _Log("Entering _OutputDirButtonHandler")
    Local $sNewDir = FileSelectFolder("Select Output Directory", "", 7, $sOutputPath)
    If Not @error Then
        $sOutputPath = $sNewDir
        _Log("Selected output directory: " & $sOutputPath)
        _GUICtrlListView_DeleteAllItems($hOutputListView)
        If FileExists($sOutputPath) Then
            Local $aOutputFiles = _FileListToArrayRec($sOutputPath, "*.wav;*.mp3;*.flac", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)
            If Not @error Then
                _Log("Found " & $aOutputFiles[0] & " audio files in " & $sOutputPath)
                For $i = 1 To $aOutputFiles[0]
                    Local $sDrive, $sDir, $sFileName, $sExtension
                    _PathSplit($aOutputFiles[$i], $sDrive, $sDir, $sFileName, $sExtension)
                    Local $sDisplayName = $sFileName & $sExtension
                    _GUICtrlListView_AddItem($hOutputListView, $sDisplayName)
                Next
            Else
                _Log("No audio files found in " & $sOutputPath)
            EndIf
        Else
            _Log("Selected output path " & $sOutputPath & " does not exist", True)
        EndIf
    Else
        _Log("Output directory selection cancelled")
    EndIf
    _Log("Exiting _OutputDirButtonHandler")
EndFunc



Func _OutputButtonHandler()
    _Log("Entering _OutputButtonHandler")
    Local $sNewDir = FileSelectFolder("Select Output Directory", "", 7, $sOutputPath)
    If @error Then
        _Log("No output directory selected")
        Return
    EndIf
    $sOutputPath = $sNewDir
    _Log("Selected output directory: " & $sOutputPath)
    IniWrite($sSettingsIni, "Paths", "OutputDir", $sOutputPath)
    _GUICtrlListView_DeleteAllItems($hOutputListView)
    Local $aOutputFiles = _FileListToArrayRec($sOutputPath, "*.wav;*.mp3;*.flac", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)
    If Not @error Then
        _Log("Found " & $aOutputFiles[0] & " audio files in " & $sOutputPath)
        For $i = 1 To $aOutputFiles[0]
            _GUICtrlListView_AddItem($hOutputListView, $aOutputFiles[$i])
        Next
    Else
        _Log("No audio files found in " & $sOutputPath)
    EndIf
    _Log("Exiting _OutputButtonHandler")
EndFunc




Func _AddButtonHandler()
    _Log("Entering _AddButtonHandler")
    Local $iSelected = _GUICtrlListView_GetSelectedIndices($hInputListView, True)
    If $iSelected[0] = 0 Then
        _Log("No items selected in Input ListView")
        Return
    EndIf
    For $i = 1 To $iSelected[0]
        Local $sFile = _GUICtrlListView_GetItemText($hInputListView, $iSelected[$i])
        _Log("Adding file to Process Queue: " & $sFile)
        Local $iIndex = _GUICtrlListView_AddItem($hBatchList, $sFile) ; $sFile is already the file name
        _GUICtrlListView_SetItemChecked($hBatchList, $iIndex, True)
    Next
    _Log("Exiting _AddButtonHandler")
EndFunc



Func _ClearButtonHandler()
    _Log("Entering _ClearButtonHandler")
    _GUICtrlListView_DeleteAllItems($hBatchList)
    _Log("Cleared Process Queue")
    _Log("Exiting _ClearButtonHandler")
EndFunc




Func _DeleteButtonHandler()
    _Log("Entering _DeleteButtonHandler")
    Local $iSelected = _GUICtrlListView_GetSelectedIndices($hBatchList, True)
    If $iSelected[0] = 0 Then
        _Log("No items selected in Process Queue")
        Return
    EndIf
    For $i = $iSelected[0] To 1 Step -1
        _Log("Deleting item from Process Queue: " & _GUICtrlListView_GetItemText($hBatchList, $iSelected[$i]))
        _GUICtrlListView_DeleteItem($hBatchList, $iSelected[$i])
    Next
    _Log("Exiting _DeleteButtonHandler")
EndFunc




Func _SeparateButtonHandler()
    _Log("Entering _SeparateButtonHandler")
    Local $iItemCount = _GUICtrlListView_GetItemCount($hBatchList)
    If $iItemCount = 0 Then
        _Log("Process Queue is empty")
        MsgBox($MB_ICONWARNING, "Warning", "Process Queue is empty.")
        Return
    EndIf

    Local $iCheckedCount = 0
    For $i = 0 To $iItemCount - 1
        If _GUICtrlListView_GetItemChecked($hBatchList, $i) Then $iCheckedCount += 1
    Next
    If $iCheckedCount = 0 Then
        _Log("No items checked in Process Queue")
        MsgBox($MB_ICONWARNING, "Warning", "No items are checked for processing.")
        Return
    EndIf

    Local $sModel = GUICtrlRead($hModelCombo)
    If $sModel = "" Or $sModel = "No models available" Then
        _Log("No model selected for processing", True)
        MsgBox($MB_ICONERROR, "Error", "Please select a valid model.")
        Return
    EndIf

    Local $iProcessed = 0
    GUICtrlSetData($hCountLabel, "Tasks Completed: 0/" & $iCheckedCount)
    For $i = 0 To $iItemCount - 1
        If Not _GUICtrlListView_GetItemChecked($hBatchList, $i) Then ContinueLoop
        Local $sSong = _GUICtrlListView_GetItemText($hBatchList, $i)
        _Log("Processing song: " & $sSong)
        GUICtrlSetData($hProgressLabel, "Task Progress: 0%")
        _GDIPlus_GraphicsFillRect($hGraphics, 0, 0, $iGuiWidth - 20, 20, $hBrushGray)
        Local $bSuccess = _ProcessFile($sSong, $sModel, $sOutputPath)
        If $bSuccess Then
            $iProcessed += 1
            GUICtrlSetData($hProgressLabel, "Task Progress: 100%")
            _GDIPlus_GraphicsFillRect($hGraphics, 0, 0, $iGuiWidth - 20, 20, $hBrushGreen)
            GUICtrlSetData($hCountLabel, "Tasks Completed: " & $iProcessed & "/" & $iCheckedCount)
        Else
            GUICtrlSetData($hProgressLabel, "Task Progress: Failed")
            _GDIPlus_GraphicsFillRect($hGraphics, 0, 0, $iGuiWidth - 20, 20, $hBrushYellow)
        EndIf
    Next
    _Log("Processing complete: " & $iProcessed & "/" & $iCheckedCount & " tasks successful")
    MsgBox($MB_ICONINFORMATION, "Complete", "Processing complete: " & $iProcessed & "/" & $iCheckedCount & " tasks successful.")
    _Log("Exiting _SeparateButtonHandler")
EndFunc




Func _SaveSettingsButtonHandler()
    _Log("Entering _SaveSettingsButtonHandler")
    Local $sModel = GUICtrlRead($hModelCombo)
    If $sModel = "" Or $sModel = "No models available" Then
        _Log("No model selected to save settings", True)
        MsgBox($MB_ICONWARNING, "Warning", "No model selected to save settings.")
        Return
    EndIf
    Local $sDescription = GUICtrlRead($hDescEdit)
    Local $sComments = GUICtrlRead($hCommentsEdit)
    If _SaveModelDetails($sModel, $sDescription, $sComments) Then
        MsgBox($MB_ICONINFORMATION, "Success", "Settings saved for model: " & $sModel)
    Else
        MsgBox($MB_ICONERROR, "Error", "Failed to save settings for model: " & $sModel)
    EndIf
    IniWrite($sSettingsIni, "GUI", "LastModel", $sModel)
    Local $iItemCount = _GUICtrlListView_GetItemCount($hBatchList)
    If $iItemCount > 0 Then
        Local $sLastSong = _GUICtrlListView_GetItemText($hBatchList, 0)
        IniWrite($sSettingsIni, "GUI", "LastSong", $sLastSong)
    EndIf
    _Log("Exiting _SaveSettingsButtonHandler")
EndFunc




Func _ModelComboHandler()
    _Log("Entering _ModelComboHandler")
    Local $sModel = GUICtrlRead($hModelCombo)
    If $sModel = "" Or $sModel = "No models available" Then
        _Log("Invalid model selected in combo box", True)
        _UpdateModelDetails("")
        Return
    EndIf
    _Log("Model selected: " & $sModel)
    _UpdateModelDetails($sModel)
    _Log("Exiting _ModelComboHandler")
EndFunc




Func _TabHandler()
    _Log("Entering _TabHandler")
    Local $iTabIndex = _GUICtrlTab_GetCurSel($hTab)
    _Log("Tab switched to index: " & $iTabIndex)

    ; Delete existing controls to avoid overlap
    If $hModelCombo <> 0 Then
        GUICtrlDelete($hModelNameLabel)
        GUICtrlDelete($hModelCombo)
        GUICtrlDelete($hStemsLabel)
        GUICtrlDelete($hStemsDisplay)
        GUICtrlDelete($hFocusLabel)
        GUICtrlDelete($hFocusDisplay)
        GUICtrlDelete($hDescLabel)
        GUICtrlDelete($hDescEdit)
        GUICtrlDelete($hCommentsLabel)
        GUICtrlDelete($hCommentsEdit)

        If IsDeclared("hSegmentSizeLabel") And $hSegmentSizeLabel <> 0 Then GUICtrlDelete($hSegmentSizeLabel)
        If IsDeclared("hSegmentSizeInput") And $hSegmentSizeInput <> 0 Then GUICtrlDelete($hSegmentSizeInput)
        If IsDeclared("hOverlapLabel") And $hOverlapLabel <> 0 Then GUICtrlDelete($hOverlapLabel)
        If IsDeclared("hOverlapInput") And $hOverlapInput <> 0 Then GUICtrlDelete($hOverlapInput)
        If IsDeclared("hDenoiseCheckbox") And $hDenoiseCheckbox <> 0 Then GUICtrlDelete($hDenoiseCheckbox)
        If IsDeclared("hBatchSizeLabel") And $hBatchSizeLabel <> 0 Then GUICtrlDelete($hBatchSizeLabel)
        If IsDeclared("hBatchSizeInput") And $hBatchSizeInput <> 0 Then GUICtrlDelete($hBatchSizeInput)
        GUICtrlDelete($hAggressivenessLabel)
        GUICtrlDelete($hAggressivenessInput)
        GUICtrlDelete($hTTACheckbox)
        GUICtrlDelete($hHighEndProcessLabel)
        GUICtrlDelete($hHighEndProcessCombo)
    EndIf

    ; Recreate controls based on the selected tab
    Local $iRightQuadX = ($iGuiWidth - 30) / 2 + 20
    Local $iTopQuadY = 35
    Local $iTabTopY = $iTopQuadY + 50
    Local $iQuadWidth = ($iGuiWidth - 30) / 2
    Local $iDetailsX = $iRightQuadX + 5
    Local $iDetailsY = $iTabTopY + 20
    Local $iDetailsWidth = $iQuadWidth - 10
    Local $iLabelHeight = 20
    Local $iLabelSpacing = 25

    $hModelNameLabel = GUICtrlCreateLabel("Model Name:", $iDetailsX, $iTabTopY, 70, 20)
    $hModelCombo = GUICtrlCreateCombo("", $iDetailsX + 80, $iTabTopY, 150, 25, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL, $WS_VSCROLL))
    $hStemsLabel = GUICtrlCreateLabel("Stems:", $iDetailsX + 235, $iTabTopY, 40, 20)
    $hStemsDisplay = GUICtrlCreateLabel("", $iDetailsX + 275, $iTabTopY, 50, 20)
    $hFocusLabel = GUICtrlCreateLabel("Focus:", $iDetailsX, $iDetailsY, 80, $iLabelHeight)
    $hFocusDisplay = GUICtrlCreateLabel("", $iDetailsX + 80, $iDetailsY, $iDetailsWidth - 80, $iLabelHeight + 10)
    $hDescLabel = GUICtrlCreateLabel("Description:", $iDetailsX, $iDetailsY + $iLabelSpacing, 80, $iLabelHeight)
    $hDescEdit = GUICtrlCreateLabel("", $iDetailsX + 80, $iDetailsY + $iLabelSpacing, $iDetailsWidth - 80, 40)
    $hCommentsLabel = GUICtrlCreateLabel("Comments:", $iDetailsX, $iDetailsY + $iLabelSpacing + 50, 80, $iLabelHeight)
    $hCommentsEdit = GUICtrlCreateLabel("", $iDetailsX + 80, $iDetailsY + $iLabelSpacing + 50, $iDetailsWidth - 80, 60)

    ; Add MDX-Net parameter controls for UVR5 tab
    If $iTabIndex = 2 Then
        $hSegmentSizeLabel = GUICtrlCreateLabel("Segment Size:", $iDetailsX, $iDetailsY + $iLabelSpacing * 3 + 110, 80, $iLabelHeight)
        Local $sSegmentSize = IniRead($sSettingsIni, "MDXNet", "SegmentSize", "256")
        $hSegmentSizeInput = GUICtrlCreateInput($sSegmentSize, $iDetailsX + 80, $iDetailsY + $iLabelSpacing * 3 + 110, 60, $iLabelHeight)
        _Log("Set Segment Size to: " & $sSegmentSize)

        $hOverlapLabel = GUICtrlCreateLabel("Overlap:", $iDetailsX, $iDetailsY + $iLabelSpacing * 3 + 135, 80, $iLabelHeight)
        Local $sOverlap = IniRead($sSettingsIni, "MDXNet", "Overlap", "0.25")
        $hOverlapInput = GUICtrlCreateInput($sOverlap, $iDetailsX + 80, $iDetailsY + $iLabelSpacing * 3 + 135, 60, $iLabelHeight)
        _Log("Set Overlap to: " & $sOverlap)

        $hDenoiseCheckbox = GUICtrlCreateCheckbox("Denoise", $iDetailsX, $iDetailsY + $iLabelSpacing * 3 + 160, 80, $iLabelHeight)
        Local $sDenoise = IniRead($sSettingsIni, "MDXNet", "Denoise", "false")
        If $sDenoise = "true" Then GUICtrlSetState($hDenoiseCheckbox, $GUI_CHECKED)
        _Log("Set Denoise to: " & $sDenoise)

        $hBatchSizeLabel = GUICtrlCreateLabel("Batch Size:", $iDetailsX, $iDetailsY + $iLabelSpacing * 3 + 185, 80, $iLabelHeight)
        Local $sBatchSize = IniRead($sSettingsIni, "MDXNet", "BatchSize", "1")
        $hBatchSizeInput = GUICtrlCreateInput($sBatchSize, $iDetailsX + 80, $iDetailsY + $iLabelSpacing * 3 + 185, 60, $iLabelHeight)
        _Log("Set Batch Size to: " & $sBatchSize)

        $hAggressivenessLabel = GUICtrlCreateLabel("Aggressiveness:", $iDetailsX, $iDetailsY + $iLabelSpacing * 3 + 210, 80, $iLabelHeight)
        Local $sAggressiveness = IniRead($sSettingsIni, "MDXNet", "Aggressiveness", "10")
        $hAggressivenessInput = GUICtrlCreateInput($sAggressiveness, $iDetailsX + 80, $iDetailsY + $iLabelSpacing * 3 + 210, 60, $iLabelHeight)
        _Log("Set Aggressiveness to: " & $sAggressiveness)

        $hTTACheckbox = GUICtrlCreateCheckbox("TTA", $iDetailsX, $iDetailsY + $iLabelSpacing * 3 + 235, 80, $iLabelHeight)
        Local $sTTA = IniRead($sSettingsIni, "MDXNet", "TTA", "false")
        If $sTTA = "true" Then GUICtrlSetState($hTTACheckbox, $GUI_CHECKED)
        _Log("Set TTA to: " & $sTTA)

        $hHighEndProcessLabel = GUICtrlCreateLabel("High End Process:", $iDetailsX, $iDetailsY + $iLabelSpacing * 3 + 260, 80, $iLabelHeight)
        Local $sHighEndProcess = IniRead($sSettingsIni, "MDXNet", "HighEndProcess", "mirroring")
        $hHighEndProcessCombo = GUICtrlCreateCombo("", $iDetailsX + 80, $iDetailsY + $iLabelSpacing * 3 + 260, 100, $iLabelHeight, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
        GUICtrlSetData($hHighEndProcessCombo, "none|mirroring|mirroring2", $sHighEndProcess)
        _Log("Set High End Process to: " & $sHighEndProcess)
    EndIf

    ; Set event handlers for the new controls
    GUICtrlSetOnEvent($hModelCombo, "_ModelComboHandler")
    If $iTabIndex = 2 Then
        GUICtrlSetOnEvent($hSegmentSizeInput, "_MDXSettingsHandler")
        GUICtrlSetOnEvent($hOverlapInput, "_MDXSettingsHandler")
        GUICtrlSetOnEvent($hDenoiseCheckbox, "_MDXSettingsHandler")
        GUICtrlSetOnEvent($hBatchSizeInput, "_MDXSettingsHandler")
        GUICtrlSetOnEvent($hAggressivenessInput, "_MDXSettingsHandler")
        GUICtrlSetOnEvent($hTTACheckbox, "_MDXSettingsHandler")
        GUICtrlSetOnEvent($hHighEndProcessCombo, "_MDXSettingsHandler")
    EndIf

    ; Populate the combo box
    _UpdateModelDroplist()

    ; Set the default model for the current tab
    Local $sDefaultModel
    Local $sSelectedModel
    Switch $iTabIndex
        Case 0
            $sDefaultModel = "htdemucs"
        Case 1
            $sDefaultModel = "2stems"
        Case 2
            $sDefaultModel = "UVR-MDX-NET-Inst_Main"
    EndSwitch

    If $sDefaultModel <> "" Then
        If _IsModelCompatibleWithTab($sDefaultModel, $iTabIndex) Then
            _Log("Setting default model for tab " & $iTabIndex & ": " & $sDefaultModel)
            GUICtrlSetData($hModelCombo, $sDefaultModel, $sDefaultModel)
            $sSelectedModel = GUICtrlRead($hModelCombo)
            If $sSelectedModel = $sDefaultModel Then
                _Log("Default model " & $sDefaultModel & " set successfully")
                _UpdateModelDetails($sDefaultModel)
                GUICtrlSetState($hModelCombo, $GUI_FOCUS)
                Sleep(50)
            Else
                _Log("Failed to set default model " & $sDefaultModel & ", current selection: " & $sSelectedModel, True)
                _UpdateModelDetails("")
            EndIf
        Else
            _Log("Default model " & $sDefaultModel & " not found or not compatible with tab " & $iTabIndex & ", selecting first available", True)
            Local $sFirstModel = StringSplit(GUICtrlRead($hModelCombo), "|")[2]
            If $sFirstModel <> "" And $sFirstModel <> "No models available" Then
                _Log("Falling back to first available model: " & $sFirstModel)
                GUICtrlSetData($hModelCombo, $sFirstModel, $sFirstModel)
                $sSelectedModel = GUICtrlRead($hModelCombo)
                If $sSelectedModel = $sFirstModel Then
                    _UpdateModelDetails($sFirstModel)
                    GUICtrlSetState($hModelCombo, $GUI_FOCUS)
                    Sleep(50)
                Else
                    _Log("Failed to set first available model " & $sFirstModel & ", current selection: " & $sSelectedModel, True)
                    _UpdateModelDetails("")
                EndIf
            Else
                _Log("No models available for tab " & $iTabIndex, True)
                _UpdateModelDetails("")
            EndIf
        EndIf
    Else
        _Log("No default model defined for tab " & $iTabIndex, True)
        _UpdateModelDetails("")
    EndIf

    GUICtrlSetState($hStemsDisplay, $GUI_FOCUS)
    GUICtrlSetState($hFocusDisplay, $GUI_FOCUS)
    Sleep(50)

    _Log("Exiting _TabHandler")
EndFunc



Func _MDXSettingsHandler()
    _Log("Entering _MDXSettingsHandler")
    Local $sSegmentSize = GUICtrlRead($hSegmentSizeInput)
    Local $sOverlap = GUICtrlRead($hOverlapInput)
    Local $bDenoise = GUICtrlRead($hDenoiseCheckbox) = $GUI_CHECKED ? "true" : "false"
    Local $sBatchSize = GUICtrlRead($hBatchSizeInput)
    Local $sAggressiveness = GUICtrlRead($hAggressivenessInput)
    Local $bTTA = GUICtrlRead($hTTACheckbox) = $GUI_CHECKED ? "true" : "false"
    Local $sHighEndProcess = GUICtrlRead($hHighEndProcessCombo)

    ; Validate inputs
    If Not StringIsInt($sSegmentSize) Or $sSegmentSize <= 0 Then
        _Log("Invalid Segment Size: " & $sSegmentSize, True)
        MsgBox($MB_ICONWARNING, "Warning", "Segment Size must be a positive integer.")
        Return
    EndIf
    If Not StringIsFloat($sOverlap) And Not StringIsInt($sOverlap) Or $sOverlap < 0 Or $sOverlap > 1 Then
        _Log("Invalid Overlap: " & $sOverlap, True)
        MsgBox($MB_ICONWARNING, "Warning", "Overlap must be a number between 0 and 1.")
        Return
    EndIf
    If Not StringIsInt($sBatchSize) Or $sBatchSize <= 0 Then
        _Log("Invalid Batch Size: " & $sBatchSize, True)
        MsgBox($MB_ICONWARNING, "Warning", "Batch Size must be a positive integer.")
        Return
    EndIf
    If Not StringIsInt($sAggressiveness) Or $sAggressiveness < 0 Or $sAggressiveness > 100 Then
        _Log("Invalid Aggressiveness: " & $sAggressiveness, True)
        MsgBox($MB_ICONWARNING, "Warning", "Aggressiveness must be between 0 and 100.")
        Return
    EndIf
    If Not ($sHighEndProcess = "none" Or $sHighEndProcess = "mirroring" Or $sHighEndProcess = "mirroring2") Then
        _Log("Invalid High End Process: " & $sHighEndProcess, True)
        MsgBox($MB_ICONWARNING, "Warning", "High End Process must be 'none', 'mirroring', or 'mirroring2'.")
        Return
    EndIf

    ; Save to INI file
    IniWrite($sSettingsIni, "MDXNet", "SegmentSize", $sSegmentSize)
    IniWrite($sSettingsIni, "MDXNet", "Overlap", $sOverlap)
    IniWrite($sSettingsIni, "MDXNet", "Denoise", $bDenoise)
    IniWrite($sSettingsIni, "MDXNet", "BatchSize", $sBatchSize)
    IniWrite($sSettingsIni, "MDXNet", "Aggressiveness", $sAggressiveness)
    IniWrite($sSettingsIni, "MDXNet", "TTA", $bTTA)
    IniWrite($sSettingsIni, "MDXNet", "HighEndProcess", $sHighEndProcess)
    _Log("Saved MDX-Net settings: SegmentSize=" & $sSegmentSize & ", Overlap=" & $sOverlap & ", Denoise=" & $bDenoise & ", BatchSize=" & $sBatchSize & ", Aggressiveness=" & $sAggressiveness & ", TTA=" & $bTTA & ", HighEndProcess=" & $sHighEndProcess)
    _Log("Exiting _MDXSettingsHandler")
EndFunc




Func _DescEditHandler()
    _Log("Entering _DescEditHandler")
    ; Placeholder for description edit handling if needed
    _Log("Exiting _DescEditHandler")
EndFunc




Func _CommentsEditHandler()
    _Log("Entering _CommentsEditHandler")
    ; Placeholder for comments edit handling if needed
    _Log("Exiting _CommentsEditHandler")
EndFunc




Func _Exit()
    _Log("Entering _Exit")

    ; Terminate any running separation processes
    If $iPID <> 0 Then
        If ProcessExists($iPID) Then
            _Log("Terminating running process with PID: " & $iPID)
            ProcessClose($iPID)
            ProcessWaitClose($iPID, 5)
            If ProcessExists($iPID) Then
                _Log("Warning: Process " & $iPID & " did not terminate cleanly")
            EndIf
        EndIf
        $iPID = 0
    EndIf

    ; Close the progress bar GUI
    If IsDeclared("hGraphicGUI") Then
        _Log("Closing progress bar GUI")
        GUISetState(@SW_HIDE, $hGraphicGUI)
        GUIDelete($hGraphicGUI)
    EndIf

    ; Close the main GUI
    If IsDeclared("hGUI") Then
        _Log("Closing main GUI")
        GUISetState(@SW_HIDE, $hGUI)
        GUIDelete($hGUI)
    EndIf

    ; Clean up GDIPlus resources
    If IsDeclared("hBrushGray") And $hBrushGray <> 0 Then
        _Log("Disposing hBrushGray")
        _GDIPlus_BrushDispose($hBrushGray)
    EndIf
    If IsDeclared("hBrushGreen") And $hBrushGreen <> 0 Then
        _Log("Disposing hBrushGreen")
        _GDIPlus_BrushDispose($hBrushGreen)
    EndIf
    If IsDeclared("hBrushYellow") And $hBrushYellow <> 0 Then
        _Log("Disposing hBrushYellow")
        _GDIPlus_BrushDispose($hBrushYellow)
    EndIf
    If IsDeclared("hPen") And $hPen <> 0 Then
        _Log("Disposing hPen")
        _GDIPlus_PenDispose($hPen)
    EndIf
    If IsDeclared("hGraphics") And $hGraphics <> 0 Then
        _Log("Disposing hGraphics")
        _GDIPlus_GraphicsDispose($hGraphics)
    EndIf
    If IsDeclared("hGraphicGUI") And IsDeclared("hDC") Then
        _Log("Releasing DC")
        _WinAPI_ReleaseDC($hGraphicGUI, $hDC)
    EndIf
    _Log("Shutting down GDIPlus")
    _GDIPlus_Shutdown()

    ; Clean up SQLite resources
    If IsDeclared("hDb") Then
        _Log("Closing SQLite database")
        _SQLite_Close($hDb)
    EndIf
    _Log("Shutting down SQLite")
    _SQLite_Shutdown()

    ; Close the log file
    If $hLogFile <> 0 Then
        _Log("Closing log file")
        FileClose($hLogFile)
        $hLogFile = 0
    EndIf

    _Log("Exiting application")
    Exit
EndFunc

#EndRegion ;**** Event Handlers ****
#EndRegion Part4





