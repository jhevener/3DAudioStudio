;**************************************************
;********************Part 1************************
;**************************************************
#Region Part1
#Region ;**** Critical Features ****
; - Database reconstruction from models.ini per _CreateDatabase (Model Database Browser)
;   - Creates models.db if missing, populates Models, ModelApps, ModelFocuses, ModelParameters, SavedSettings
;   - Supports Model_1 section names with ModelID extraction, and model-named sections (e.g., TestModel)
;   - Adds default UVR5 model if models.ini is missing
; - UVR5 support with ModelParameters table (SegmentSize, Overlap, Denoise, Aggressiveness, TTA)
; - Robust logging to C:\temp\s2S\logs\StemSeparator_*.log.txt
#EndRegion ;**** Critical Features ****

#Region ;**** Directives and Includes ****
#AutoIt3Wrapper_Res_Description=AudioWizardSeparator
#AutoIt3Wrapper_Res_Fileversion=1.0.2.3
#AutoIt3Wrapper_Res_ProductName=Stem Separator
#AutoIt3Wrapper_Res_ProductVersion=1.0.2
#AutoIt3Wrapper_Res_CompanyName=FretzCapo
#AutoIt3Wrapper_Res_LegalCopyright=© 2025 FretzCapo
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=None
#AutoIt3Wrapper_Run_AU3Check=Y
#AutoIt3Wrapper_AU3Check_Parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6 -w 7

#include <Array.au3>
#include <Constants.au3>
#include <File.au3>
#include <GDIPlus.au3>
#include <GuiListView.au3>
#include <GuiTab.au3>
#include <SQLite.au3>
#include <StringConstants.au3>
#include <WindowsConstants.au3>
#include <GUIConstantsEx.au3>
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <ComboConstants.au3>
#include <ListViewConstants.au3>
#include <TabConstants.au3>
#include <WinAPI.au3>
#include <WinAPIFiles.au3>
#include <WinAPISys.au3>
#include <Date.au3>

Opt("GUIOnEventMode", 1)
#EndRegion ;**** Directives and Includes ****

#Region ;**** Global Variables and Constants ****
Global Const $GOOGLE_GREEN = 0xFF34C759
Global Const $GOOGLE_YELLOW = 0xFFF4B400
Global Const $GOOGLE_BLUE = 0xFF4285F4
Global Const $GOOGLE_RED = 0xFFDB4437
Global Const $GOOGLE_PURPLE = 0xFF673AB7
Global Const $GOOGLE_ORANGE = 0xFFF57C00
Global Const $GOOGLE_BROWN = 0xFF795548
Global Const $GOOGLE_TEAL = 0xFF26A69A

Global $hGUI, $hInputListView, $hOutputListView, $hBatchList, $hModelCombo, $hTab
Global $hInputDirButton, $hOutputDirButton, $hAddButton, $hClearButton, $hDeleteButton, $hSeparateButton, $hSaveSettingsButton
Global $hModelNameLabel, $hStemsLabel, $hStemsDisplay, $hFocusLabel, $hFocusDisplay
Global $hDescLabel, $hDescEdit, $hCommentsLabel, $hCommentsEdit
Global $hProgressLabel, $hCountLabel, $hGraphic
Global $hGraphicGUI, $hDC, $hGraphics, $hBrushGray, $hBrushGreen, $hBrushYellow, $hPen
Global $hAppCombo, $hSettingsCombo
Global $iGuiWidth, $iGuiHeight
Global $hDb, $sDbFile
Global $sSettingsIni = @ScriptDir & "\settings.ini"
Global $sModelsIni = @ScriptDir & "\Models.ini"
Global $sUserIni = @ScriptDir & "\user.ini"
Global $sLogFile
Global $sInputPath = @ScriptDir & "\songs"
Global $sOutputPath = @ScriptDir & "\stems"
Global $aInputFiles[1] = [0], $aOutputFiles[1] = [0]
Global $bProcessing = False
Global $hAggressivenessLabel, $hAggressivenessInput, $hTTACheckbox, $hHighEndProcessLabel, $hHighEndProcessCombo
Global $hSegmentSizeLabel = 0, $hSegmentSizeCombo = 0, $hOverlapLabel = 0, $hOverlapInput = 0
Global $hDenoiseCheckbox = 0, $hBatchSizeLabel = 0, $hBatchSizeInput = 0
Global $sSelectedModel = ""
$iGuiWidth = Int(IniRead($sSettingsIni, "GUI", "Width", 800))
$iGuiHeight = Int(IniRead($sSettingsIni, "GUI", "Height", 600))
$sDbFile = IniRead($sSettingsIni, "Paths", "DbFile", @ScriptDir & "\models.db")
$sLogFile = IniRead($sSettingsIni, "Paths", "LogDir", @ScriptDir & "\logs") & "\StemSeparator_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & ".log.txt"
If Not FileExists(IniRead($sSettingsIni, "Paths", "LogDir", @ScriptDir & "\logs")) Then DirCreate(IniRead($sSettingsIni, "Paths", "LogDir", @ScriptDir & "\logs"))
#EndRegion ;**** Global Variables and Constants ****

#Region ;**** Helper Functions ****
Func _GetPythonVersion($sPythonPath)
    Local $sCmd = '"' & $sPythonPath & '" --version'
    Local $iPID = Run($sCmd, "", @SW_HIDE, $STDOUT_CHILD)
    Local $sOutput = ""
    While ProcessExists($iPID)
        $sOutput &= StdoutRead($iPID)
        Sleep(10)
    WEnd
    ProcessWaitClose($iPID)
    Return StringStripWS($sOutput, 3)
EndFunc

Func _GetModelPath($sModel)
    Local $sIniFile = @ScriptDir & "\models.ini"
    Local $sPath = IniRead($sIniFile, $sModel, "Path", "")
    If $sPath = "" Then
        _Log("No path found for model " & $sModel & " in models.ini", True)
        Return ""
    EndIf
    $sPath = StringReplace($sPath, "@ScriptDir", @ScriptDir)
    $sPath = StringReplace($sPath, "\\", "\")
    Return $sPath
EndFunc
#EndRegion ;**** Helper Functions ****

#Region ;**** Logging Functions ****
Func _Log($sMessage, $bError = False)
    Local $sTimestamp = "[" & _Now() & "] " & ($bError ? "ERROR" : "INFO") & ": "
    Local $hFile = FileOpen($sLogFile, 1)
    If $hFile = -1 Then
        ConsoleWrite("Error: Unable to open log file: " & $sLogFile & @CRLF)
        Return
    EndIf
    FileWrite($hFile, $sTimestamp & $sMessage & @CRLF)
    FileClose($hFile)
EndFunc

Func _LogStartupInfo()
    _Log("Entering _LogStartupInfo")
    _Log("Script started")
    _Log("Script Directory: " & @ScriptDir)
    _Log("Working Directory: " & @WorkingDir)
    _Log("OS: " & @OSVersion & " (" & @OSArch & ")")
    _Log("User: " & @UserName)
    _Log("FFmpeg Path: " & IniRead($sSettingsIni, "Paths", "FFmpegPath", "C:\temp\s2S\installs\uvr\ffmpeg\bin\ffmpeg.exe"))
    _Log("Models Database File: " & $sDbFile)
    _Log("Settings INI: " & $sSettingsIni)
    _Log("Models INI: " & $sModelsIni)
    _Log("User INI: " & $sUserIni)
    _Log("Exiting _LogStartupInfo")
EndFunc
#EndRegion ;**** Logging Functions ****

#Region ;**** Initialization Functions ****
Func _InitializeModels()
    _Log("Entering _InitializeModels")
    _SQLite_Startup()
    If @error Then
        _Log("Failed to start SQLite: Error " & @error, True)
        Return False
    EndIf
    Local $bCreateDb = Not FileExists($sDbFile)
    If $bCreateDb Then
        _Log("Database file not found, creating: " & $sDbFile)
        $hDb = _SQLite_Open($sDbFile)
        If $hDb = 0 Then
            _Log("Failed to create database: " & _SQLite_ErrMsg(), True)
            _SQLite_Shutdown()
            Return False
        EndIf
        Local $sQuery = "CREATE TABLE IF NOT EXISTS Models (ModelID INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT, Path TEXT, CommandLine TEXT, Description TEXT, Comments TEXT);" & _
                        "CREATE TABLE IF NOT EXISTS ModelApps (ModelID INTEGER, App TEXT, FOREIGN KEY(ModelID) REFERENCES Models(ModelID));" & _
                        "CREATE TABLE IF NOT EXISTS ModelFocuses (ModelID INTEGER, Focus TEXT, Stems TEXT, FOREIGN KEY(ModelID) REFERENCES Models(ModelID));" & _
                        "CREATE TABLE IF NOT EXISTS ModelParameters (ModelName TEXT PRIMARY KEY, SegmentSize TEXT, Overlap TEXT, Denoise TEXT, Aggressiveness TEXT, TTA TEXT);" & _
                        "CREATE TABLE IF NOT EXISTS SavedSettings (Name TEXT PRIMARY KEY, ModelName TEXT, App TEXT);"
        If _SQLite_Exec($hDb, $sQuery) <> $SQLITE_OK Then
            _Log("Failed to create tables: " & _SQLite_ErrMsg(), True)
            _SQLite_Close($hDb)
            _SQLite_Shutdown()
            Return False
        EndIf
        _Log("Database tables created")
        Local $aSections = IniReadSectionNames($sModelsIni)
        If @error Or $aSections[0] = 0 Then
            _Log("Models INI not found or empty, creating default model", True)
            $sQuery = "INSERT INTO Models (Name, Path, CommandLine, Description, Comments) VALUES ('DefaultUVR5', '@ScriptDir\\models\\default.pth', '--vocals', 'Default UVR5 model', 'Auto-generated');"
            If _SQLite_Exec($hDb, $sQuery) <> $SQLITE_OK Then
                _Log("Failed to insert default model: " & _SQLite_ErrMsg(), True)
                _SQLite_Close($hDb)
                _SQLite_Shutdown()
                Return False
            EndIf
            Local $iModelID = _SQLite_LastInsertRowID($hDb)
            $sQuery = "INSERT INTO ModelApps (ModelID, App) VALUES (" & $iModelID & ", 'UVR5');" & _
                      "INSERT INTO ModelFocuses (ModelID, Focus, Stems) VALUES (" & $iModelID & ", 'Vocals', 'Vocals,Instrumental');" & _
                      "INSERT INTO ModelParameters (ModelName, SegmentSize, Overlap, Denoise, Aggressiveness, TTA) VALUES ('DefaultUVR5', '512', '0.0', 'False', '10', 'False');"
            If _SQLite_Exec($hDb, $sQuery) <> $SQLITE_OK Then
                _Log("Failed to insert default model data: " & _SQLite_ErrMsg(), True)
                _SQLite_Close($hDb)
                _SQLite_Shutdown()
                Return False
            EndIf
            _Log("Default UVR5 model created")
        Else
            For $i = 1 To $aSections[0]
                Local $sSection = $aSections[$i]
                Local $iModelID = 0
                If StringLeft($sSection, 6) = "Model_" Then
                    $iModelID = StringReplace($sSection, "Model_", "")
                    If Not StringIsInt($iModelID) Then $iModelID = 0
                EndIf
                Local $sName = IniRead($sModelsIni, $sSection, "Name", $sSection)
                Local $sPath = IniRead($sModelsIni, $sSection, "Path", "@ScriptDir\\models\\" & $sName & ".pth")
                Local $sCommandLine = IniRead($sModelsIni, $sSection, "CommandLine", "--vocals")
                Local $sDescription = IniRead($sModelsIni, $sSection, "Description", "")
                Local $sComments = IniRead($sModelsIni, $sSection, "Comments", "")
                Local $sApp = IniRead($sModelsIni, $sSection, "App", "UVR5")
                Local $sFocus = IniRead($sModelsIni, $sSection, "Focus", "Vocals")
                Local $sStems = IniRead($sModelsIni, $sSection, "Stems", "Vocals,Instrumental")
                Local $sSegmentSize = IniRead($sModelsIni, $sSection, "SegmentSize", "512")
                Local $sOverlap = IniRead($sModelsIni, $sSection, "Overlap", "0.0")
                Local $sDenoise = IniRead($sModelsIni, $sSection, "Denoise", "False")
                Local $sAggressiveness = IniRead($sModelsIni, $sSection, "Aggressiveness", "10")
                Local $sTTA = IniRead($sModelsIni, $sSection, "TTA", "False")
                $sName = StringReplace($sName, "'", "''")
                $sPath = StringReplace($sPath, "'", "''")
                $sCommandLine = StringReplace($sCommandLine, "'", "''")
                $sDescription = StringReplace($sDescription, "'", "''")
                $sComments = StringReplace($sComments, "'", "''")
                $sApp = StringReplace($sApp, "'", "''")
                $sFocus = StringReplace($sFocus, "'", "''")
                $sStems = StringReplace($sStems, "'", "''")
                $sSegmentSize = StringReplace($sSegmentSize, "'", "''")
                $sOverlap = StringReplace($sOverlap, "'", "''")
                $sDenoise = StringReplace($sDenoise, "'", "''")
                $sAggressiveness = StringReplace($sAggressiveness, "'", "''")
                $sTTA = StringReplace($sTTA, "'", "''")
                Local $sModelInsert = "INSERT INTO Models (Name, Path, CommandLine, Description, Comments"
                If $iModelID > 0 Then $sModelInsert &= ", ModelID"
                $sModelInsert &= ") VALUES ('" & $sName & "', '" & $sPath & "', '" & $sCommandLine & "', '" & $sDescription & "', '" & $sComments & "'"
                If $iModelID > 0 Then $sModelInsert &= ", " & $iModelID
                $sModelInsert &= ");"
                If _SQLite_Exec($hDb, $sModelInsert) <> $SQLITE_OK Then
                    _Log("Failed to insert model " & $sSection & ": " & _SQLite_ErrMsg(), True)
                    ContinueLoop
                EndIf
                Local $iInsertedModelID = _SQLite_LastInsertRowID($hDb)
                If $sApp <> "" Then
                    $sQuery = "INSERT INTO ModelApps (ModelID, App) VALUES (" & $iInsertedModelID & ", '" & $sApp & "');"
                    If _SQLite_Exec($hDb, $sQuery) <> $SQLITE_OK Then
                        _Log("Failed to insert ModelApps for " & $sSection & ": " & _SQLite_ErrMsg(), True)
                    EndIf
                EndIf
                If $sFocus <> "" Then
                    $sQuery = "INSERT INTO ModelFocuses (ModelID, Focus, Stems) VALUES (" & $iInsertedModelID & ", '" & $sFocus & "', '" & $sStems & "');"
                    If _SQLite_Exec($hDb, $sQuery) <> $SQLITE_OK Then
                        _Log("Failed to insert ModelFocuses for " & $sSection & ": " & _SQLite_ErrMsg(), True)
                    EndIf
                EndIf
                If $sApp = "UVR5" Then
                    $sQuery = "INSERT OR REPLACE INTO ModelParameters (ModelName, SegmentSize, Overlap, Denoise, Aggressiveness, TTA) VALUES ('" & _
                              $sName & "', '" & $sSegmentSize & "', '" & $sOverlap & "', '" & $sDenoise & "', '" & $sAggressiveness & "', '" & $sTTA & "');"
                    If _SQLite_Exec($hDb, $sQuery) <> $SQLITE_OK Then
                        _Log("Failed to insert ModelParameters for " & $sSection & ": " & _SQLite_ErrMsg(), True)
                    EndIf
                EndIf
                _Log("Inserted model: " & $sSection)
            Next
            _Log("Database populated from models.ini")
        EndIf
    Else
        $hDb = _SQLite_Open($sDbFile)
        If $hDb = 0 Then
            _Log("Failed to open database: " & _SQLite_ErrMsg(), True)
            _SQLite_Shutdown()
            Return False
        EndIf
        Local $sQuery = "SELECT COUNT(*) FROM Models;"
        Local $aResult, $iRows, $iCols
        If _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols) <> $SQLITE_OK Then
            _Log("Failed to query Models table: " & _SQLite_ErrMsg(), True)
            _SQLite_Close($hDb)
            _SQLite_Shutdown()
            Return False
        EndIf
        _Log("Models database opened successfully")
    EndIf
    _Log("Exiting _InitializeModels")
    Return True
EndFunc

Func _GetModelDetails($sModel)
    _Log("Entering _GetModelDetails for model: " & $sModel)
    If $sModel = "" Then
        _Log("Model name is empty", True)
        Return SetError(3, 0, 0)
    EndIf
    Local $aResult, $iRows, $iCols
    Local $sQuery = "SELECT ModelApps.App, ModelFocuses.Focus, Models.Name, ModelFocuses.Stems, Models.Path, Models.CommandLine, Models.Description, Models.Comments " & _
                    "FROM Models LEFT JOIN ModelApps ON Models.ModelID = ModelApps.ModelID " & _
                    "LEFT JOIN ModelFocuses ON Models.ModelID = ModelFocuses.ModelID " & _
                    "WHERE Models.Name = '" & _SQLite_Escape($sModel) & "';"
    _Log("Executing query: " & $sQuery)
    Local $iRet = _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRet <> $SQLITE_OK Then
        _Log("SQLite query failed for model " & $sModel & ": " & _SQLite_ErrMsg(), True)
        Return SetError(1, 0, 0)
    EndIf
    If $iRows = 0 Or Not IsArray($aResult) Or UBound($aResult, 1) < 2 Then
        _Log("No details found for model " & $sModel, True)
        Return SetError(2, 0, 0)
    EndIf
    Local $aReturn[8]
    For $i = 0 To 7
        $aReturn[$i] = $aResult[1][$i] = Null ? "" : $aResult[1][$i]
    Next
    _Log("Retrieved details for model " & $sModel)
    Return $aReturn
EndFunc

Func SetDefaults()
    _Log("Entering SetDefaults")
    Local $iDefaultTab = 0
    _Log("Setting default tab to Demucs (index " & $iDefaultTab & ")")
    _GUICtrlTab_SetCurSel($hTab, $iDefaultTab)
    $sInputPath = IniRead($sSettingsIni, "Paths", "InputDir", @ScriptDir & "\songs")
    _Log("Setting default input path to " & $sInputPath)
    If Not FileExists($sInputPath) Then
        _Log("Creating input directory: " & $sInputPath)
        DirCreate($sInputPath)
    EndIf
    If FileExists($sInputPath) Then
        _GUICtrlListView_DeleteAllItems($hInputListView)
        Local $aInputFiles = _FileListToArrayRec($sInputPath, "*.wav;*.mp3;*.flac", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)
        If Not @error Then
            _Log("Found " & $aInputFiles[0] & " audio files in " & $sInputPath)
            For $i = 1 To $aInputFiles[0]
                _GUICtrlListView_AddItem($hInputListView, $aInputFiles[$i])
            Next
        Else
            _Log("No audio files found in " & $sInputPath)
        EndIf
    Else
        _Log("Failed to create input path: " & $sInputPath, True)
    EndIf
    $sOutputPath = IniRead($sSettingsIni, "Paths", "OutputDir", @ScriptDir & "\stems")
    _Log("Setting default output path to " & $sOutputPath)
    If Not FileExists($sOutputPath) Then
        _Log("Creating output directory: " & $sOutputPath)
        DirCreate($sOutputPath)
    EndIf
    If FileExists($sOutputPath) Then
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
    Else
        _Log("Failed to create output path: " & $sOutputPath, True)
    EndIf
    Local $sDefaultSong = IniRead($sSettingsIni, "GUI", "LastSong", @ScriptDir & "\songs\song1.wav")
    _Log("Adding default song " & $sDefaultSong & " to Process Queue")
    If FileExists($sDefaultSong) Then
        _GUICtrlListView_DeleteAllItems($hBatchList)
        _GUICtrlListView_AddItem($hBatchList, $sDefaultSong)
        _GUICtrlListView_SetItemChecked($hBatchList, 0, True)
        _Log("Default song " & $sDefaultSong & " added and checked successfully")
    Else
        _Log("Default song " & $sDefaultSong & " does not exist, skipping", True)
    EndIf
    _Log("Triggering _TabHandler to initialize Demucs tab controls and set default model")
    _TabHandler()
    _Log("Exiting SetDefaults")
EndFunc

Func _Main()
    _Log("Entering _Main")
    _LogStartupInfo()
    If Not _InitializeModels() Then
        _Log("Failed to initialize models database", True)
        MsgBox($MB_ICONERROR, "Error", "Failed to initialize models database. Ensure models.ini exists and is correctly formatted, or check write permissions for " & $sDbFile & ". See log at " & $sLogFile & " for details.")
        Exit 1
    EndIf
    _CreateGUI()
    SetDefaults()
    _Log("GUI initialized and defaults set")
    While 1
        Sleep(100)
    WEnd
EndFunc

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




;**************************************************
; AudioWizardSeparator.au3 - Part 3
;**************************************************
#Region Part3
#Region ;**** Parameter and ListView Management ****
Func _GetModelParameters($sModel)
    _Log("Entering _GetModelParameters for model: " & $sModel)
    If $sModel = "" Then
        _Log("Model name is empty", True)
        Return SetError(1, 0, 0)
    EndIf
    Local $aResult, $iRows, $iCols
    Local $sQuery = "SELECT SegmentSize, Overlap, Denoise, Aggressiveness, TTA FROM ModelParameters WHERE ModelName = '" & _SQLite_Escape($sModel) & "';"
    Local $iRet = _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRet <> $SQLITE_OK Then
        _Log("Failed to query parameters: " & _SQLite_ErrMsg(), True)
        Return SetError(2, 0, 0)
    EndIf
    If $iRows = 0 Or Not IsArray($aResult) Or UBound($aResult, 1) < 2 Then
        _Log("No parameters found for model " & $sModel, True)
        Return SetError(3, 0, 0)
    EndIf
    Local $aParams[5]
    For $i = 0 To 4
        $aParams[$i] = $aResult[1][$i] = Null ? "" : $aResult[1][$i]
    Next
    _Log("Retrieved parameters for model " & $sModel)
    _Log("Exiting _GetModelParameters")
    Return $aParams
EndFunc

Func _PopulateListView($hListView, $sPath, $bOutput = False)
    _Log("Entering _PopulateListView for path: " & $sPath & ", Output: " & $bOutput)
    If Not FileExists($sPath) Then
        _Log("Path does not exist: " & $sPath, True)
        Return
    EndIf
    _GUICtrlListView_DeleteAllItems($hListView)
    Local $aFiles = _FileListToArrayRec($sPath, "*.wav;*.mp3;*.flac", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH)
    If @error Then
        _Log("No audio files found in " & $sPath)
        Return
    EndIf
    If $bOutput Then
        ReDim $aOutputFiles[$aFiles[0] + 1]
        $aOutputFiles[0] = $aFiles[0]
        For $i = 1 To $aFiles[0]
            $aOutputFiles[$i] = $aFiles[$i]
            _GUICtrlListView_AddItem($hListView, $aFiles[$i])
        Next
    Else
        ReDim $aInputFiles[$aFiles[0] + 1]
        $aInputFiles[0] = $aFiles[0]
        For $i = 1 To $aFiles[0]
            $aInputFiles[$i] = $aFiles[$i]
            _GUICtrlListView_AddItem($hListView, $aFiles[$i])
        Next
    EndIf
    _Log("Populated ListView with " & $aFiles[0] & " files")
    _Log("Exiting _PopulateListView")
EndFunc
#EndRegion ;**** Parameter and ListView Management ****

#Region ;**** Button Handlers ****
Func _InputDirButtonHandler()
    _Log("Entering _InputDirButtonHandler")
    Local $sPath = FileSelectFolder("Select Input Directory", "", 7, $sInputPath)
    If @error Or $sPath = "" Then
        _Log("No input directory selected")
        Return
    EndIf
    $sInputPath = $sPath
    IniWrite($sSettingsIni, "Paths", "InputDir", $sInputPath)
    _PopulateListView($hInputListView, $sInputPath)
    _Log("Input directory set to: " & $sInputPath)
    _Log("Exiting _InputDirButtonHandler")
EndFunc

Func _OutputDirButtonHandler()
    _Log("Entering _OutputDirButtonHandler")
    Local $sPath = FileSelectFolder("Select Output Directory", "", 7, $sOutputPath)
    If @error Or $sPath = "" Then
        _Log("No output directory selected")
        Return
    EndIf
    $sOutputPath = $sPath
    IniWrite($sSettingsIni, "Paths", "OutputDir", $sOutputPath)
    _PopulateListView($hOutputListView, $sOutputPath, True)
    _Log("Output directory set to: " & $sOutputPath)
    _Log("Exiting _OutputDirButtonHandler")
EndFunc

Func _AddButtonHandler()
    _Log("Entering _AddButtonHandler")
    Local $sFiles = FileOpenDialog("Select Audio Files", $sInputPath, "Audio Files (*.wav;*.mp3;*.flac)", $FD_MULTISELECT)
    If @error Or $sFiles = "" Then
        _Log("No files selected")
        Return
    EndIf
    Local $aFiles = StringSplit($sFiles, "|", $STR_NOCOUNT)
    If UBound($aFiles) = 1 Then
        _GUICtrlListView_AddItem($hBatchList, $sFiles)
        _GUICtrlListView_SetItemChecked($hBatchList, _GUICtrlListView_GetItemCount($hBatchList) - 1, True)
        _Log("Added file to BatchList: " & $sFiles)
    Else
        Local $sDir = $aFiles[0]
        For $i = 1 To UBound($aFiles) - 1
            Local $sFile = $sDir & "\" & $aFiles[$i]
            _GUICtrlListView_AddItem($hBatchList, $sFile)
            _GUICtrlListView_SetItemChecked($hBatchList, _GUICtrlListView_GetItemCount($hBatchList) - 1, True)
            _Log("Added file to BatchList: " & $sFile)
        Next
    EndIf
    _Log("Exiting _AddButtonHandler")
EndFunc

Func _ClearButtonHandler()
    _Log("Entering _ClearButtonHandler")
    _GUICtrlListView_DeleteAllItems($hBatchList)
    _Log("Cleared BatchList")
    _Log("Exiting _ClearButtonHandler")
EndFunc

Func _DeleteButtonHandler()
    _Log("Entering _DeleteButtonHandler")
    Local $iCount = _GUICtrlListView_GetItemCount($hBatchList)
    For $i = $iCount - 1 To 0 Step -1
        If _GUICtrlListView_GetItemSelected($hBatchList, $i) Then
            Local $sFile = _GUICtrlListView_GetItemText($hBatchList, $i)
            _GUICtrlListView_DeleteItem($hBatchList, $i)
            _Log("Deleted item from BatchList: " & $sFile)
        EndIf
    Next
    _Log("Exiting _DeleteButtonHandler")
EndFunc

Func _DescEditHandler()
    _Log("Entering _DescEditHandler")
    Local $sModel = GUICtrlRead($hModelCombo)
    If $sModel = "" Or $sModel = "No models available" Then
        _Log("No model selected for description update", True)
        Return
    EndIf
    Local $sDesc = GUICtrlRead($hDescEdit)
    Local $sQuery = "UPDATE Models SET Description = '" & _SQLite_Escape($sDesc) & "' WHERE Name = '" & _SQLite_Escape($sModel) & "';"
    If _SQLite_Exec($hDb, $sQuery) <> $SQLITE_OK Then
        _Log("Failed to update description: " & _SQLite_ErrMsg(), True)
    Else
        _Log("Updated description for model: " & $sModel)
    EndIf
    _Log("Exiting _DescEditHandler")
EndFunc

Func _CommentsEditHandler()
    _Log("Entering _CommentsEditHandler")
    Local $sModel = GUICtrlRead($hModelCombo)
    If $sModel = "" Or $sModel = "No models available" Then
        _Log("No model selected for comments update", True)
        Return
    EndIf
    Local $sComments = GUICtrlRead($hCommentsEdit)
    Local $sQuery = "UPDATE Models SET Comments = '" & _SQLite_Escape($sComments) & "' WHERE Name = '" & _SQLite_Escape($sModel) & "';"
    If _SQLite_Exec($hDb, $sQuery) <> $SQLITE_OK Then
        _Log("Failed to update comments: " & _SQLite_ErrMsg(), True)
    Else
        _Log("Updated comments for model: " & $sModel)
    EndIf
    _Log("Exiting _CommentsEditHandler")
EndFunc

Func _SaveSettingsButtonHandler()
    _Log("Entering _SaveSettingsButtonHandler")
    Local $sModel = GUICtrlRead($hModelCombo)
    If $sModel = "" Or $sModel = "No models available" Then
        _Log("No model selected for saving settings", True)
        MsgBox($MB_ICONWARNING, "Warning", "Please select a model before saving settings.")
        Return
    EndIf
    Local $sSettingsName = InputBox("Save Settings", "Enter a name for the settings:", "", "", 300, 150)
    If @error Or $sSettingsName = "" Then
        _Log("Settings save cancelled or invalid name")
        Return
    EndIf
    Local $sQuery = "INSERT OR REPLACE INTO SavedSettings (Name, ModelName, App) VALUES ('" & _SQLite_Escape($sSettingsName) & "', '" & _SQLite_Escape($sModel) & "', '" & _SQLite_Escape(GUICtrlRead($hAppCombo)) & "');"
    If _SQLite_Exec($hDb, $sQuery) <> $SQLITE_OK Then
        _Log("Failed to save settings: " & _SQLite_ErrMsg(), True)
        MsgBox($MB_ICONERROR, "Error", "Failed to save settings. See log for details.")
        Return
    EndIf
    If GUICtrlRead($hAppCombo) = "UVR5" Then
        Local $sSegmentSize = GUICtrlRead($hSegmentSizeCombo)
        Local $sOverlap = GUICtrlRead($hOverlapInput)
        Local $sDenoise = GUICtrlRead($hDenoiseCheckbox) = $GUI_CHECKED ? "True" : "False"
        Local $sAggressiveness = GUICtrlRead($hAggressivenessInput)
        Local $sTTA = GUICtrlRead($hTTACheckbox) = $GUI_CHECKED ? "True" : "False"
        $sQuery = "INSERT OR REPLACE INTO ModelParameters (ModelName, SegmentSize, Overlap, Denoise, Aggressiveness, TTA) VALUES ('" & _
                  _SQLite_Escape($sModel) & "', '" & _SQLite_Escape($sSegmentSize) & "', '" & _SQLite_Escape($sOverlap) & "', '" & _
                  _SQLite_Escape($sDenoise) & "', '" & _SQLite_Escape($sAggressiveness) & "', '" & _SQLite_Escape($sTTA) & "');"
        If _SQLite_Exec($hDb, $sQuery) <> $SQLITE_OK Then
            _Log("Failed to save UVR5 parameters: " & _SQLite_ErrMsg(), True)
        Else
            _Log("Saved UVR5 parameters for model: " & $sModel)
        EndIf
    EndIf
    _UpdateSettingsDroplist()
    _Log("Settings saved as: " & $sSettingsName)
    _Log("Exiting _SaveSettingsButtonHandler")
EndFunc

Func _LoadSettings()
    _Log("Entering _LoadSettings")
    Local $sSettingsName = GUICtrlRead($hSettingsCombo)
    If $sSettingsName = "" Or $sSettingsName = "No settings available" Then
        _Log("No settings selected", True)
        Return
    EndIf
    Local $sQuery = "SELECT ModelName, App FROM SavedSettings WHERE Name = '" & _SQLite_Escape($sSettingsName) & "';"
    Local $aResult, $iRows, $iCols
    If _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols) <> $SQLITE_OK Then
        _Log("Failed to load settings: " & _SQLite_ErrMsg(), True)
        Return
    EndIf
    If $iRows = 0 Or Not IsArray($aResult) Or UBound($aResult, 1) < 2 Then
        _Log("No settings found for name: " & $sSettingsName, True)
        Return
    EndIf
    Local $sModel = $aResult[1][0]
    Local $sApp = $aResult[1][1]
    GUICtrlSetData($hAppCombo, $sApp)
    Local $iMargin = 10
    Local $iListViewWidth = ($iGuiWidth - 3 * $iMargin) / 2
    Local $iListViewHeight = 150
    Local $iButtonHeight = 30
    Local $iControlWidth = $iListViewWidth
    Local $iComboHeight = 25
    _UpdateAppControls($iListViewWidth, $iListViewHeight, $iButtonHeight, $iMargin, $iControlWidth, $iComboHeight)
    GUICtrlSetData($hModelCombo, $sModel)
    _UpdateModelDetails($sModel)
    _Log("Loaded settings: " & $sSettingsName & ", Model: " & $sModel & ", App: " & $sApp)
    _Log("Exiting _LoadSettings")
EndFunc

Func _ModelComboHandler()
    _Log("Entering _ModelComboHandler")
    Local $sModel = GUICtrlRead($hModelCombo)
    If $sModel = "" Or $sModel = "No models available" Then
        _Log("No model selected", True)
        _UpdateModelDetails("")
        Return
    EndIf
    _UpdateModelDetails($sModel)
    _Log("Exiting _ModelComboHandler")
EndFunc

Func _SeparateButtonHandler()
    _Log("Entering _SeparateButtonHandler")
    If $bProcessing Then
        _Log("Separation already in progress", True)
        MsgBox($MB_ICONWARNING, "Warning", "A separation process is already running.")
        Return
    EndIf
    Local $iCount = _GUICtrlListView_GetItemCount($hBatchList)
    If $iCount = 0 Then
        _Log("No files in batch list", True)
        MsgBox($MB_ICONWARNING, "Warning", "No files selected for separation.")
        Return
    EndIf
    If Not FileExists($sInputPath) Then
        _Log("Input path does not exist: " & $sInputPath, True)
        MsgBox($MB_ICONERROR, "Error", "Input directory does not exist.")
        Return
    EndIf
    If Not FileExists($sOutputPath) Then
        _Log("Output path does not exist: " & $sOutputPath, True)
        MsgBox($MB_ICONERROR, "Error", "Output directory does not exist.")
        Return
    EndIf
    Local $sPythonPath = IniRead($sSettingsIni, "Paths", "PythonPath", "python")
    Local $sScriptPath = @ScriptDir & "\separate.py"
    If Not FileExists($sScriptPath) Then
        _Log("Separation script not found: " & $sScriptPath, True)
        MsgBox($MB_ICONERROR, "Error", "Separation script (separate.py) not found.")
        Return
    EndIf
    Local $sFFmpegPath = IniRead($sSettingsIni, "Paths", "FFmpegPath", "C:\temp\s2S\installs\uvr\ffmpeg\bin\ffmpeg.exe")
    If Not FileExists($sFFmpegPath) Then
        _Log("FFmpeg not found: " & $sFFmpegPath, True)
        MsgBox($MB_ICONERROR, "Error", "FFmpeg not found at: " & $sFFmpegPath)
        Return
    EndIf
    Local $sModel = GUICtrlRead($hModelCombo)
    If $sModel = "" Or $sModel = "No models available" Then
        _Log("No model selected", True)
        MsgBox($MB_ICONWARNING, "Warning", "Please select a model.")
        Return
    EndIf
    $bProcessing = True
    GUICtrlSetData($hProgressLabel, "Progress: 0%")
    GUICtrlSetData($hCountLabel, "0 of " & $iCount)
    Local $iProcessed = 0
    For $i = 0 To $iCount - 1
        If Not $bProcessing Then ExitLoop
        If _GUICtrlListView_GetItemChecked($hBatchList, $i) Then
            Local $sFile = _GUICtrlListView_GetItemText($hBatchList, $i)
            If Not FileExists($sFile) Then
                _Log("Input file not found: " & $sFile, True)
                ContinueLoop
            EndIf
            Local $sCmd = '"' & $sPythonPath & '" "' & $sScriptPath & '" "' & $sFile & '" "' & $sOutputPath & '" "' & $sModel & '"'
            If GUICtrlRead($hAppCombo) = "UVR5" Then
                Local $sSegmentSize = GUICtrlRead($hSegmentSizeCombo)
                Local $sOverlap = GUICtrlRead($hOverlapInput)
                Local $sDenoise = GUICtrlRead($hDenoiseCheckbox) = $GUI_CHECKED ? "True" : "False"
                Local $sAggressiveness = GUICtrlRead($hAggressivenessInput)
                Local $sTTA = GUICtrlRead($hTTACheckbox) = $GUI_CHECKED ? "True" : "False"
                $sCmd &= ' --segment_size "' & $sSegmentSize & '" --overlap "' & $sOverlap & '" --denoise "' & $sDenoise & '" --aggressiveness "' & $sAggressiveness & '" --tta "' & $sTTA & '"'
            EndIf
            _Log("Executing separation command: " & $sCmd)
            Local $iPID = Run($sCmd, "", @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
            Local $sOutput = "", $sError = ""
            While ProcessExists($iPID)
                $sOutput &= StdoutRead($iPID)
                $sError &= StderrRead($iPID)
                Sleep(100)
            WEnd
            ProcessWaitClose($iPID)
            If $sError <> "" Then
                _Log("Separation error for " & $sFile & ": " & $sError, True)
                _HandleExternalError($sError)
            Else
                _Log("Separation completed for " & $sFile)
            EndIf
            $iProcessed += 1
            GUICtrlSetData($hProgressLabel, "Progress: " & Round($iProcessed / $iCount * 100) & "%")
            GUICtrlSetData($hCountLabel, $iProcessed & " of " & $iCount)
            _PopulateListView($hOutputListView, $sOutputPath, True)
        EndIf
    Next
    $bProcessing = False
    GUICtrlSetData($hProgressLabel, "Progress: 100%")
    _Log("Separation process completed")
    _Log("Exiting _SeparateButtonHandler")
EndFunc
#EndRegion ;**** Button Handlers ****

#Region ;**** Notification Handler ****
Func _WM_NOTIFY($hWnd, $iMsg, $wParam, $lParam)
    _Log("Entering _WM_NOTIFY")
    Local $iDummy = $hWnd + $iMsg + $wParam ; Suppress unused parameter warnings
    Local $iIndex, $iItem, $sFile
    Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
    If @error Then
        _Log("Failed to create NMHDR structure", True)
        Return $GUI_RUNDEFMSG
    EndIf
    Local $hWndFrom = HWnd(DllStructGetData($tNMHDR, "hWndFrom"))
    Local $iCode = DllStructGetData($tNMHDR, "Code")
    Switch $hWndFrom
        Case GUICtrlGetHandle($hInputListView)
            Switch $iCode
                Case $LVN_ITEMCHANGED
                    Local $tNMLISTVIEW = DllStructCreate($tagNMLISTVIEW, $lParam)
                    If @error Then
                        _Log("Failed to create NMLISTVIEW structure", True)
                        Return $GUI_RUNDEFMSG
                    EndIf
                    $iItem = DllStructGetData($tNMLISTVIEW, "Item")
                    If $iItem >= 0 Then
                        Local $bChecked = _GUICtrlListView_GetItemChecked($hInputListView, $iItem)
                        $sFile = _GUICtrlListView_GetItemText($hInputListView, $iItem)
                        If $bChecked Then
                            $iIndex = _GUICtrlListView_FindText($hBatchList, $sFile, -1, False)
                            If $iIndex = -1 Then
                                _Log("Adding checked item to BatchList: " & $sFile)
                                $iIndex = _GUICtrlListView_AddItem($hBatchList, $sFile)
                                _GUICtrlListView_SetItemChecked($hBatchList, $iIndex, True)
                            EndIf
                        Else
                            $iIndex = _GUICtrlListView_FindText($hBatchList, $sFile, -1, False)
                            If $iIndex <> -1 Then
                                _Log("Removing unchecked item from BatchList: " & $sFile)
                                _GUICtrlListView_DeleteItem($hBatchList, $iIndex)
                            EndIf
                        EndIf
                    EndIf
                Case $NM_DBLCLK
                    Local $tNMITEMACTIVATE = DllStructCreate($tagNMITEMACTIVATE, $lParam)
                    If @error Then
                        _Log("Failed to create NMITEMACTIVATE structure", True)
                        Return $GUI_RUNDEFMSG
                    EndIf
                    $iItem = DllStructGetData($tNMITEMACTIVATE, "Index")
                    If $iItem >= 0 Then
                        $sFile = _GUICtrlListView_GetItemText($hInputListView, $iItem)
                        $iIndex = _GUICtrlListView_FindText($hBatchList, $sFile, -1, False)
                        If $iIndex = -1 Then
                            _Log("Double-clicked item added to BatchList: " & $sFile)
                            $iIndex = _GUICtrlListView_AddItem($hBatchList, $sFile)
                            _GUICtrlListView_SetItemChecked($hBatchList, $iIndex, True)
                            _GUICtrlListView_SetItemChecked($hInputListView, $iItem, True)
                        EndIf
                    EndIf
            EndSwitch
    EndSwitch
    _Log("Exiting _WM_NOTIFY")
    Return $GUI_RUNDEFMSG
EndFunc
#EndRegion ;**** Notification Handler ****
#EndRegion Part3



;**************************************************
; AudioWizardSeparator.au3 - Part 4
;**************************************************
#Region Part4
#Region ;**** Tab and Error Handling ****
Func _TabHandler()
    _Log("Entering _TabHandler")
    Local $iTabIndex = _GUICtrlTab_GetCurSel($hTab)
    If $iTabIndex < 0 Or $iTabIndex > 2 Then
        _Log("Invalid tab index: " & $iTabIndex, True)
        Return
    EndIf
    Local $sApp
    Switch $iTabIndex
        Case 0
            $sApp = "Demucs"
        Case 1
            $sApp = "Spleeter"
        Case 2
            $sApp = "UVR5"
    EndSwitch
    If $sApp = "" Then
        _Log("Failed to determine app for tab index: " & $iTabIndex, True)
        Return
    EndIf
    If Not IsHWnd($hAppCombo) Then
        _Log("AppCombo control not found", True)
        Return
    EndIf
    GUICtrlSetData($hAppCombo, $sApp)
    Local $iMargin = 10
    Local $iListViewWidth = ($iGuiWidth - 3 * $iMargin) / 2
    Local $iListViewHeight = 150
    Local $iButtonHeight = 30
    Local $iControlWidth = $iListViewWidth
    Local $iComboHeight = 25
    _UpdateAppControls($iListViewWidth, $iListViewHeight, $iButtonHeight, $iMargin, $iControlWidth, $iComboHeight)
    _Log("Tab switched to: " & $sApp)
    _Log("Exiting _TabHandler")
EndFunc

Func _HandleExternalError($sError)
    _Log("Entering _HandleExternalError")
    _Log("External error: " & $sError, True)
    Local $sModel = GUICtrlRead($hModelCombo)
    Local $sFile = _GUICtrlListView_GetItemText($hBatchList, _GUICtrlListView_GetItemCount($hBatchList) - 1)
    Local $sMessage = "Separation failed for file: " & $sFile & @CRLF & "Model: " & $sModel & @CRLF & "Error: "
    If StringInStr($sError, "No module named") Then
        $sMessage &= "Missing Python module. Check dependencies (e.g., librosa, matplotlib)."
    ElseIf StringInStr($sError, "ffmpeg") Then
        $sMessage &= "FFmpeg error. Verify FFmpeg path in settings.ini."
    ElseIf StringInStr($sError, "File not found") Then
        $sMessage &= "Input file or model file not found."
    Else
        $sMessage &= "Unknown error. See log for details."
    EndIf
    MsgBox($MB_ICONERROR, "Separation Error", $sMessage)
    _Log("Displayed error message: " & $sMessage)
    _Log("Exiting _HandleExternalError")
EndFunc
#EndRegion ;**** Tab and Error Handling ****

#Region ;**** Spectrogram Display ****
Func _ShowSpectrogram($sFile, $sOutputPath, $sModel)
    _Log("Entering _ShowSpectrogram for file: " & $sFile & ", model: " & $sModel)
    If Not FileExists($sOutputPath) Then
        _Log("Output path does not exist: " & $sOutputPath, True)
        MsgBox($MB_ICONERROR, "Error", "Output directory not found: " & $sOutputPath)
        Return
    EndIf
    Local $sPythonPath = IniRead($sSettingsIni, "Paths", "PythonPath", "python")
    Local $sFFmpegPath = IniRead($sSettingsIni, "Paths", "FFmpegPath", "C:\temp\s2S\installs\uvr\ffmpeg\bin\ffmpeg.exe")
    If Not FileExists($sFFmpegPath) Then
        _Log("FFmpeg not found: " & $sFFmpegPath, True)
        MsgBox($MB_ICONERROR, "Error", "FFmpeg not found at: " & $sFFmpegPath)
        Return
    EndIf
    Local $sScriptPath = @ScriptDir & "\spectrogram.py"
    If Not FileExists($sScriptPath) Then
        _Log("Spectrogram script not found: " & $sScriptPath, True)
        MsgBox($MB_ICONERROR, "Error", "Spectrogram script (spectrogram.py) not found.")
        Return
    EndIf
    Local $sBaseName = StringRegExpReplace($sFile, "^.*\\", "")
    Local $sStemPath
    If GUICtrlRead($hAppCombo) = "UVR5" Then
        $sStemPath = $sOutputPath & "\" & $sBaseName & "_vocals.wav"
    Else
        $sStemPath = $sOutputPath & "\" & $sBaseName & "_vocals.wav"
    EndIf
    If Not FileExists($sStemPath) Then
        _Log("Stem file not found: " & $sStemPath, True)
        MsgBox($MB_ICONERROR, "Error", "Stem file not found: " & $sStemPath)
        Return
    EndIf
    Local $sCmd = '"' & $sPythonPath & '" "' & $sScriptPath & '" "' & $sStemPath & '"'
    _Log("Executing spectrogram command: " & $sCmd)
    Local $iPID = Run($sCmd, "", @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
    Local $sOutput = "", $sError = ""
    While ProcessExists($iPID)
        $sOutput &= StdoutRead($iPID)
        $sError &= StderrRead($iPID)
        Sleep(100)
    WEnd
    ProcessWaitClose($iPID)
    If $sError <> "" Then
        _Log("Spectrogram generation error: " & $sError, True)
        If StringInStr($sError, "matplotlib") Then
            MsgBox($MB_ICONERROR, "Error", "Failed to generate spectrogram. Ensure matplotlib is installed in Python.")
        Else
            MsgBox($MB_ICONERROR, "Error", "Failed to generate spectrogram. See log for details.")
        EndIf
        Return
    EndIf
    _Log("Spectrogram generated for: " & $sStemPath)
    _Log("Exiting _ShowSpectrogram")
EndFunc
#EndRegion ;**** Spectrogram Display ****

#Region ;**** Exit Handler ****
Func _Exit()
    _Log("Entering _Exit")
    If $bProcessing Then
        _Log("Separation in progress, prompting user", True)
        If MsgBox($MB_YESNO + $MB_ICONWARNING, "Exit", "Separation is in progress. Exit anyway?") = $IDNO Then
            _Log("Exit cancelled by user")
            Return
        EndIf
    EndIf
    If $hDb <> 0 Then
        If _SQLite_Close($hDb) <> $SQLITE_OK Then
            _Log("Failed to close SQLite database: " & _SQLite_ErrMsg(), True)
        Else
            _Log("SQLite database closed")
        EndIf
        $hDb = 0
    EndIf
    If _SQLite_Shutdown() <> $SQLITE_OK Then
        _Log("Failed to shutdown SQLite", True)
    Else
        _Log("SQLite shutdown completed")
    EndIf
    If $hGraphics <> 0 Then
        _GDIPlus_GraphicsDispose($hGraphics)
        $hGraphics = 0
        _Log("GDI+ graphics disposed")
    EndIf
    If $hGraphicGUI <> 0 Then
        _GDIPlus_GraphicsDispose($hGraphicGUI)
        $hGraphicGUI = 0
        _Log("GDI+ graphic GUI disposed")
    EndIf
    If $hDC <> 0 Then
        _WinAPI_ReleaseDC(GUICtrlGetHandle($hGraphic), $hDC)
        $hDC = 0
        _Log("DC released")
    EndIf
    If $hBrushGray <> 0 Then
        _GDIPlus_BrushDispose($hBrushGray)
        $hBrushGray = 0
        _Log("Gray brush disposed")
    EndIf
    If $hBrushGreen <> 0 Then
        _GDIPlus_BrushDispose($hBrushGreen)
        $hBrushGreen = 0
        _Log("Green brush disposed")
    EndIf
    If $hBrushYellow <> 0 Then
        _GDIPlus_BrushDispose($hBrushYellow)
        $hBrushYellow = 0
        _Log("Yellow brush disposed")
    EndIf
    If $hPen <> 0 Then
        _GDIPlus_PenDispose($hPen)
        $hPen = 0
        _Log("Pen disposed")
    EndIf
    If _GDIPlus_Shutdown() Then
        _Log("GDI+ shutdown completed")
    Else
        _Log("Failed to shutdown GDI+", True)
    EndIf
    If IsHWnd($hGUI) Then
        GUIDelete($hGUI)
        _Log("GUI deleted")
    EndIf
    _Log("Script exiting")
    Exit
EndFunc
#EndRegion ;**** Exit Handler ****
#EndRegion Part4