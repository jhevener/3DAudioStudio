;**************************************************
;********************Part 1************************
;**************************************************
#Region Part1
#Region ;**** Directives and Includes ****
#AutoIt3Wrapper_Res_Description=Stem Separator
#AutoIt3Wrapper_Res_Fileversion=1.0.0.25
#AutoIt3Wrapper_Res_ProductName=Stem Separator
#AutoIt3Wrapper_Res_ProductVersion=1.0.0
#AutoIt3Wrapper_Res_CompanyName=FretzCapo
#AutoIt3Wrapper_Res_LegalCopyright=� 2025 FretzCapo
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
Global $hInputDirButton, $hOutputDirButton, $hAddButton, $hClearButton, $hDeleteButton, $hSeparateButton, $hSaveSettingsButton, $hManageDbButton
Global $hModelNameLabel, $hStemsLabel, $hStemsDisplay, $hFocusLabel, $hFocusDisplay
Global $hDescLabel, $hDescEdit, $hCommentsLabel, $hCommentsEdit
Global $hProgressLabel, $hCountLabel, $hGraphic
Global $hGraphicGUI, $hDC, $hGraphics, $hBrushGray, $hBrushGreen, $hBrushYellow, $hPen
Global $iGuiWidth, $iGuiHeight
Global $hDb, $sDbFile
Global $sSettingsIni = @ScriptDir & "\settings.ini"
Global $sModelsIni = @ScriptDir & "\Models.ini"
Global $sUserIni = @ScriptDir & "\user.ini"
Global $sLogFile = ""
Global $sInputPath = @ScriptDir & "\songs"
Global $sOutputPath = @ScriptDir & "\stems"

$iGuiWidth = Int(IniRead($sSettingsIni, "GUI", "Width", 800))
$iGuiHeight = Int(IniRead($sSettingsIni, "GUI", "Height", 600))
$sDbFile = IniRead($sSettingsIni, "Paths", "DbFile", @ScriptDir & "\models.db")
$sLogFile = IniRead($sSettingsIni, "Paths", "LogDir", @ScriptDir & "\logs") & "\StemSeparator_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & ".log.txt"
If Not FileExists(IniRead($sSettingsIni, "Paths", "LogDir", @ScriptDir & "\logs")) Then DirCreate(IniRead($sSettingsIni, "Paths", "LogDir", @ScriptDir & "\logs"))
#EndRegion ;**** Global Variables and Constants ****

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
            _Log("Invalid tab index: " & $iTabIndex, True)
            GUICtrlSetData($hModelCombo, "|No models available")
            Return
    EndSwitch

    Local $aResult, $iRows, $iCols
    Local $sQuery = "SELECT Models.Name FROM Models INNER JOIN ModelApps ON Models.ModelID = ModelApps.ModelID WHERE ModelApps.App = '" & $sAppFilter & "' ORDER BY Models.Name;"
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
        GUICtrlSetData($hModelCombo, "|" & $sModelList)
    Else
        _Log("No models found for " & $sAppFilter)
        GUICtrlSetData($hModelCombo, "|No models available")
    EndIf
    _Log("Exiting _UpdateModelDroplist")
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
                    "WHERE Models.Name = '" & $sModel & "';"
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

    _Log("Triggering _TabHandler to initialize Demucs tab controls and set default model")
    _TabHandler()

    $sInputPath = IniRead($sSettingsIni, "Paths", "InputDir", @ScriptDir & "\songs")
    _Log("Setting default input path to " & $sInputPath)
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
        _Log("Default input path " & $sInputPath & " does not exist", True)
    EndIf

    $sOutputPath = IniRead($sSettingsIni, "Paths", "OutputDir", @ScriptDir & "\stems")
    _Log("Setting default output path to " & $sOutputPath)
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
        _Log("Default output path " & $sOutputPath & " does not exist", True)
    EndIf

    Local $sDefaultSong = IniRead($sSettingsIni, "GUI", "LastSong", @ScriptDir & "\songs\song1.wav")
    _Log("Adding default song " & $sDefaultSong & " to Process Queue")
    If FileExists($sDefaultSong) Then
        _GUICtrlListView_DeleteAllItems($hBatchList)
        _GUICtrlListView_AddItem($hBatchList, $sDefaultSong)
        _GUICtrlListView_SetItemChecked($hBatchList, 0, True)
        _Log("Default song " & $sDefaultSong & " added and checked successfully")
    Else
        _Log("Default song " & $sDefaultSong & " does not exist", True)
    EndIf

    _Log("Exiting SetDefaults")
EndFunc

Func _Main()
    _Log("Entering _Main")
    _LogStartupInfo()
    If Not _InitializeModels() Then
        _Log("Failed to initialize models database", True)
        MsgBox($MB_ICONERROR, "Error", "Failed to initialize models database. See log for details.")
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
;********************Part 2************************
;**************************************************
#Region Part2
#Region ;**** GUI Creation Functions ****
Func _CreateGUI()
    _Log("Entering _CreateGUI")
    $hGUI = GUICreate("Stem Separator", $iGuiWidth, $iGuiHeight, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU, $WS_SIZEBOX))
    GUISetBkColor(0xFFFFFF)

    ; Top 30 pixels: Buttons for user interaction
    Local $iButtonY = 5
    Local $iButtonCtrlWidth = 80
    Local $iButtonCtrlHeight = 20
    Local $iButtonSpacing = 10
    Local $iTotalButtonWidth = ($iButtonCtrlWidth * 8) + ($iButtonSpacing * 7) ; Updated for 8 buttons
    Local $iButtonXStart = ($iGuiWidth - $iTotalButtonWidth) / 2

    $hInputDirButton = GUICtrlCreateButton("Input Dir", $iButtonXStart, $iButtonY, $iButtonCtrlWidth, $iButtonCtrlHeight)
    GUICtrlSetBkColor($hInputDirButton, $GOOGLE_GREEN)
    $hOutputDirButton = GUICtrlCreateButton("Output Dir", $iButtonXStart + $iButtonCtrlWidth + $iButtonSpacing, $iButtonY, $iButtonCtrlWidth, $iButtonCtrlHeight)
    GUICtrlSetBkColor($hOutputDirButton, $GOOGLE_GREEN)
    $hAddButton = GUICtrlCreateButton("Add", $iButtonXStart + ($iButtonCtrlWidth + $iButtonSpacing) * 2, $iButtonY, $iButtonCtrlWidth, $iButtonCtrlHeight)
    GUICtrlSetBkColor($hAddButton, $GOOGLE_GREEN)
    $hClearButton = GUICtrlCreateButton("Clear", $iButtonXStart + ($iButtonCtrlWidth + $iButtonSpacing) * 3, $iButtonY, $iButtonCtrlWidth, $iButtonCtrlHeight)
    GUICtrlSetBkColor($hClearButton, $GOOGLE_GREEN)
    $hDeleteButton = GUICtrlCreateButton("Delete", $iButtonXStart + ($iButtonCtrlWidth + $iButtonSpacing) * 4, $iButtonY, $iButtonCtrlWidth, $iButtonCtrlHeight)
    GUICtrlSetBkColor($hDeleteButton, $GOOGLE_GREEN)
    $hSeparateButton = GUICtrlCreateButton("Separate", $iButtonXStart + ($iButtonCtrlWidth + $iButtonSpacing) * 5, $iButtonY, $iButtonCtrlWidth, $iButtonCtrlHeight)
    GUICtrlSetBkColor($hSeparateButton, $GOOGLE_GREEN)
    $hSaveSettingsButton = GUICtrlCreateButton("Save Settings", $iButtonXStart + ($iButtonCtrlWidth + $iButtonSpacing) * 6, $iButtonY, $iButtonCtrlWidth, $iButtonCtrlHeight)
    GUICtrlSetBkColor($hSaveSettingsButton, $GOOGLE_GREEN)
    $hManageDbButton = GUICtrlCreateButton("Manage DB", $iButtonXStart + ($iButtonCtrlWidth + $iButtonSpacing) * 7, $iButtonY, $iButtonCtrlWidth, $iButtonCtrlHeight)
    GUICtrlSetBkColor($hManageDbButton, $GOOGLE_GREEN)

    ; Layout: Four quadrants below buttons
    Local $iQuadWidth = ($iGuiWidth - 30) / 2
    Local $iQuadHeight = ($iGuiHeight - 110) / 2
    Local $iLeftQuadX = 10
    Local $iRightQuadX = $iLeftQuadX + $iQuadWidth + 10
    Local $iTopQuadY = 35
    Local $iBottomQuadY = $iTopQuadY + $iQuadHeight + 10

    ; Top-left quadrant: Input ListView for selecting audio files
    $hInputListView = GUICtrlCreateListView("Input Files", $iLeftQuadX, $iTopQuadY, $iQuadWidth, $iQuadHeight, BitOR($LVS_REPORT, $LVS_SHOWSELALWAYS, $LVS_EX_CHECKBOXES, $LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT))
    _GUICtrlListView_SetColumnWidth($hInputListView, 0, $iQuadWidth - 20)

    ; Top-right quadrant: Tabbed Control (now filling the entire quadrant)
    $hTab = GUICtrlCreateTab($iRightQuadX, $iTopQuadY, $iQuadWidth, $iQuadHeight)

    ; Tab 1: Demucs
    GUICtrlCreateTabItem("Demucs")
    Local $iTabTopY = $iTopQuadY + 30 ; Adjust for tab header height
    $hModelNameLabel = GUICtrlCreateLabel("Model Name:", $iRightQuadX + 5, $iTabTopY, 70, 20)
    $hModelCombo = GUICtrlCreateCombo("", $iRightQuadX + 80, $iTabTopY, 150, 25, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL, $WS_VSCROLL))
    $hStemsLabel = GUICtrlCreateLabel("Stems:", $iRightQuadX + 235, $iTabTopY, 40, 20)
    $hStemsDisplay = GUICtrlCreateLabel("", $iRightQuadX + 275, $iTabTopY, 30, 20)

    Local $iDetailsX = $iRightQuadX + 5
    Local $iDetailsY = $iTabTopY + 30
    Local $iDetailsWidth = $iQuadWidth - 10
    Local $iLabelHeight = 20
    Local $iLabelSpacing = 25

    $hFocusLabel = GUICtrlCreateLabel("Focus:", $iDetailsX, $iDetailsY, 80, $iLabelHeight)
    $hFocusDisplay = GUICtrlCreateLabel("", $iDetailsX + 80, $iDetailsY, $iDetailsWidth - 80, $iLabelHeight)
    $hDescLabel = GUICtrlCreateLabel("Description:", $iDetailsX, $iDetailsY + $iLabelSpacing, 80, $iLabelHeight)
    $hDescEdit = GUICtrlCreateEdit("", $iDetailsX, $iDetailsY + $iLabelSpacing + 20, $iDetailsWidth, 80, BitOR($ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL))
    $hCommentsLabel = GUICtrlCreateLabel("Comments:", $iDetailsX, $iDetailsY + $iLabelSpacing * 2 + 80, 80, $iLabelHeight)
    $hCommentsEdit = GUICtrlCreateEdit("", $iDetailsX, $iDetailsY + $iLabelSpacing * 2 + 100, $iDetailsWidth, 80, BitOR($ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL))

    ; Tab 2: Spleeter
    GUICtrlCreateTabItem("Spleeter")
    ; Controls are recreated in _TabHandler when the tab is switched

    ; Tab 3: UVR5
    GUICtrlCreateTabItem("UVR5")
    ; Controls are recreated in _TabHandler when the tab is switched

    GUICtrlCreateTabItem("")

    ; Bottom-left quadrant: Output ListView for displaying separated stems
    $hOutputListView = GUICtrlCreateListView("Output Files", $iLeftQuadX, $iBottomQuadY, $iQuadWidth, $iQuadHeight, BitOR($LVS_REPORT, $LVS_SHOWSELALWAYS, $LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT))
    _GUICtrlListView_SetColumnWidth($hOutputListView, 0, $iQuadWidth - 20)

    ; Bottom-right quadrant: Process Queue for managing files to separate
    $hBatchList = GUICtrlCreateListView("Process Queue", $iRightQuadX, $iBottomQuadY, $iQuadWidth, $iQuadHeight, BitOR($LVS_REPORT, $LVS_SHOWSELALWAYS, $LVS_EX_CHECKBOXES, $LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT))
    _GUICtrlListView_SetColumnWidth($hBatchList, 0, $iQuadWidth - 20)

    ; Bottom: Progress bar and labels for task status
    $hProgressLabel = GUICtrlCreateLabel("Task Progress: 0%", $iLeftQuadX, $iGuiHeight - 65, $iGuiWidth / 2, 20)
    $hCountLabel = GUICtrlCreateLabel("Tasks Completed: 0/0", $iLeftQuadX, $iGuiHeight - 45, $iGuiWidth / 2, 20)
    $hGraphic = GUICtrlCreateGraphic($iLeftQuadX, $iGuiHeight - 25, $iGuiWidth - 20, 20)
    GUICtrlSetBkColor($hGraphic, 0xFFFFFF)
    GUICtrlSetGraphic($hGraphic, $GUI_GR_RECT, 0, 0, $iGuiWidth - 20, 20)
    _GDIPlus_Startup()
    $hGraphicGUI = GUICtrlGetHandle($hGraphic)
    $hDC = _WinAPI_GetDC($hGraphicGUI)
    $hGraphics = _GDIPlus_GraphicsCreateFromHDC($hDC)
    $hBrushGray = _GDIPlus_BrushCreateSolid(0xFFC0C0C0)
    $hBrushGreen = _GDIPlus_BrushCreateSolid($GOOGLE_GREEN)
    $hBrushYellow = _GDIPlus_BrushCreateSolid($GOOGLE_YELLOW)
    $hPen = _GDIPlus_PenCreate(0xFF000000, 1)

    ; Set event handlers for user interaction
    GUICtrlSetOnEvent($hInputDirButton, "_InputButtonHandler")
    GUICtrlSetOnEvent($hOutputDirButton, "_OutputButtonHandler")
    GUICtrlSetOnEvent($hAddButton, "_AddButtonHandler")
    GUICtrlSetOnEvent($hClearButton, "_ClearButtonHandler")
    GUICtrlSetOnEvent($hDeleteButton, "_DeleteButtonHandler")
    GUICtrlSetOnEvent($hSeparateButton, "_SeparateButtonHandler")
    GUICtrlSetOnEvent($hSaveSettingsButton, "_SaveSettingsButtonHandler")
    GUICtrlSetOnEvent($hManageDbButton, "_ManageDbButtonHandler") ; New event handler
    GUICtrlSetOnEvent($hModelCombo, "_ModelComboHandler")
    GUICtrlSetOnEvent($hTab, "_TabHandler")
    GUICtrlSetOnEvent($hDescEdit, "_DescEditHandler")
    GUICtrlSetOnEvent($hCommentsEdit, "_CommentsEditHandler")
    GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")

    GUISetState(@SW_SHOW)
    _Log("Exiting _CreateGUI")
EndFunc
#EndRegion ;**** GUI Creation Functions ****

#Region ;**** Model Management Functions ****
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
;********************Part 3************************
;**************************************************
#Region Part3
#Region ;**** Separation Functions ****
Func _ProcessDemucs($sSong, $sModel, $sOutputDir)
    _Log("Entering _ProcessDemucs: File=" & $sSong & ", Model=" & $sModel)

    ; Define the full path to Demucs's python.exe
    Local $sPythonPath = @ScriptDir & "\installs\Demucs\demucs_env\Scripts\python.exe"
    If Not FileExists($sPythonPath) Then
        _Log("Python executable not found in Demucs virtual environment: " & $sPythonPath, True)
        MsgBox($MB_ICONERROR, "Error", "Python executable not found at " & $sPythonPath & ". Please ensure the Demucs virtual environment is correctly set up.")
        Return SetError(1, 0, False)
    EndIf

    ; Validate the Python version
    Local $sPythonCheck = Run('"' & $sPythonPath & '" --version', "", @SW_HIDE, $STDOUT_CHILD + $STDERR_MERGED)
    If $sPythonCheck = 0 Then
        _Log("Failed to run Python version check", True)
        MsgBox($MB_ICONERROR, "Error", "Failed to run Python version check for " & $sPythonPath)
        Return SetError(2, 0, False)
    EndIf
    Local $sOutput = "", $sVersionOutput = ""
    While ProcessExists($sPythonCheck)
        $sOutput = StdoutRead($sPythonCheck)
        If Not @error And $sOutput <> "" Then
            $sVersionOutput &= $sOutput
        EndIf
        $sOutput = StderrRead($sPythonCheck)
        If Not @error And $sOutput <> "" Then
            $sVersionOutput &= $sOutput
        EndIf
        Sleep(10)
    WEnd
    ProcessWaitClose($sPythonCheck)
    _Log("Demucs Python version: " & $sVersionOutput)

    ; Ensure output directory exists
    If Not FileExists($sOutputDir) Then
        DirCreate($sOutputDir)
        If Not FileExists($sOutputDir) Then
            _Log("Failed to create output directory: " & $sOutputDir, True)
            MsgBox($MB_ICONERROR, "Error", "Failed to create output directory: " & $sOutputDir)
            Return SetError(3, 0, False)
        EndIf
    EndIf

    ; Create model-specific subdirectory (e.g., htdemucs, htdemucs_6s)
    Local $sModelSubDir = $sOutputDir & "\" & $sModel
    If Not FileExists($sModelSubDir) Then
        DirCreate($sModelSubDir)
        If Not FileExists($sModelSubDir) Then
            _Log("Failed to create model subdirectory: " & $sModelSubDir, True)
            MsgBox($MB_ICONERROR, "Error", "Failed to create model subdirectory: " & $sModelSubDir)
            Return SetError(4, 0, False)
        EndIf
    EndIf

    ; Construct the command using the full path to python.exe
    Local $sCmd
    If $sModel = "htdemucs_2s" Then
        $sCmd = '"' & $sPythonPath & '" -m demucs --two-stems vocals --device cpu -o "' & $sModelSubDir & '" "' & $sSong & '"'
    ElseIf $sModel = "htdemucs_6s" Then
        $sCmd = '"' & $sPythonPath & '" -m demucs -n htdemucs_6s --device cpu -o "' & $sModelSubDir & '" "' & $sSong & '"'
    Else
        $sCmd = '"' & $sPythonPath & '" -m demucs --device cpu -o "' & $sModelSubDir & '" "' & $sSong & '"'
    EndIf

    Local $sLogFile = @ScriptDir & "\logs\demucs_log.txt"
    Local $hLogFile = FileOpen($sLogFile, 2) ; Overwrite mode
    If $hLogFile = -1 Then
        _Log("Failed to open demucs_log.txt for writing", True)
        MsgBox($MB_ICONERROR, "Error", "Failed to open demucs_log.txt for writing")
        Return SetError(7, 0, False)
    EndIf
    _Log("Opened demucs_log.txt for writing")
    FileWrite($hLogFile, "Command: " & $sCmd & @CRLF)

    Local $iPID = Run($sCmd, "", @SW_HIDE, $STDOUT_CHILD + $STDERR_MERGED)
    If $iPID = 0 Then
        _Log("Failed to start Demucs command: " & $sCmd, True)
        FileWrite($hLogFile, "Error: Failed to start Demucs command: " & $sCmd & @CRLF)
        FileClose($hLogFile)
        MsgBox($MB_ICONERROR, "Error", "Failed to start Demucs command. Check log for details.")
        Return SetError(8, 0, False)
    EndIf
    _Log("Started Demucs process with PID: " & $iPID)

    ; Create a Google Blue brush for the progress bar
    Local $hBrushTeal = _GDIPlus_BrushCreateSolid($GOOGLE_BLUE)

    Local $sOutput, $iProgress = 0
    While ProcessExists($iPID)
        $sOutput = StdoutRead($iPID)
        If Not @error And $sOutput <> "" Then
            _Log("[Demucs STDOUT] " & $sOutput)
            FileWrite($hLogFile, "[STDOUT] " & $sOutput)
            ; Parse for progress percentage (e.g., "45% |")
            Local $aMatch = StringRegExp($sOutput, "(\d+)%\s*\|", 1)
            If Not @error Then
                $iProgress = Number($aMatch[0])
                _Log("Progress updated to: " & $iProgress & "%")
                GUICtrlSetData($hProgressLabel, "Task Progress: " & $iProgress & "%")
                _GDIPlus_GraphicsFillRect($hGraphics, 0, 0, ($iGuiWidth - 20) * $iProgress / 100, 20, $hBrushTeal)
            EndIf
        EndIf
        $sOutput = StderrRead($iPID)
        If Not @error And $sOutput <> "" Then
            _Log("[Demucs STDERR] " & $sOutput)
            FileWrite($hLogFile, "[STDERR] " & $sOutput)
        EndIf
        Sleep(100)
    WEnd

    ; Capture any remaining output
    $sOutput = StdoutRead($iPID)
    If Not @error And $sOutput <> "" Then
        _Log("[Demucs STDOUT] " & $sOutput)
        FileWrite($hLogFile, "[STDOUT] " & $sOutput)
    EndIf
    $sOutput = StderrRead($iPID)
    If Not @error And $sOutput <> "" Then
        _Log("[Demucs STDERR] " & $sOutput)
        FileWrite($hLogFile, "[STDERR] " & $sOutput)
    EndIf

    Local $iExitCode = ProcessWaitClose($iPID)
    If $iExitCode <> 0 Then
        _Log("Demucs process exited with non-zero code: " & $iExitCode & ". Output files were generated successfully, but this may indicate a minor issue.", True)
    Else
        _Log("Demucs process exited with code: " & $iExitCode)
    EndIf
    FileWrite($hLogFile, "Process exited with code: " & $iExitCode & @CRLF)
    FileClose($hLogFile)

    ; Clean up the brush
    _GDIPlus_BrushDispose($hBrushTeal)

    ; Check for expected output files
    Local $sOutputPath = $sModelSubDir & "\" & StringRegExpReplace($sSong, "^.*\\", "")
    $sOutputPath = StringRegExpReplace($sOutputPath, "\.[^.]+$", "")
    Local $aExpectedFiles[4] = ["vocals.wav", "drums.wav", "bass.wav", "other.wav"]
    If $sModel = "htdemucs_2s" Then
        Dim $aExpectedFiles[2] = ["vocals.wav", "other.wav"]
    ElseIf $sModel = "htdemucs_6s" Then
        Dim $aExpectedFiles[6] = ["vocals.wav", "drums.wav", "bass.wav", "guitar.wav", "piano.wav", "other.wav"]
    EndIf
    Local $iFound = 0
    For $i = 0 To UBound($aExpectedFiles) - 1
        If FileExists($sOutputPath & "\" & $aExpectedFiles[$i]) Then $iFound += 1
    Next

    If $iFound = UBound($aExpectedFiles) Then
        _Log("Successfully processed " & $sSong & ": found " & $iFound & " output files")
        For $i = 0 To UBound($aExpectedFiles) - 1
            _GUICtrlListView_AddItem($hOutputListView, $sOutputPath & "\" & $aExpectedFiles[$i])
        Next
        Return True
    Else
        _Log("Failed to process " & $sSong & ": expected " & UBound($aExpectedFiles) & " output files, found " & $iFound, True)
        Local $sLogContent = FileRead($sLogFile)
        If StringLen($sLogContent) > 1000 Then
            $sLogContent = StringLeft($sLogContent, 1000) & "... (see full log at " & $sLogFile & ")"
        EndIf
        MsgBox($MB_ICONERROR, "Demucs Error", "Failed to process " & $sSong & ". Expected " & UBound($aExpectedFiles) & " output files, found " & $iFound & "." & @CRLF & @CRLF & "Log Details:" & @CRLF & $sLogContent)
        Return SetError(9, 0, False)
    EndIf
EndFunc

Func _ProcessSpleeter($sSong, $sModel, $sOutputDir)
    _Log("Entering _ProcessSpleeter: File=" & $sSong & ", Model=" & $sModel)

    ; Define the full path to Spleeter's python.exe
    Local $sPythonPath = @ScriptDir & "\installs\Spleeter\spleeter_env\Scripts\python.exe"
    If Not FileExists($sPythonPath) Then
        _Log("Python executable not found in Spleeter virtual environment: " & $sPythonPath, True)
        MsgBox($MB_ICONERROR, "Error", "Python executable not found at " & $sPythonPath & ". Please ensure the Spleeter virtual environment is correctly set up.")
        Return SetError(1, 0, False)
    EndIf

    ; Validate the Python version
    Local $sPythonCheck = Run('"' & $sPythonPath & '" --version', "", @SW_HIDE, $STDOUT_CHILD + $STDERR_MERGED)
    If $sPythonCheck = 0 Then
        _Log("Failed to run Python version check", True)
        MsgBox($MB_ICONERROR, "Error", "Failed to run Python version check for " & $sPythonPath)
        Return SetError(2, 0, False)
    EndIf
    Local $sOutput
    While ProcessExists($sPythonCheck)
        $sOutput &= StdoutRead($sPythonCheck)
        $sOutput &= StderrRead($sPythonCheck)
        Sleep(10)
    WEnd
    ProcessWaitClose($sPythonCheck)
    _Log("Spleeter Python version: " & $sOutput)

    ; Ensure output directory exists
    If Not FileExists($sOutputDir) Then
        DirCreate($sOutputDir)
        If Not FileExists($sOutputDir) Then
            _Log("Failed to create output directory: " & $sOutputDir, True)
            MsgBox($MB_ICONERROR, "Error", "Failed to create output directory: " & $sOutputDir)
            Return SetError(3, 0, False)
        EndIf
    EndIf

    ; Create model-specific subdirectory (e.g., 2stems, 4stems)
    Local $sModelSubDir = $sOutputDir & "\" & $sModel
    If Not FileExists($sModelSubDir) Then
        DirCreate($sModelSubDir)
        If Not FileExists($sModelSubDir) Then
            _Log("Failed to create model subdirectory: " & $sModelSubDir, True)
            MsgBox($MB_ICONERROR, "Error", "Failed to create model subdirectory: " & $sModelSubDir)
            Return SetError(4, 0, False)
        EndIf
    EndIf

    ; Construct the command using the full path to python.exe
    Local $sStemConfig = "spleeter:" & $sModel
    Local $sCmd = '"' & $sPythonPath & '" -m spleeter separate -p ' & $sStemConfig & ' -o "' & $sModelSubDir & '" "' & $sSong & '"'

    Local $sLogFile = @ScriptDir & "\logs\spleeter_log.txt"
    Local $hLogFile = FileOpen($sLogFile, 2) ; Overwrite mode
    If $hLogFile = -1 Then
        _Log("Failed to open spleeter_log.txt for writing", True)
        MsgBox($MB_ICONERROR, "Error", "Failed to open spleeter_log.txt for writing")
        Return SetError(7, 0, False)
    EndIf
    _Log("Opened spleeter_log.txt for writing")
    FileWrite($hLogFile, "Command: " & $sCmd & @CRLF)

    Local $iPID = Run($sCmd, "", @SW_HIDE, $STDOUT_CHILD + $STDERR_MERGED)
    If $iPID = 0 Then
        _Log("Failed to start Spleeter command: " & $sCmd, True)
        FileWrite($hLogFile, "Error: Failed to start Spleeter command: " & $sCmd & @CRLF)
        FileClose($hLogFile)
        MsgBox($MB_ICONERROR, "Error", "Failed to start Spleeter command. Check log for details.")
        Return SetError(8, 0, False)
    EndIf
    _Log("Started Spleeter process with PID: " & $iPID)

    ; Create a Google Blue brush for the progress bar
    Local $hBrushTeal = _GDIPlus_BrushCreateSolid($GOOGLE_BLUE)

    Local $sOutput, $iProgress = 0
    While ProcessExists($iPID)
        $sOutput = StdoutRead($iPID)
        If Not @error And $sOutput <> "" Then
            _Log("[Spleeter STDOUT] " & $sOutput)
            FileWrite($hLogFile, "[STDOUT] " & $sOutput)
            ; Parse for progress percentage (e.g., "45%")
            Local $aMatch = StringRegExp($sOutput, "(\d+)%", 1)
            If Not @error Then
                $iProgress = Number($aMatch[0])
                _Log("Progress updated to: " & $iProgress & "%")
                GUICtrlSetData($hProgressLabel, "Task Progress: " & $iProgress & "%")
                _GDIPlus_GraphicsFillRect($hGraphics, 0, 0, ($iGuiWidth - 20) * $iProgress / 100, 20, $hBrushTeal)
            EndIf
        EndIf
        $sOutput = StderrRead($iPID)
        If Not @error And $sOutput <> "" Then
            _Log("[Spleeter STDERR] " & $sOutput)
            FileWrite($hLogFile, "[STDERR] " & $sOutput)
        EndIf
        Sleep(100)
    WEnd

    ; Capture any remaining output
    $sOutput = StdoutRead($iPID)
    If $sOutput <> "" Then
        _Log("[Spleeter STDOUT] " & $sOutput)
        FileWrite($hLogFile, "[STDOUT] " & $sOutput)
    EndIf
    $sOutput = StderrRead($iPID)
    If $sOutput <> "" Then
        _Log("[Spleeter STDERR] " & $sOutput)
        FileWrite($hLogFile, "[STDERR] " & $sOutput)
    EndIf

    Local $iExitCode = ProcessWaitClose($iPID)
    _Log("Spleeter process exited with code: " & $iExitCode)
    FileWrite($hLogFile, "Process exited with code: " & $iExitCode & @CRLF)
    FileClose($hLogFile)

    ; Clean up the brush
    _GDIPlus_BrushDispose($hBrushTeal)

    ; Check for expected output files
    Local $sFileName = StringRegExpReplace($sSong, "^.*\\", "")
    $sFileName = StringRegExpReplace($sFileName, "\.[^.]+$", "")
    Local $sOutputPath = $sModelSubDir & "\" & $sFileName
    Local $aExpectedFiles[2] = ["vocals.wav", "accompaniment.wav"]
    If $sModel = "4stems" Then
        Dim $aExpectedFiles[4] = ["vocals.wav", "drums.wav", "bass.wav", "other.wav"]
    ElseIf $sModel = "5stems" Then
        Dim $aExpectedFiles[5] = ["vocals.wav", "drums.wav", "bass.wav", "piano.wav", "other.wav"]
    EndIf
    Local $iFound = 0
    For $i = 0 To UBound($aExpectedFiles) - 1
        If FileExists($sOutputPath & "\" & $aExpectedFiles[$i]) Then $iFound += 1
    Next

    If $iFound = UBound($aExpectedFiles) Then
        _Log("Successfully processed " & $sSong & ": found " & $iFound & " output files")
        For $i = 0 To UBound($aExpectedFiles) - 1
            _GUICtrlListView_AddItem($hOutputListView, $sOutputPath & "\" & $aExpectedFiles[$i])
        Next
        Return True
    Else
        _Log("Failed to process " & $sSong & ": expected " & UBound($aExpectedFiles) & " output files, found " & $iFound, True)
        Local $sLogContent = FileRead($sLogFile)
        If StringLen($sLogContent) > 1000 Then
            $sLogContent = StringLeft($sLogContent, 1000) & "... (see full log at " & $sLogFile & ")"
        EndIf
        MsgBox($MB_ICONERROR, "Spleeter Error", "Failed to process " & $sSong & ". Expected " & UBound($aExpectedFiles) & " output files, found " & $iFound & "." & @CRLF & @CRLF & "Log Details:" & @CRLF & $sLogContent)
        Return SetError(9, 0, False)
    EndIf
EndFunc

Func _ProcessUVR5($sSong, $sModel, $sOutputDir)
    _Log("Entering _ProcessUVR5: File=" & $sSong & ", Model=" & $sModel)
    Local $sUVR5Dir = @ScriptDir & "\installs\UVR\uvr_env\Scripts"
    Local $sPythonPath = $sUVR5Dir & "\python.exe"
    Local $sSeparatePy = @ScriptDir & "\installs\UVR\uvr-main\separate.py"
    Local $sWorkingDir = @ScriptDir & "\installs\UVR\uvr-main" ; Match the manual command's directory

    If Not FileExists($sPythonPath) Then
        _Log("Python executable not found in UVR virtual environment: " & $sPythonPath, True)
        MsgBox($MB_ICONERROR, "Error", "Python executable not found at " & $sPythonPath & ". Please ensure the UVR virtual environment is correctly set up.")
        Return SetError(1, 0, False)
    EndIf
    If Not FileExists($sSeparatePy) Then
        _Log("separate.py not found: " & $sSeparatePy, True)
        MsgBox($MB_ICONERROR, "Error", "separate.py not found at " & $sSeparatePy & ". Please ensure the UVR script is in place.")
        Return SetError(2, 0, False)
    EndIf
    _Log("Virtual environment and script found: " & $sPythonPath & ", " & $sSeparatePy)

    ; Get the model path from the database
    Local $sModelPath = _GetModelPath($sModel)
    If $sModelPath = "" Then
        _Log("Failed to retrieve model path for " & $sModel, True)
        MsgBox($MB_ICONERROR, "Error", "Could not find model path for " & $sModel & ". Check models.db or models.ini.")
        Return SetError(3, 0, False)
    EndIf
    _Log("Retrieved raw model path: " & $sModelPath)

    ; Robust path resolution with debugging
    Local $sResolvedPath = $sModelPath
    _Log("Before resolution: " & $sResolvedPath)
    If StringInStr($sResolvedPath, "@ScriptDir") Then
        $sResolvedPath = StringRegExpReplace($sResolvedPath, "@ScriptDir\s*&?\s*", @ScriptDir) ; Handle @ScriptDir & with optional space
        $sResolvedPath = StringReplace($sResolvedPath, "\\", "\") ; Normalize backslashes
    EndIf
    _Log("After resolution: " & $sResolvedPath)

    ; Validate expected path
    Local $sExpectedPath = @ScriptDir & "\installs\models\VR_Models\1_HP-UVR.pth"
    If $sResolvedPath <> $sExpectedPath Then
        _Log("Warning: Resolved path (" & $sResolvedPath & ") does not match expected path (" & $sExpectedPath & ")", True)
    EndIf

    ; Check if the model file exists
    If Not FileExists($sResolvedPath) Then
        _Log("Model file not found at: " & $sResolvedPath, True)
        MsgBox($MB_ICONERROR, "Error", "Model file not found at " & $sResolvedPath & ". Please verify the file exists and the path in models.ini is correct. Expected: " & $sExpectedPath)
        Return SetError(4, 0, False)
    EndIf
    _Log("Model file verified at: " & $sResolvedPath)

    ; Construct the command, ensuring output directory has only one \output
    Local $sOutputPath = $sOutputDir
    If StringRight($sOutputPath, 7) <> "\output" Then $sOutputPath &= "\output"
    Local $sCmd = '"' & $sPythonPath & '" "' & $sSeparatePy & '" --model "' & $sResolvedPath & '" --input_file "' & $sSong & '" --output_dir "' & $sOutputPath & '"'
    _Log("UVR5 command: " & $sCmd)

    Local $sLogFile = @ScriptDir & "\logs\uvr5_log.txt"
    Local $hLogFile = FileOpen($sLogFile, 2) ; Overwrite mode
    If $hLogFile = -1 Then
        _Log("Failed to open uvr5_log.txt for writing", True)
        MsgBox($MB_ICONERROR, "Error", "Failed to open uvr5_log.txt for writing")
        Return SetError(5, 0, False)
    EndIf
    _Log("Opened uvr5_log.txt for writing")
    FileWrite($hLogFile, "Command: " & $sCmd & @CRLF)

    ; Run the command in the correct working directory
    Local $iPID = Run($sCmd, $sWorkingDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_MERGED)
    If $iPID = 0 Then
        _Log("Failed to start UVR5 command: " & $sCmd, True)
        FileWrite($hLogFile, "Error: Failed to start UVR5 command: " & $sCmd & @CRLF)
        FileClose($hLogFile)
        MsgBox($MB_ICONERROR, "Error", "Failed to start UVR5 command. Check log for details.")
        Return SetError(6, 0, False)
    EndIf
    _Log("Started UVR5 process with PID: " & $iPID)

    ; Create a Google Blue brush for the progress bar
    Local $hBrushTeal = _GDIPlus_BrushCreateSolid($GOOGLE_BLUE)

    Local $sOutput, $iProgress = 0, $currentIteration = 0 ; Initialize $currentIteration
    Local $totalIterations = 96 ; Placeholder; adjust based on audio length or model
    While ProcessExists($iPID)
        $sOutput = StdoutRead($iPID)
        If Not @error And $sOutput <> "" Then
            _Log("[UVR5 STDOUT] " & $sOutput)
            FileWrite($hLogFile, "[STDOUT] " & $sOutput)
            ; Parse for progress from tqdm (e.g., "96/96 [07:32<00:00, 4.71s/it]")
            Local $aMatch = StringRegExp($sOutput, "(\d+)/\d+ .*?(\d+\.\d+)s/it", 1)
            If Not @error And UBound($aMatch) >= 1 Then
                $currentIteration = Number($aMatch[0])
                $iProgress = Int(($currentIteration / $totalIterations) * 100)
                If $iProgress > 100 Then $iProgress = 100
                _Log("Progress updated to: " & $iProgress & "%")
                GUICtrlSetData($hProgressLabel, "Task Progress: " & $iProgress & "%")
                _GDIPlus_GraphicsFillRect($hGraphics, 0, 0, ($iGuiWidth - 20) * $iProgress / 100, 20, $hBrushTeal)
            EndIf
        EndIf
        $sOutput = StderrRead($iPID)
        If Not @error And $sOutput <> "" Then
            _Log("[UVR5 STDERR] " & $sOutput)
            FileWrite($hLogFile, "[STDERR] " & $sOutput)
        EndIf
        Sleep(100)
    WEnd

    ; Capture any remaining output
    $sOutput = StdoutRead($iPID)
    If Not @error And $sOutput <> "" Then
        _Log("[UVR5 STDOUT] " & $sOutput)
        FileWrite($hLogFile, "[STDOUT] " & $sOutput)
    EndIf
    $sOutput = StderrRead($iPID)
    If Not @error And $sOutput <> "" Then
        _Log("[UVR5 STDERR] " & $sOutput)
        FileWrite($hLogFile, "[STDERR] " & $sOutput)
    EndIf

    Local $iExitCode = ProcessWaitClose($iPID)
    If $iExitCode <> 0 Then
        _Log("UVR5 process exited with non-zero code: " & $iExitCode & ". Output files were generated successfully, but this may indicate a minor issue.", True)
    Else
        _Log("UVR5 process exited with code: " & $iExitCode)
    EndIf
    FileWrite($hLogFile, "Process exited with code: " & $iExitCode & @CRLF)
    FileClose($hLogFile)

    ; Clean up the brush
    _GDIPlus_BrushDispose($hBrushTeal)

    ; Check for expected output files in the specified output subdirectory
    Local $sOutputPath = $sOutputDir & "\output\" & StringRegExpReplace($sSong, "^.*\\", "")
    $sOutputPath = StringRegExpReplace($sOutputPath, "\.[^.]+$", "")
    Local $aExpectedFiles[2] = ["instruments_" & StringRegExpReplace($sSong, "^.*\\|\.[^.]+$", "") & ".wav", "vocals_" & StringRegExpReplace($sSong, "^.*\\|\.[^.]+$", "") & ".wav"]
    Local $iFound = 0
    For $i = 0 To UBound($aExpectedFiles) - 1
        If FileExists($sOutputPath & "\" & $aExpectedFiles[$i]) Then $iFound += 1
    Next

    If $iFound = 2 Then
        _Log("Successfully processed " & $sSong & ": found " & $iFound & " output files")
        For $i = 0 To UBound($aExpectedFiles) - 1
            _GUICtrlListView_AddItem($hOutputListView, $sOutputPath & "\" & $aExpectedFiles[$i])
        Next
        Return True
    Else
        _Log("Failed to process " & $sSong & ": expected 2 output files, found " & $iFound, True)
        Local $sLogContent = FileRead($sLogFile)
        If StringLen($sLogContent) > 1000 Then
            $sLogContent = StringLeft($sLogContent, 1000) & "... (see full log at " & $sLogFile & ")"
        EndIf
        MsgBox($MB_ICONERROR, "UVR5 Error", "Failed to process " & $sSong & ". Expected 2 output files, found " & $iFound & "." & @CRLF & @CRLF & "Log Details:" & @CRLF & $sLogContent)
        Return SetError(7, 0, False)
    EndIf
EndFunc




Func _ProcessFile($sSong, $sModel, $sOutputDir)
    _Log("Entering _ProcessFile: File=" & $sSong & ", Model=" & $sModel & ", OutputDir=" & $sOutputDir)
    Local $iTabIndex = _GUICtrlTab_GetCurSel($hTab)
    If Not _IsModelCompatibleWithTab($sModel, $iTabIndex) Then
        _Log("Model " & $sModel & " is not compatible with the current tab (index " & $iTabIndex & ")", True)
        MsgBox($MB_ICONERROR, "Error", "Selected model '" & $sModel & "' is not compatible with the current tab.")
        Return False
    EndIf

    Local $bSuccess = False
    Switch $iTabIndex
        Case 0 ; Demucs
            _Log("Processing with Demucs using model: " & $sModel)
            $bSuccess = _ProcessDemucs($sSong, $sModel, $sOutputDir)
        Case 1 ; Spleeter
            _Log("Processing with Spleeter using model: " & $sModel)
            $bSuccess = _ProcessSpleeter($sSong, $sModel, $sOutputDir)
        Case 2 ; UVR5
            _Log("Processing with UVR5 using model: " & $sModel)
            $bSuccess = _ProcessUVR5($sSong, $sModel, $sOutputDir)
        Case Else
            _Log("Invalid tab index for processing: " & $iTabIndex, True)
            Return False
    EndSwitch

    If $bSuccess Then
        _Log("File processed successfully: " & $sSong)
        Return True
    Else
        _Log("Failed to process file: " & $sSong, True)
        Return False
    EndIf
EndFunc

; Helper function to get model path from database
Func _GetModelPath($sModelName)
    _Log("Entering _GetModelPath for model: " & $sModelName)
    Local $sQuery = "SELECT Path FROM Models WHERE Name = '" & StringReplace($sModelName, "'", "''") & "';"
    Local $hQuery, $aRow
    Local $sModelPath = ""
    _SQLite_Query($hDB, $sQuery, $hQuery)
    While _SQLite_FetchData($hQuery, $aRow) = $SQLITE_OK
        $sModelPath = $aRow[0]
        ExitLoop ; Take the first match
    WEnd
    _SQLite_QueryFinalize($hQuery)
    _Log("Retrieved model path: " & $sModelPath)
    Return $sModelPath
EndFunc
#EndRegion ;**** Separation Functions ****
#EndRegion Part3





;**************************************************
;********************Part 4************************
;**************************************************
#Region Part4
#Region ;**** Event Handlers ****
Func _InputButtonHandler()
    _Log("Entering _InputButtonHandler")
    Local $sNewDir = FileSelectFolder("Select Input Directory", "", 7, $sInputPath)
    If @error Then
        _Log("No input directory selected")
        Return
    EndIf
    $sInputPath = $sNewDir
    _Log("Selected input directory: " & $sInputPath)
    IniWrite($sSettingsIni, "Paths", "InputDir", $sInputPath)
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
    _Log("Exiting _InputButtonHandler")
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
        Local $iIndex = _GUICtrlListView_AddItem($hBatchList, $sFile)
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

Func _ManageDbButtonHandler()
    _Log("Entering _ManageDbButtonHandler")
    Local $sExePath = @ScriptDir & "\ModelsDbApp.exe"
    If FileExists($sExePath) Then
        _Log("Launching ModelsDbApp.exe: " & $sExePath)
        ShellExecute($sExePath)
    Else
        _Log("ModelsDbApp.exe not found at: " & $sExePath, True)
        MsgBox($MB_ICONERROR, "Error", "ModelsDbApp.exe not found at " & $sExePath)
    EndIf
    _Log("Exiting _ManageDbButtonHandler")
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
    EndIf

    ; Recreate controls based on the selected tab
    Local $iRightQuadX = ($iGuiWidth - 30) / 2 + 20
    Local $iTopQuadY = 35
    Local $iTabTopY = $iTopQuadY + 30
    Local $iQuadWidth = ($iGuiWidth - 30) / 2
    Local $iDetailsX = $iRightQuadX + 5
    Local $iDetailsY = $iTabTopY + 30
    Local $iDetailsWidth = $iQuadWidth - 10
    Local $iLabelHeight = 20
    Local $iLabelSpacing = 25

    $hModelNameLabel = GUICtrlCreateLabel("Model Name:", $iRightQuadX + 5, $iTabTopY, 70, 20)
    $hModelCombo = GUICtrlCreateCombo("", $iRightQuadX + 80, $iTabTopY, 150, 25, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL, $WS_VSCROLL))
    $hStemsLabel = GUICtrlCreateLabel("Stems:", $iRightQuadX + 235, $iTabTopY, 40, 20)
    $hStemsDisplay = GUICtrlCreateLabel("", $iRightQuadX + 275, $iTabTopY, 30, 20)
    $hFocusLabel = GUICtrlCreateLabel("Focus:", $iDetailsX, $iDetailsY, 80, $iLabelHeight)
    $hFocusDisplay = GUICtrlCreateLabel("", $iDetailsX + 80, $iDetailsY, $iDetailsWidth - 80, $iLabelHeight)
    $hDescLabel = GUICtrlCreateLabel("Description:", $iDetailsX, $iDetailsY + $iLabelSpacing, 80, $iLabelHeight)
    $hDescEdit = GUICtrlCreateEdit("", $iDetailsX, $iDetailsY + $iLabelSpacing + 20, $iDetailsWidth, 80, BitOR($ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL))
    $hCommentsLabel = GUICtrlCreateLabel("Comments:", $iDetailsX, $iDetailsY + $iLabelSpacing * 2 + 80, 80, $iLabelHeight)
    $hCommentsEdit = GUICtrlCreateEdit("", $iDetailsX, $iDetailsY + $iLabelSpacing * 2 + 100, $iDetailsWidth, 80, BitOR($ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL))

    ; Set event handlers for the new controls
    GUICtrlSetOnEvent($hModelCombo, "_ModelComboHandler")
    GUICtrlSetOnEvent($hDescEdit, "_DescEditHandler")
    GUICtrlSetOnEvent($hCommentsEdit, "_CommentsEditHandler")

    ; Populate the combo box
    _UpdateModelDroplist()

    ; Set the default model for the current tab
    Local $sDefaultModel
    Switch $iTabIndex
        Case 0
            $sDefaultModel = "htdemucs"
        Case 1
            $sDefaultModel = "2stems"
        Case 2
            $sDefaultModel = "UVR-MDX-NET-Inst_Main" ; Set a default UVR5 model
    EndSwitch

    If $sDefaultModel <> "" Then
        Local $aDetails = _GetModelDetails($sDefaultModel)
        If Not @error And _IsModelCompatibleWithTab($sDefaultModel, $iTabIndex) Then
            _Log("Setting default model for tab " & $iTabIndex & ": " & $sDefaultModel)
            GUICtrlSetData($hModelCombo, $sDefaultModel)
            Local $sSelectedModel = GUICtrlRead($hModelCombo)
            If $sSelectedModel = $sDefaultModel Then
                _Log("Default model " & $sDefaultModel & " set successfully")
                _UpdateModelDetails($sDefaultModel)
            Else
                _Log("Failed to set default model " & $sDefaultModel & ", current selection: " & $sSelectedModel, True)
                _UpdateModelDetails("")
            EndIf
        Else
            _Log("Default model " & $sDefaultModel & " not found or not compatible with tab " & $iTabIndex & ", selecting first available", True)
            Local $sFirstModel = StringSplit(GUICtrlRead($hModelCombo), "|")[2] ; First model after the leading "|"
            If $sFirstModel <> "" And $sFirstModel <> "No models available" Then
                _Log("Falling back to first available model: " & $sFirstModel)
                GUICtrlSetData($hModelCombo, $sFirstModel)
                Local $sSelectedModel = GUICtrlRead($hModelCombo)
                If $sSelectedModel = $sFirstModel Then
                    _UpdateModelDetails($sFirstModel)
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

    _Log("Exiting _TabHandler")
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
    _GDIPlus_BrushDispose($hBrushGray)
    _GDIPlus_BrushDispose($hBrushGreen)
    _GDIPlus_BrushDispose($hBrushYellow)
    _GDIPlus_PenDispose($hPen)
    _GDIPlus_GraphicsDispose($hGraphics)
    _WinAPI_ReleaseDC($hGraphicGUI, $hDC)
    _GDIPlus_Shutdown()
    _SQLite_Close($hDb)
    _SQLite_Shutdown()
    _Log("Exiting application")
    Exit
EndFunc
#EndRegion ;**** Event Handlers ****
#EndRegion Part4





