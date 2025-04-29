#include <SQLite.au3>
#include <File.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <GuiListView.au3>
#include <GuiMenu.au3>
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <ComboConstants.au3>
#include <GuiToolbar.au3>
#include <GuiStatusBar.au3>
#include <GuiEdit.au3>
#include <Array.au3>

#Region ;**** Global Variables ****
Global $sIniFile = @ScriptDir & "\models.ini"
Global $sDbFile = @ScriptDir & "\models.db"
Global $sLogFile = ""
Global $hDb, $hGUI, $hTableCombo, $hListView, $hSearchInput, $hFilterAppCombo, $hFilterStemsCombo
Global $hModelIDInput, $hNameInput, $hPathInput, $hDescInput, $hCommentsInput, $hCmdInput
Global $hAppInput, $hFocusInput, $hStemsInput
Global $hFirstButton, $hPrevButton, $hNextButton, $hLastButton, $hEditButton, $hSaveButton, $hCancelButton
Global $hToolbar, $hStatusBar, $hContextMenu
Global $bDarkTheme = True, $bEditMode = False
Global $iCurrentIndex = -1, $aListViewData[0][0]
Global Enum $idCopyRow, $idExportCSV, $idOpenPath
Global $bHasModelApps = False, $bHasModelFocuses = False
Global $aLabels[0] ; Array to store label handles for theming
#EndRegion ;**** Global Variables ****

#Region ;**** Logging Function ****
Func _Log($sMessage, $bError = False)
    Local $sLogDir = @ScriptDir & "\logs"
    If Not FileExists($sLogDir) Then DirCreate($sLogDir)
    Local $sTimestamp = @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC
    If $sLogFile = "" Then
        $sLogFile = $sLogDir & "\ModelBrowser_" & $sTimestamp & ".log"
    EndIf
    Local $sPrefix = $bError ? "ERROR: " : "INFO: "
    Local $sHour = (@HOUR > 12) ? @HOUR - 12 : (@HOUR = 0 ? 12 : @HOUR)
    Local $sAmPm = (@HOUR >= 12) ? "PM" : "AM"
    Local $sLogMessage = "[" & @MON & "/" & @MDAY & "/" & @YEAR & " " & $sHour & ":" & @MIN & ":" & @SEC & " " & $sAmPm & "] " & $sPrefix & $sMessage & @CRLF
    FileWrite($sLogFile, $sLogMessage)
    ConsoleWrite($sLogMessage)
EndFunc
#EndRegion ;**** Logging Function ****

#Region ;**** Database Creation ****
Func _CreateDatabase()
    _Log("Starting database creation")
    _SQLite_Startup()
    If @error Then
        _Log("Failed to start SQLite: Error " & @error, True)
        Exit
    EndIf
    _Log("SQLite started")
    If FileExists($sDbFile) Then FileDelete($sDbFile)
    $hDb = _SQLite_Open($sDbFile)
    If @error Then
        _Log("Failed to open/create database: " & _SQLite_ErrMsg(), True)
        _SQLite_Shutdown()
        Exit
    EndIf
    _Log("Database opened: " & $sDbFile)
    Local $sQuery
    $sQuery = "CREATE TABLE IF NOT EXISTS Models (" & _
              "ModelID INTEGER PRIMARY KEY, " & _
              "Name TEXT, " & _
              "Path TEXT, " & _
              "Description TEXT, " & _
              "Comments TEXT, " & _
              "CommandLine TEXT);"
    _SQLite_Exec($hDb, $sQuery)
    If @error Then
        _Log("Failed to create Models table: " & _SQLite_ErrMsg(), True)
        _SQLite_Close($hDb)
        _SQLite_Shutdown()
        Exit
    EndIf
    _Log("Models table created")
    $sQuery = "CREATE TABLE IF NOT EXISTS ModelApps (" & _
              "ModelID INTEGER, " & _
              "App TEXT, " & _
              "FOREIGN KEY(ModelID) REFERENCES Models(ModelID));"
    _SQLite_Exec($hDb, $sQuery)
    If @error Then
        _Log("Failed to create ModelApps table: " & _SQLite_ErrMsg(), True)
        _SQLite_Close($hDb)
        _SQLite_Shutdown()
        Exit
    EndIf
    _Log("ModelApps table created")
    $sQuery = "CREATE TABLE IF NOT EXISTS ModelFocuses (" & _
              "ModelID INTEGER, " & _
              "Focus TEXT, " & _
              "Stems INTEGER, " & _
              "FOREIGN KEY(ModelID) REFERENCES Models(ModelID));"
    _SQLite_Exec($hDb, $sQuery)
    If @error Then
        _Log("Failed to create ModelFocuses table: " & _SQLite_ErrMsg(), True)
        _SQLite_Close($hDb)
        _SQLite_Shutdown()
        Exit
    EndIf
    _Log("ModelFocuses table created")
    Local $aSections = IniReadSectionNames($sIniFile)
    If @error Then
        _Log("Failed to read ini file: " & $sIniFile, True)
        _SQLite_Close($hDb)
        _SQLite_Shutdown()
        Exit
    EndIf
    _Log("Found " & $aSections[0] & " sections in ini file")
    For $i = 1 To $aSections[0]
        Local $sSection = $aSections[$i]
        Local $iModelID = StringReplace($sSection, "Model_", "")
        Local $sApp = IniRead($sIniFile, $sSection, "App", "")
        Local $sName = IniRead($sIniFile, $sSection, "Name", "")
        Local $sFocus = IniRead($sIniFile, $sSection, "Focus", "")
        Local $iStems = IniRead($sIniFile, $sSection, "Stems", 0)
        Local $sPath = IniRead($sIniFile, $sSection, "Path", "")
        Local $sDescription = IniRead($sIniFile, $sSection, "Description", "")
        Local $sComments = IniRead($sIniFile, $sSection, "Comments", "")
        Local $sCommandLine = IniRead($sIniFile, $sSection, "CommandLine", "")
        $sName = StringReplace($sName, "'", "''")
        $sPath = StringReplace($sPath, "'", "''")
        $sDescription = StringReplace($sDescription, "'", "''")
        $sComments = StringReplace($sComments, "'", "''")
        $sCommandLine = StringReplace($sCommandLine, "'", "''")
        $sApp = StringReplace($sApp, "'", "''")
        $sFocus = StringReplace($sFocus, "'", "''")
        $sQuery = "INSERT INTO Models (ModelID, Name, Path, Description, Comments, CommandLine) " & _
                  "VALUES (" & $iModelID & ", '" & $sName & "', '" & $sPath & "', '" & $sDescription & "', '" & $sComments & "', '" & $sCommandLine & "');"
        _SQLite_Exec($hDb, $sQuery)
        If @error Then
            _Log("Failed to insert into Models for ModelID " & $iModelID & ": " & _SQLite_ErrMsg(), True)
            ContinueLoop
        EndIf
        _Log("Inserted ModelID " & $iModelID & " into Models")
        If $sApp <> "" Then
            $sQuery = "INSERT INTO ModelApps (ModelID, App) VALUES (" & $iModelID & ", '" & $sApp & "');"
            _SQLite_Exec($hDb, $sQuery)
            If @error Then
                _Log("Failed to insert into ModelApps for ModelID " & $iModelID & ": " & _SQLite_ErrMsg(), True)
                ContinueLoop
            EndIf
            _Log("Inserted ModelID " & $iModelID & " into ModelApps")
        EndIf
        If $sFocus <> "" Then
            $sQuery = "INSERT INTO ModelFocuses (ModelID, Focus, Stems) VALUES (" & $iModelID & ", '" & $sFocus & "', " & $iStems & ");"
            _SQLite_Exec($hDb, $sQuery)
            If @error Then
                _Log("Failed to insert into ModelFocuses for ModelID " & $iModelID & ": " & _SQLite_ErrMsg(), True)
                ContinueLoop
            EndIf
            _Log("Inserted ModelID " & $iModelID & " into ModelFocuses")
        EndIf
    Next
    _Log("Database creation completed")
EndFunc
#EndRegion ;**** Database Creation ****

#Region ;**** GUI Creation ****
Func _CreateGUI()
    _Log("Creating GUI")
    $hGUI = GUICreate("Model Database Browser", 1200, 800, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU, $WS_SIZEBOX, $WS_MAXIMIZEBOX))
    GUISetFont(12, 400, 0, "Segoe UI")

    $hToolbar = _GUICtrlToolbar_Create($hGUI)
    _GUICtrlToolbar_AddButton($hToolbar, 1000, 22, "Refresh")
    _GUICtrlToolbar_AddButton($hToolbar, 1001, 24, "Export CSV")
    _GUICtrlToolbar_AddButtonSep($hToolbar)
    _GUICtrlToolbar_AddButton($hToolbar, 1002, 26, "Toggle Theme")

    $hStatusBar = _GUICtrlStatusBar_Create($hGUI)
    _GUICtrlStatusBar_SetSimple($hStatusBar, True)
    _GUICtrlStatusBar_SetText($hStatusBar, "Ready")

    $hTableCombo = GUICtrlCreateCombo("", 10, 40, 180, 30, $CBS_DROPDOWNLIST)
    GUICtrlSetData($hTableCombo, "Models|ModelApps|ModelFocuses", "Models")
    GUICtrlSetTip($hTableCombo, "Select table to view")
    Local $hSearchLabel = GUICtrlCreateLabel("Search:", 200, 45, 50, 25)
    $hSearchInput = GUICtrlCreateInput("", 250, 40, 200, 30)
    GUICtrlSetTip($hSearchInput, "Search across all fields (Ctrl+F)")
    Local $hAppFilterLabel = GUICtrlCreateLabel("App Filter:", 460, 45, 70, 25)
    $hFilterAppCombo = GUICtrlCreateCombo("", 530, 40, 150, 30, $CBS_DROPDOWNLIST)
    GUICtrlSetTip($hFilterAppCombo, "Filter by application")
    Local $hStemsFilterLabel = GUICtrlCreateLabel("Stems Filter:", 690, 45, 80, 25)
    $hFilterStemsCombo = GUICtrlCreateCombo("", 770, 40, 100, 30, $CBS_DROPDOWNLIST)
    GUICtrlSetTip($hFilterStemsCombo, "Filter by stems count")

    $hListView = GUICtrlCreateListView("", 10, 80, 1180, 400, $LVS_REPORT)
    _GUICtrlListView_SetExtendedListViewStyle($hListView, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_DOUBLEBUFFER))

    $hFirstButton = GUICtrlCreateButton("First", 10, 490, 80, 30)
    $hPrevButton = GUICtrlCreateButton("Previous", 100, 490, 80, 30)
    $hNextButton = GUICtrlCreateButton("Next", 190, 490, 80, 30)
    $hLastButton = GUICtrlCreateButton("Last", 280, 490, 80, 30)
    $hEditButton = GUICtrlCreateButton("Edit", 370, 490, 80, 30)
    $hSaveButton = GUICtrlCreateButton("Save", 460, 490, 80, 30)
    $hCancelButton = GUICtrlCreateButton("Cancel", 550, 490, 80, 30)
    GUICtrlSetState($hSaveButton, $GUI_DISABLE)
    GUICtrlSetState($hCancelButton, $GUI_DISABLE)

    Local $iLabelX = 10, $iInputX = 120, $iYStart = 530, $iSpacing = 60
    Local $hModelIDLabel = GUICtrlCreateLabel("ModelID:", $iLabelX, $iYStart, 100, 25)
    $hModelIDInput = GUICtrlCreateInput("", $iInputX, $iYStart - 5, 100, 30, $ES_READONLY)

    Local $hNameLabel = GUICtrlCreateLabel("Name:", $iLabelX, $iYStart + $iSpacing, 100, 25)
    $hNameInput = GUICtrlCreateEdit("", $iInputX, $iYStart + $iSpacing - 5, 300, 50, BitOR($ES_READONLY, $ES_AUTOVSCROLL, $WS_VSCROLL))

    Local $hAppLabel = GUICtrlCreateLabel("App:", $iLabelX, $iYStart + $iSpacing * 2, 100, 25)
    $hAppInput = GUICtrlCreateInput("", $iInputX, $iYStart + $iSpacing * 2 - 5, 200, 30, $ES_READONLY)

    Local $hPathLabel = GUICtrlCreateLabel("Path:", $iLabelX, $iYStart + $iSpacing * 3, 100, 25)
    $hPathInput = GUICtrlCreateEdit("", $iInputX, $iYStart + $iSpacing * 3 - 5, 1050, 50, BitOR($ES_READONLY, $ES_AUTOVSCROLL, $WS_VSCROLL))

    Local $hDescLabel = GUICtrlCreateLabel("Description:", $iLabelX, $iYStart + $iSpacing * 4, 100, 25)
    $hDescInput = GUICtrlCreateEdit("", $iInputX, $iYStart + $iSpacing * 4 - 5, 1050, 50, BitOR($ES_READONLY, $ES_AUTOVSCROLL, $WS_VSCROLL))

    Local $hCommentsLabel = GUICtrlCreateLabel("Comments:", $iLabelX, $iYStart + $iSpacing * 5, 100, 25)
    $hCommentsInput = GUICtrlCreateEdit("", $iInputX, $iYStart + $iSpacing * 5 - 5, 1050, 50, BitOR($ES_READONLY, $ES_AUTOVSCROLL, $WS_VSCROLL))

    Local $hCmdLabel = GUICtrlCreateLabel("CommandLine:", $iLabelX, $iYStart + $iSpacing * 6, 100, 25)
    $hCmdInput = GUICtrlCreateEdit("", $iInputX, $iYStart + $iSpacing * 6 - 5, 1050, 50, BitOR($ES_READONLY, $ES_AUTOVSCROLL, $WS_VSCROLL))

    Local $hFocusLabel = GUICtrlCreateLabel("Focus:", $iLabelX, $iYStart + $iSpacing * 7, 100, 25)
    $hFocusInput = GUICtrlCreateEdit("", $iInputX, $iYStart + $iSpacing * 7 - 5, 450, 50, BitOR($ES_READONLY, $ES_AUTOVSCROLL, $WS_VSCROLL))

    Local $hStemsLabel = GUICtrlCreateLabel("Stems:", $iLabelX, $iYStart + $iSpacing * 8, 100, 25)
    $hStemsInput = GUICtrlCreateInput("", $iInputX, $iYStart + $iSpacing * 8 - 5, 100, 30, $ES_READONLY)

    $hContextMenu = GUICtrlCreateContextMenu($hListView)
    GUICtrlCreateMenuItem("Copy Row", $hContextMenu, $idCopyRow)
    GUICtrlCreateMenuItem("Export Table to CSV", $hContextMenu, $idExportCSV)
    GUICtrlCreateMenuItem("Open Path in Explorer", $hContextMenu, $idOpenPath)

    ; Store labels in an array for theme application (compatible with AutoIt 3.3.16.1)
    ReDim $aLabels[12]
    $aLabels[0] = $hSearchLabel
    $aLabels[1] = $hAppFilterLabel
    $aLabels[2] = $hStemsFilterLabel
    $aLabels[3] = $hModelIDLabel
    $aLabels[4] = $hNameLabel
    $aLabels[5] = $hAppLabel
    $aLabels[6] = $hPathLabel
    $aLabels[7] = $hDescLabel
    $aLabels[8] = $hCommentsLabel
    $aLabels[9] = $hCmdLabel
    $aLabels[10] = $hFocusLabel
    $aLabels[11] = $hStemsLabel

    GUISetState(@SW_SHOW)
    _ApplyTheme() ; Moved to after GUISetState to ensure all controls are created
    _Log("GUI displayed")
EndFunc
#EndRegion ;**** GUI Creation ****

#Region ;**** Theme Functions ****
Func _ApplyTheme()
    Local $iBgColor = $bDarkTheme ? 0x2D2D2D : 0xFFFFFF
    Local $iTextColor = $bDarkTheme ? 0xFFFFFF : 0x000000
    Local $iInputBg = $bDarkTheme ? 0x3C3C3C : 0xF0F0F0
    GUISetBkColor($iBgColor)

    ; Disable Windows theming to ensure custom colors apply (Windows 11 compatibility)
    DllCall("uxtheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($hListView), "wstr", "", "wstr", "")
    DllCall("uxtheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($hTableCombo), "wstr", "", "wstr", "")
    DllCall("uxtheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($hFilterAppCombo), "wstr", "", "wstr", "")
    DllCall("uxtheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($hFilterStemsCombo), "wstr", "", "wstr", "")

    Local $aControls = [$hTableCombo, $hSearchInput, $hFilterAppCombo, $hFilterStemsCombo, _
                        $hModelIDInput, $hNameInput, $hPathInput, $hDescInput, $hCommentsInput, _
                        $hCmdInput, $hAppInput, $hFocusInput, $hStemsInput]
    For $hCtrl In $aControls
        DllCall("uxtheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($hCtrl), "wstr", "", "wstr", "")
        GUICtrlSetBkColor($hCtrl, $iInputBg)
        GUICtrlSetColor($hCtrl, $iTextColor)
    Next

    Local $aButtons = [$hFirstButton, $hPrevButton, $hNextButton, $hLastButton, $hEditButton, $hSaveButton, $hCancelButton]
    For $hBtn In $aButtons
        DllCall("uxtheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($hBtn), "wstr", "", "wstr", "")
        GUICtrlSetBkColor($hBtn, $bDarkTheme ? 0x4CAF50 : 0x34C759)
        GUICtrlSetColor($hBtn, 0xFFFFFF)
    Next

    ; Use list view-specific functions for background and text color
    _GUICtrlListView_SetBkColor($hListView, $iInputBg)
    _GUICtrlListView_SetTextBkColor($hListView, $iInputBg)
    _GUICtrlListView_SetTextColor($hListView, $iTextColor)

    _GUICtrlStatusBar_SetBkColor($hStatusBar, $iBgColor)
    ; Apply theme to labels
    For $hLabel In $aLabels
        GUICtrlSetColor($hLabel, $iTextColor)
    Next
    _Log("Theme applied: " & ($bDarkTheme ? "Dark" : "Light"))
EndFunc

Func _ToggleTheme()
    $bDarkTheme = Not $bDarkTheme
    _ApplyTheme()
    _GUICtrlStatusBar_SetText($hStatusBar, "Theme switched to " & ($bDarkTheme ? "Dark" : "Light"))
EndFunc
#EndRegion ;**** Theme Functions ****

#Region ;**** Database Functions ****
Func _CheckTables()
    _Log("Checking database tables")
    Local $aResult, $iRows, $iCols
    _SQLite_GetTable2d($hDb, "SELECT name FROM sqlite_master WHERE type='table';", $aResult, $iRows, $iCols)
    If @error Then
        _Log("Failed to check tables: " & _SQLite_ErrMsg(), True)
        Return
    EndIf
    $bHasModelApps = False
    $bHasModelFocuses = False
    For $i = 1 To $iRows
        If $aResult[$i][0] = "ModelApps" Then $bHasModelApps = True
        If $aResult[$i][0] = "ModelFocuses" Then $bHasModelFocuses = True
    Next
    ; Enable/disable filter combos based on table existence
    If $bHasModelApps Then
        GUICtrlSetState($hFilterAppCombo, $GUI_ENABLE)
    Else
        GUICtrlSetState($hFilterAppCombo, $GUI_DISABLE)
    EndIf
    If $bHasModelFocuses Then
        GUICtrlSetState($hFilterStemsCombo, $GUI_ENABLE)
    Else
        GUICtrlSetState($hFilterStemsCombo, $GUI_DISABLE)
    EndIf
    _Log("ModelApps table: " & ($bHasModelApps ? "Found" : "Not found"))
    _Log("ModelFocuses table: " & ($bHasModelFocuses ? "Found" : "Not found"))
EndFunc

Func _InitDatabase()
    _Log("Initializing database indices")
    _SQLite_Exec($hDb, "CREATE INDEX IF NOT EXISTS idx_models_id ON Models(ModelID);")
    If @error Then
        _Log("Failed to create Models index: " & _SQLite_ErrMsg(), True)
    EndIf
    _SQLite_Exec($hDb, "CREATE INDEX IF NOT EXISTS idx_modelapps_id ON ModelApps(ModelID);")
    If @error Then
        _Log("Failed to create ModelApps index: " & _SQLite_ErrMsg(), True)
    EndIf
    _SQLite_Exec($hDb, "CREATE INDEX IF NOT EXISTS idx_modelfocuses_id ON ModelFocuses(ModelID);")
    If @error Then
        _Log("Failed to create ModelFocuses index: " & _SQLite_ErrMsg(), True)
    EndIf
    _Log("Database indices created")
EndFunc

Func _LoadTableData($sTable, $sSearch = "", $sAppFilter = "", $iStemsFilter = -1)
    _Log("Loading data for table: " & $sTable)
    _GUICtrlListView_DeleteAllItems($hListView)
    _GUICtrlListView_DeleteAllItems(GUICtrlGetHandle($hListView))
    $iCurrentIndex = -1
    ReDim $aListViewData[0][0]

    Local $sQuery, $aHeaders
    Switch $sTable
        Case "Models"
            $sQuery = "SELECT m.ModelID, m.Name, m.Path, m.Description, m.Comments, m.CommandLine, ma.App " & _
                      "FROM Models m LEFT JOIN ModelApps ma ON m.ModelID = ma.ModelID ORDER BY m.ModelID;" ; Fixed ORDER BY
            $aHeaders = StringSplit("ModelID|Name|Path|Description|Comments|CommandLine|App", "|", 2)
        Case "ModelApps"
            $sQuery = "SELECT ModelID, App FROM ModelApps ORDER BY ModelID;" ; Added ORDER BY for consistency
            $aHeaders = StringSplit("ModelID|App", "|", 2)
        Case "ModelFocuses"
            $sQuery = "SELECT ModelID, Focus, Stems FROM ModelFocuses ORDER BY ModelID;" ; Added ORDER BY for consistency
            $aHeaders = StringSplit("ModelID|Focus|Stems", "|", 2)
    EndSwitch

    Local $sWhere = ""
    If $sSearch <> "" Then
        $sSearch = StringReplace($sSearch, "'", "''")
        Local $aFields
        If $sTable = "Models" Then
            Local $sFields = "m.ModelID,m.Name,m.Path,m.Description,m.Comments,m.CommandLine,ma.App"
            $aFields = StringSplit($sFields, ",", 2)
        ElseIf $sTable = "ModelApps" Then
            Local $sFields = "ModelID,App"
            $aFields = StringSplit($sFields, ",", 2)
        Else
            Local $sFields = "ModelID,Focus,Stems"
            $aFields = StringSplit($sFields, ",", 2)
        EndIf
        Local $aConditions[0]
        For $sField In $aFields
            ReDim $aConditions[UBound($aConditions) + 1]
            $aConditions[UBound($aConditions) - 1] = $sField & " LIKE '%" & $sSearch & "%'"
        Next
        $sWhere &= ($sWhere = "" ? " WHERE " : " AND ") & "(" & _ArrayToString($aConditions, " OR ") & ")"
    EndIf
    If $sAppFilter <> "" And $sTable = "Models" Then
        $sAppFilter = StringReplace($sAppFilter, "'", "''")
        $sWhere &= ($sWhere = "" ? " WHERE " : " AND ") & "ma.App = '" & $sAppFilter & "'"
    ElseIf $sAppFilter <> "" And $sTable = "ModelApps" Then
        $sAppFilter = StringReplace($sAppFilter, "'", "''")
        $sWhere &= ($sWhere = "" ? " WHERE " : " AND ") & "App = '" & $sAppFilter & "'"
    EndIf
    If $iStemsFilter >= 0 And $sTable = "ModelFocuses" Then
        $sWhere &= ($sWhere = "" ? " WHERE " : " AND ") & "Stems = " & $iStemsFilter
    EndIf
    $sQuery = StringReplace($sQuery, "ORDER BY", $sWhere & " ORDER BY") ; Insert WHERE clause before ORDER BY

    For $i = _GUICtrlListView_GetColumnCount($hListView) - 1 To 0 Step -1
        _GUICtrlListView_DeleteColumn($hListView, $i)
    Next
    Local $aWidths
    If $sTable = "Models" Then
        Dim $aWidths[7] = [80, 150, 250, 300, 300, 400, 100]
    ElseIf $sTable = "ModelApps" Then
        Dim $aWidths[2] = [80, 200]
    Else
        Dim $aWidths[3] = [80, 300, 80]
    EndIf
    For $i = 0 To UBound($aHeaders) - 1
        _GUICtrlListView_AddColumn($hListView, $aHeaders[$i], $aWidths[$i])
    Next

    Local $aResult, $iRows, $iCols
    _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If @error Then
        _Log("Failed to load table " & $sTable & ": " & _SQLite_ErrMsg(), True)
        _GUICtrlStatusBar_SetText($hStatusBar, "Error loading data")
        Return
    EndIf

    ReDim $aListViewData[$iRows][$iCols]
    For $i = 1 To $iRows
        _GUICtrlListView_AddItem($hListView, $aResult[$i][0])
        For $j = 0 To $iCols - 1
            $aListViewData[$i - 1][$j] = $aResult[$i][$j]
            If $j > 0 Then
                _GUICtrlListView_AddSubItem($hListView, $i - 1, $aResult[$i][$j] <> "" ? $aResult[$i][$j] : "N/A", $j)
            EndIf
        Next
    Next
    _GUICtrlStatusBar_SetText($hStatusBar, "Loaded " & $iRows & " records")
    _Log("Loaded " & $iRows & " rows into ListView for table " & $sTable)

    _UpdateFilterCombos()
EndFunc

Func _UpdateFilterCombos()
    _Log("Updating filter combos")
    If $bHasModelApps Then
        Local $aApps, $iRows, $iCols
        _SQLite_GetTable2d($hDb, "SELECT DISTINCT App FROM ModelApps WHERE App IS NOT NULL ORDER BY App;", $aApps, $iRows, $iCols)
        If @error Then
            _Log("Failed to query ModelApps for filter: " & _SQLite_ErrMsg(), True)
        ElseIf $iRows > 0 Then
            Local $sAppList = "|All"
            For $i = 1 To $iRows
                $sAppList &= "|" & $aApps[$i][0]
            Next
            GUICtrlSetData($hFilterAppCombo, $sAppList, "All")
            _Log("Updated App filter with " & $iRows & " entries")
        Else
            _Log("No App entries found in ModelApps", True)
            GUICtrlSetData($hFilterAppCombo, "|All", "All")
        EndIf
    Else
        GUICtrlSetData($hFilterAppCombo, "|All", "All")
        _Log("ModelApps table not available, App filter disabled")
    EndIf

    If $bHasModelFocuses Then
        Local $aStems, $iRows, $iCols
        _SQLite_GetTable2d($hDb, "SELECT DISTINCT Stems FROM ModelFocuses WHERE Stems IS NOT NULL ORDER BY Stems;", $aStems, $iRows, $iCols)
        If @error Then
            _Log("Failed to query ModelFocuses for filter: " & _SQLite_ErrMsg(), True)
        ElseIf $iRows > 0 Then
            Local $sStemsList = "|All"
            For $i = 1 To $iRows
                $sStemsList &= "|" & $aStems[$i][0]
            Next
            GUICtrlSetData($hFilterStemsCombo, $sStemsList, "All")
            _Log("Updated Stems filter with " & $iRows & " entries")
        Else
            _Log("No Stems entries found in ModelFocuses", True)
            GUICtrlSetData($hFilterStemsCombo, "|All", "All")
        EndIf
    Else
        GUICtrlSetData($hFilterStemsCombo, "|All", "All")
        _Log("ModelFocuses table not available, Stems filter disabled")
    EndIf
    _Log("Filter combos update completed")
EndFunc

Func _PopulateFields($iIndex)
    _Log("Populating fields for index: " & $iIndex)
    If $iIndex < 0 Or $iIndex >= UBound($aListViewData) Then
        _Log("Invalid index for populating fields", True)
        Return
    EndIf
    $iCurrentIndex = $iIndex
    _GUICtrlListView_SetItemSelected($hListView, $iIndex, True, True)
    _GUICtrlListView_EnsureVisible($hListView, $iIndex)

    Local $sTable = GUICtrlRead($hTableCombo)
    Local $sModelID = $aListViewData[$iIndex][0]

    Local $aFields = [$hModelIDInput, $hNameInput, $hPathInput, $hDescInput, $hCommentsInput, $hCmdInput, $hAppInput, $hFocusInput, $hStemsInput]
    For $hField In $aFields
        GUICtrlSetData($hField, "")
    Next

    GUICtrlSetData($hModelIDInput, $sModelID)
    Switch $sTable
        Case "Models"
            GUICtrlSetData($hNameInput, $aListViewData[$iIndex][1])
            GUICtrlSetData($hPathInput, $aListViewData[$iIndex][2])
            GUICtrlSetData($hDescInput, $aListViewData[$iIndex][3])
            GUICtrlSetData($hCommentsInput, $aListViewData[$iIndex][4])
            GUICtrlSetData($hCmdInput, $aListViewData[$iIndex][5])
            GUICtrlSetData($hAppInput, $aListViewData[$iIndex][6])
        Case "ModelApps"
            GUICtrlSetData($hAppInput, $aListViewData[$iIndex][1])
        Case "ModelFocuses"
            GUICtrlSetData($hFocusInput, $aListViewData[$iIndex][1])
            GUICtrlSetData($hStemsInput, $aListViewData[$iIndex][2])
    EndSwitch
    _GUICtrlStatusBar_SetText($hStatusBar, "Viewing ModelID: " & $sModelID)
    _Log("Populated fields for ModelID: " & $sModelID & " in table: " & $sTable)
EndFunc

Func _EnableEditMode($bEnable)
    _Log("Setting edit mode: " & ($bEnable ? "Enabled" : "Disabled"))
    $bEditMode = $bEnable
    Local $iStyle = $bEnable ? 0 : $ES_READONLY
    Local $aFields = [$hNameInput, $hPathInput, $hDescInput, $hCommentsInput, $hCmdInput, $hAppInput, $hFocusInput, $hStemsInput]
    For $hField In $aFields
        GUICtrlSetStyle($hField, BitOR($iStyle, $ES_AUTOVSCROLL, $WS_VSCROLL))
    Next
    GUICtrlSetState($hEditButton, $bEnable ? $GUI_DISABLE : $GUI_ENABLE)
    GUICtrlSetState($hSaveButton, $bEnable ? $GUI_ENABLE : $GUI_DISABLE)
    GUICtrlSetState($hCancelButton, $bEnable ? $GUI_ENABLE : $GUI_DISABLE)
    _GUICtrlStatusBar_SetText($hStatusBar, $bEnable ? "Edit mode enabled" : "Edit mode disabled")
EndFunc

Func _SaveChanges()
    _Log("Attempting to save changes")
    If $iCurrentIndex < 0 Then
        _Log("No record selected for saving", True)
        Return
    EndIf
    Local $sTable = GUICtrlRead($hTableCombo)
    Local $sModelID = GUICtrlRead($hModelIDInput)
    Local $sQuery

    Switch $sTable
        Case "Models"
            Local $sName = StringReplace(GUICtrlRead($hNameInput), "'", "''")
            Local $sPath = StringReplace(GUICtrlRead($hPathInput), "'", "''")
            Local $sDesc = StringReplace(GUICtrlRead($hDescInput), "'", "''")
            Local $sComments = StringReplace(GUICtrlRead($hCommentsInput), "'", "''")
            Local $sCmd = StringReplace(GUICtrlRead($hCmdInput), "'", "''")
            $sQuery = "UPDATE Models SET Name = '" & $sName & "', Path = '" & $sPath & "', " & _
                      "Description = '" & $sDesc & "', Comments = '" & $sComments & "', " & _
                      "CommandLine = '" & $sCmd & "' WHERE ModelID = " & $sModelID & ";"
            _SQLite_Exec($hDb, $sQuery)
            If @error Then
                _Log("Failed to update Models: " & _SQLite_ErrMsg(), True)
                _GUICtrlStatusBar_SetText($hStatusBar, "Error saving Models")
                Return
            EndIf
            Local $sApp = StringReplace(GUICtrlRead($hAppInput), "'", "''")
            If $sApp <> "" Then
                $sQuery = "INSERT OR REPLACE INTO ModelApps (ModelID, App) VALUES (" & $sModelID & ", '" & $sApp & "');"
                _SQLite_Exec($hDb, $sQuery)
                If @error Then
                    _Log("Failed to update ModelApps: " & _SQLite_ErrMsg(), True)
                    _GUICtrlStatusBar_SetText($hStatusBar, "Error saving App")
                    Return
                EndIf
            Else
                $sQuery = "DELETE FROM ModelApps WHERE ModelID = " & $sModelID & ";"
                _SQLite_Exec($hDb, $sQuery)
                If @error Then
                    _Log("Failed to delete from ModelApps: " & _SQLite_ErrMsg(), True)
                EndIf
            EndIf
        Case "ModelApps"
            Local $sApp = StringReplace(GUICtrlRead($hAppInput), "'", "''")
            $sQuery = "INSERT OR REPLACE INTO ModelApps (ModelID, App) VALUES (" & $sModelID & ", '" & $sApp & "');"
            _SQLite_Exec($hDb, $sQuery)
            If @error Then
                _Log("Failed to save ModelApps: " & _SQLite_ErrMsg(), True)
                _GUICtrlStatusBar_SetText($hStatusBar, "Error saving App")
                Return
            EndIf
        Case "ModelFocuses"
            Local $sFocus = StringReplace(GUICtrlRead($hFocusInput), "'", "''")
            Local $sStems = GUICtrlRead($hStemsInput)
            If Not StringIsInt($sStems) Then
                _GUICtrlStatusBar_SetText($hStatusBar, "Error: Stems must be an integer")
                _Log("Invalid Stems value: " & $sStems, True)
                Return
            EndIf
            $sQuery = "UPDATE ModelFocuses SET Focus = '" & $sFocus & "', Stems = " & $sStems & " WHERE ModelID = " & $sModelID & ";"
            _SQLite_Exec($hDb, $sQuery)
            If @error Then
                _Log("Failed to save ModelFocuses: " & _SQLite_ErrMsg(), True)
                _GUICtrlStatusBar_SetText($hStatusBar, "Error saving Focuses")
                Return
            EndIf
    EndSwitch

    _Log("Changes saved for ModelID: " & $sModelID)
    _EnableEditMode(False)
    _LoadTableData($sTable, GUICtrlRead($hSearchInput), _
                   GUICtrlRead($hFilterAppCombo) = "All" ? "" : GUICtrlRead($hFilterAppCombo), _
                   GUICtrlRead($hFilterStemsCombo) = "All" ? -1 : GUICtrlRead($hFilterStemsCombo))
    _PopulateFields($iCurrentIndex)
    _GUICtrlStatusBar_SetText($hStatusBar, "Changes saved")
EndFunc
#EndRegion ;**** Database Functions ****

#Region ;**** Navigation Functions ****
Func _FirstRecord()
    _Log("Navigating to first record")
    If UBound($aListViewData) > 0 Then
        _PopulateFields(0)
    EndIf
EndFunc

Func _PrevRecord()
    _Log("Navigating to previous record")
    If $iCurrentIndex > 0 Then
        _PopulateFields($iCurrentIndex - 1)
    EndIf
EndFunc

Func _NextRecord()
    _Log("Navigating to next record")
    If $iCurrentIndex < UBound($aListViewData) - 1 Then
        _PopulateFields($iCurrentIndex + 1)
    EndIf
EndFunc

Func _LastRecord()
    _Log("Navigating to last record")
    If UBound($aListViewData) > 0 Then
        _PopulateFields(UBound($aListViewData) - 1)
    EndIf
EndFunc
#EndRegion ;**** Navigation Functions ****

#Region ;**** Utility Functions ****
Func _CopyRow()
    _Log("Copying row")
    If $iCurrentIndex < 0 Then
        _Log("No row selected to copy", True)
        Return
    EndIf
    Local $sTable = GUICtrlRead($hTableCombo)
    Local $sRow = _ArrayToString($aListViewData[$iCurrentIndex], "|")
    ClipPut($sRow)
    _GUICtrlStatusBar_SetText($hStatusBar, "Row copied to clipboard")
EndFunc

Func _ExportCSV()
    _Log("Exporting table to CSV")
    Local $sTable = GUICtrlRead($hTableCombo)
    Local $sFile = FileSaveDialog("Export to CSV", @ScriptDir, "CSV Files (*.csv)", 16, $sTable & "_export.csv")
    If $sFile = "" Then
        _Log("CSV export cancelled", True)
        Return
    EndIf
    Local $hFile = FileOpen($sFile, 2)
    Local $sHeader
    If _GUICtrlListView_GetColumnCount($hListView) = 2 Then
        $sHeader = "ModelID,App"
    ElseIf $sTable = "ModelFocuses" Then
        $sHeader = "ModelID,Focus,Stems"
    Else
        $sHeader = "ModelID,Name,Path,Description,Comments,CommandLine,App"
    EndIf
    FileWriteLine($hFile, $sHeader)
    For $i = 0 To UBound($aListViewData) - 1
        Local $sLine = _ArrayToString($aListViewData[$i], ",")
        FileWriteLine($hFile, $sLine)
    Next
    FileClose($hFile)
    _GUICtrlStatusBar_SetText($hStatusBar, "Exported to " & $sFile)
    _Log("Exported table to " & $sFile)
EndFunc

Func _OpenPath()
    _Log("Opening path in Explorer")
    If $iCurrentIndex < 0 Or GUICtrlRead($hTableCombo) <> "Models" Then
        _Log("Invalid selection for opening path", True)
        Return
    EndIf
    Local $sPath = $aListViewData[$iCurrentIndex][2]
    If $sPath = "N/A" Or Not FileExists($sPath) Then
        _GUICtrlStatusBar_SetText($hStatusBar, "Invalid path")
        _Log("Invalid path: " & $sPath, True)
        Return
    EndIf
    ShellExecute("explorer.exe", "/select," & $sPath)
    _GUICtrlStatusBar_SetText($hStatusBar, "Opened path in Explorer")
    _Log("Opened path: " & $sPath)
EndFunc
#EndRegion ;**** Utility Functions ****

#Region ;**** Main Script ****
Opt("GUIOnEventMode", 1)
_Log("Starting Model Database Browser")

_SQLite_Startup()
If @error Then
    _Log("Failed to start SQLite: Error " & @error, True)
    Exit
EndIf
_Log("SQLite started")

_CreateDatabase()
$hDb = _SQLite_Open($sDbFile) ; Re-open after creation
If @error Then
    _Log("Failed to open database: " & _SQLite_ErrMsg(), True)
    _SQLite_Shutdown()
    Exit
EndIf
_Log("Database opened: " & $sDbFile)

_CheckTables()
_InitDatabase()

_CreateGUI()
_LoadTableData("Models")
_Log("Initial data load completed")

GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
GUICtrlSetOnEvent($hTableCombo, "_TableComboHandler")
GUICtrlSetOnEvent($hSearchInput, "_SearchHandler")
GUICtrlSetOnEvent($hFilterAppCombo, "_FilterHandler")
GUICtrlSetOnEvent($hFilterStemsCombo, "_FilterHandler")
GUICtrlSetOnEvent($hFirstButton, "_FirstRecord")
GUICtrlSetOnEvent($hPrevButton, "_PrevRecord")
GUICtrlSetOnEvent($hNextButton, "_NextRecord")
GUICtrlSetOnEvent($hLastButton, "_LastRecord")
GUICtrlSetOnEvent($hEditButton, "_EditHandler")
GUICtrlSetOnEvent($hSaveButton, "_SaveChanges")
GUICtrlSetOnEvent($hCancelButton, "_CancelEdit")
GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")
GUIRegisterMsg($WM_COMMAND, "WM_COMMAND")
_Log("Event handlers registered")

While 1
    Sleep(100)
WEnd

Func _TableComboHandler()
    _Log("Table combo changed")
    Local $sTable = GUICtrlRead($hTableCombo)
    _LoadTableData($sTable)
EndFunc

Func _SearchHandler()
    _Log("Search input changed")
    Local $sTable = GUICtrlRead($hTableCombo)
    _LoadTableData($sTable, GUICtrlRead($hSearchInput), _
                   GUICtrlRead($hFilterAppCombo) = "All" ? "" : GUICtrlRead($hFilterAppCombo), _
                   GUICtrlRead($hFilterStemsCombo) = "All" ? -1 : GUICtrlRead($hFilterStemsCombo))
EndFunc

Func _FilterHandler()
    _Log("Filter changed")
    _SearchHandler()
EndFunc

Func _EditHandler()
    _Log("Edit button clicked")
    If $iCurrentIndex < 0 Then
        _GUICtrlStatusBar_SetText($hStatusBar, "Select a record to edit")
        _Log("No record selected for edit", True)
        Return
    EndIf
    _EnableEditMode(True)
EndFunc

Func _CancelEdit()
    _Log("Cancel edit clicked")
    _EnableEditMode(False)
    If $iCurrentIndex >= 0 Then _PopulateFields($iCurrentIndex)
EndFunc

Func _Exit()
    _Log("Shutting down")
    _SQLite_Close($hDb)
    _SQLite_Shutdown()
    GUIDelete($hGUI)
    Exit
EndFunc

Func WM_NOTIFY($hWnd, $iMsg, $wParam, $lParam)
    _Log("WM_NOTIFY received")
    Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
    Local $hWndFrom = DllStructGetData($tNMHDR, "hWndFrom")
    Local $iCode = DllStructGetData($tNMHDR, "Code")

    Switch $hWndFrom
        Case GUICtrlGetHandle($hListView)
            Switch $iCode
                Case $NM_CLICK
                    Local $iSelected = _GUICtrlListView_GetSelectedIndices($hListView)
                    If $iSelected <> -1 Then
                        _Log("ListView item selected: " & $iSelected)
                        _PopulateFields(Number($iSelected))
                    EndIf
                Case $NM_DBLCLK
                    If $iCurrentIndex >= 0 Then
                        _Log("ListView double-clicked")
                        _EditHandler()
                    EndIf
            EndSwitch
        Case $hToolbar
            Switch DllStructGetData($tNMHDR, "IDFrom")
                Case 1000
                    _Log("Toolbar Refresh clicked")
                    _TableComboHandler()
                Case 1001
                    _Log("Toolbar Export CSV clicked")
                    _ExportCSV()
                Case 1002
                    _Log("Toolbar Toggle Theme clicked")
                    _ToggleTheme()
            EndSwitch
    EndSwitch
    Return $GUI_RUNDEFMSG
EndFunc

Func WM_COMMAND($hWnd, $iMsg, $wParam, $lParam)
    _Log("WM_COMMAND received")
    Local $iID = BitAND($wParam, 0xFFFF)
    Switch $iID
        Case $idCopyRow
            _Log("Context menu: Copy Row")
            _CopyRow()
        Case $idExportCSV
            _Log("Context menu: Export CSV")
            _ExportCSV()
        Case $idOpenPath
            _Log("Context menu: Open Path")
            _OpenPath()
    EndSwitch
    Return $GUI_RUNDEFMSG
EndFunc
#EndRegion ;**** Main Script ****