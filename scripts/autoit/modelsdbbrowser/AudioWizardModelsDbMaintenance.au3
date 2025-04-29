#Region ;**** Directives and Includes ****
#AutoIt3Wrapper_Res_Description=AudioWizard Models Database Maintenance
#AutoIt3Wrapper_Res_Fileversion=1.0.0.1
#AutoIt3Wrapper_Res_ProductName=AudioWizard Models DB Maintenance
#AutoIt3Wrapper_Res_ProductVersion=1.0.0
#AutoIt3Wrapper_Res_CompanyName=FretzCapo
#AutoIt3Wrapper_Res_LegalCopyright=© 2025 FretzCapo
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=None
#AutoIt3Wrapper_Run_AU3Check=Y
#AutoIt3Wrapper_AU3Check_Parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6 -w 7

#include <Array.au3>
#include <File.au3>
#include <SQLite.au3>
#include <StringConstants.au3>
#include <GUIConstantsEx.au3>
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <ListViewConstants.au3>
#include <WindowsConstants.au3>
#include <GuiListView.au3>
#include <Date.au3>
#include <MsgBoxConstants.au3>
#EndRegion ;**** Directives and Includes ****

#Region ;**** Global Variables ****
Global $hGUI, $hListView, $hAddButton, $hRemoveButton, $hEditButton, $hRebuildButton, $hClearButton, $hRefreshButton, $hDb
Global $sDbFile = @ScriptDir & "\models.db"
Global $sModelsIni = @ScriptDir & "\Models.ini"
Global $sLogFile = @ScriptDir & "\logs\ModelsDbMaintenance_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & ".log"
If Not FileExists(@ScriptDir & "\logs") Then DirCreate(@ScriptDir & "\logs")

; Global variables for Add/Edit dialogs
Global $hAddGUI, $hEditGUI
Global $hAppInput, $hNameInput, $hPathInput, $hFocusInput, $hStemsInput, $hDescInput, $hCommentsInput, $hCmdInput
Global $iEditModelID
#EndRegion ;**** Global Variables ****

#Region ;**** Logging Functions ****
Func _Log($sMessage, $bError = False)
    Local $sTimestamp = "[" & _Now() & "] " & ($bError ? "ERROR" : "INFO") & ": "
    Local $hFile = FileOpen($sLogFile, 1)
    FileWrite($hFile, $sTimestamp & $sMessage & @CRLF)
    FileClose($hFile)
EndFunc
#EndRegion ;**** Logging Functions ****

#Region ;**** Database Functions ****
Func _InitializeModels()
    _Log("Entering _InitializeModels")
    Local $aResult, $iRows, $iCols

    ; Check if Apps table exists
    Local $sQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='Apps';"
    _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRows = 0 Then
        _Log("Apps table does not exist, creating it")
        $sQuery = "CREATE TABLE Apps (AppID INTEGER PRIMARY KEY AUTOINCREMENT, AppName TEXT UNIQUE);"
        _SQLite_Exec($hDb, $sQuery)
        If @error Then
            _Log("Failed to create Apps table: " & _SQLite_ErrMsg(), True)
            Return False
        EndIf
        _Log("Apps table created successfully")
    EndIf

    ; Check if Models table exists
    $sQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='Models';"
    _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRows = 0 Then
        _Log("Models table does not exist, creating it")
        $sQuery = "CREATE TABLE Models (ModelID INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT UNIQUE, Path TEXT, Focus TEXT, Stems INTEGER, Description TEXT, Comments TEXT, CommandLine TEXT);"
        _SQLite_Exec($hDb, $sQuery)
        If @error Then
            _Log("Failed to create Models table: " & _SQLite_ErrMsg(), True)
            Return False
        EndIf
        _Log("Models table created successfully")
    Else
        _Log("Models table exists, checking schema")
        $sQuery = "PRAGMA table_info(Models);"
        _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
        If @error Then
            _Log("Failed to query table schema: " & _SQLite_ErrMsg(), True)
            Return False
        EndIf

        Local $aExpectedColumns = ["Name", "Path", "Focus", "Stems", "Description", "Comments", "CommandLine"]
        Local $bSchemaCorrect = True
        For $sColumn In $aExpectedColumns
            Local $bFound = False
            For $i = 0 To $iRows - 1
                If $aResult[$i][1] = $sColumn Then
                    $bFound = True
                    ExitLoop
                EndIf
            Next
            If Not $bFound Then
                _Log("Missing column in Models table: " & $sColumn, True)
                $bSchemaCorrect = False
                ExitLoop
            EndIf
        Next

        ; Check for unexpected App column
        For $i = 0 To $iRows - 1
            If $aResult[$i][1] = "App" Then
                _Log("Unexpected column 'App' found in Models table", True)
                $bSchemaCorrect = False
                ExitLoop
            EndIf
        Next

        If Not $bSchemaCorrect Then
            _Log("Schema mismatch detected, dropping and recreating Models table")
            $sQuery = "DROP TABLE Models;"
            _SQLite_Exec($hDb, $sQuery)
            If @error Then
                _Log("Failed to drop Models table: " & _SQLite_ErrMsg(), True)
                Return False
            EndIf
            $sQuery = "CREATE TABLE Models (ModelID INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT UNIQUE, Path TEXT, Focus TEXT, Stems INTEGER, Description TEXT, Comments TEXT, CommandLine TEXT);"
            _SQLite_Exec($hDb, $sQuery)
            If @error Then
                _Log("Failed to recreate Models table: " & _SQLite_ErrMsg(), True)
                Return False
            EndIf
            _Log("Models table recreated successfully")
        Else
            _Log("Models table schema is correct")
        EndIf
    EndIf

    ; Check if ModelApps table exists
    $sQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='ModelApps';"
    _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRows = 0 Then
        _Log("ModelApps table does not exist, creating it")
        $sQuery = "CREATE TABLE ModelApps (ModelID INTEGER, AppID INTEGER, PRIMARY KEY (ModelID, AppID), FOREIGN KEY (ModelID) REFERENCES Models(ModelID), FOREIGN KEY (AppID) REFERENCES Apps(AppID));"
        _SQLite_Exec($hDb, $sQuery)
        If @error Then
            _Log("Failed to create ModelApps table: " & _SQLite_ErrMsg(), True)
            Return False
        EndIf
        _Log("ModelApps table created successfully")
    EndIf

    ; Check if the tables have any data
    $sQuery = "SELECT COUNT(*) FROM Models;"
    Local $aCount
    _SQLite_GetTable2d($hDb, $sQuery, $aCount, $iRows, $iCols)
    If $aCount[0][0] = 0 Then
        _Log("Models table is empty, rebuilding from Models.ini")
        If Not _RebuildDatabaseFromIni() Then
            _Log("Failed to rebuild database from Models.ini", True)
            Return False
        EndIf
    Else
        _Log("Models table contains " & $aCount[0][0] & " records")
    EndIf

    _Log("Exiting _InitializeModels")
    Return True
EndFunc



Func _RebuildDatabaseFromIni()
    _Log("Entering _RebuildDatabaseFromIni")
    If Not FileExists($sModelsIni) Then
        _Log("Models.ini not found at " & $sModelsIni, True)
        MsgBox($MB_ICONERROR, "Error", "Models.ini not found at " & $sModelsIni)
        Return False
    EndIf

    Local $aSections = IniReadSectionNames($sModelsIni)
    If @error Then
        _Log("Failed to read sections from Models.ini", True)
        MsgBox($MB_ICONERROR, "Error", "Failed to read Models.ini")
        Return False
    EndIf
    _Log("Found " & $aSections[0] & " sections in Models.ini")

    ; Clear existing data
    _SQLite_Exec($hDb, "DELETE FROM Models;")
    If @error Then
        _Log("Failed to clear Models table: " & _SQLite_ErrMsg(), True)
        Return False
    EndIf
    _Log("Cleared existing data in Models table")

    For $i = 1 To $aSections[0]
        Local $sSection = $aSections[$i]
        Local $sApp = IniRead($sModelsIni, $sSection, "App", "")
        Local $sName = IniRead($sModelsIni, $sSection, "Name", "")
        Local $sPath = IniRead($sModelsIni, $sSection, "Path", "N/A")
        Local $sFocus = IniRead($sModelsIni, $sSection, "Focus", "N/A")
        Local $iStems = Int(IniRead($sModelsIni, $sSection, "Stems", 0))
        Local $sDescription = IniRead($sModelsIni, $sSection, "Description", "")
        Local $sComments = IniRead($sModelsIni, $sSection, "Comments", "")
        Local $sCommandLine = IniRead($sModelsIni, $sSection, "CommandLine", "")

        If $sName = "" Then
            _Log("Skipping section " & $sSection & ": Name is empty", True)
            ContinueLoop
        EndIf

        Local $sQuery = "INSERT INTO Models (App, Name, Path, Focus, Stems, Description, Comments, CommandLine) VALUES (" & _
            _SQLite_Escape($sApp) & "," & _SQLite_Escape($sName) & "," & _SQLite_Escape($sPath) & "," & _
            _SQLite_Escape($sFocus) & "," & $iStems & "," & _SQLite_Escape($sDescription) & "," & _
            _SQLite_Escape($sComments) & "," & _SQLite_Escape($sCommandLine) & ");"
        _SQLite_Exec($hDb, $sQuery)
        If @error Then
            _Log("Failed to insert model " & $sName & ": " & _SQLite_ErrMsg(), True)
        Else
            _Log("Inserted model: " & $sName)
        EndIf
    Next

    _Log("Exiting _RebuildDatabaseFromIni")
    Return True
EndFunc




Func _ClearDatabase()
    _Log("Entering _ClearDatabase")
    _SQLite_Exec($hDb, "DELETE FROM Models;")
    If @error Then
        _Log("Failed to clear Models table: " & _SQLite_ErrMsg(), True)
        MsgBox($MB_ICONERROR, "Error", "Failed to clear database")
        Return False
    EndIf
    _Log("Database cleared successfully")
    _Log("Exiting _ClearDatabase")
    Return True
EndFunc





Func _LoadModelsIntoListView()
    _Log("Entering _LoadModelsIntoListView")
    _Log("Database file: " & $sDbFile)
    If Not FileExists($sDbFile) Then
        _Log("Database file does not exist: " & $sDbFile, True)
        MsgBox($MB_ICONERROR, "Error", "Database file not found: " & $sDbFile)
        Return
    EndIf

    _GUICtrlListView_DeleteAllItems($hListView)
    Local $aResult, $iRows, $iCols
    Local $sQuery = "SELECT m.ModelID, a.AppName, m.Name, m.Path, m.Focus, m.Stems, m.Description, m.Comments, m.CommandLine " & _
                    "FROM Models m " & _
                    "JOIN ModelApps ma ON m.ModelID = ma.ModelID " & _
                    "JOIN Apps a ON ma.AppID = a.AppID;"
    _Log("Executing query: " & $sQuery)
    Local $iResult = _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iResult <> $SQLITE_OK Then
        _Log("SQLite query failed with result: " & $iResult & ", Error: " & _SQLite_ErrMsg(), True)
        MsgBox($MB_ICONERROR, "Error", "Failed to query database: " & _SQLite_ErrMsg())
        Return
    EndIf
    If $iRows = 0 Then
        _Log("No models found in database")
        MsgBox($MB_ICONINFORMATION, "Info", "No models found in the database. Add a model or rebuild from Models.ini.")
        Return
    EndIf

    For $i = 0 To $iRows - 1
        Local $aRow = $aResult[$i]
        Local $iIndex = _GUICtrlListView_AddItem($hListView, $aRow[0]) ; ModelID
        _GUICtrlListView_AddSubItem($hListView, $iIndex, $aRow[1], 1) ; AppName
        _GUICtrlListView_AddSubItem($hListView, $iIndex, $aRow[2], 2) ; Name
        _GUICtrlListView_AddSubItem($hListView, $iIndex, $aRow[3], 3) ; Path
        _GUICtrlListView_AddSubItem($hListView, $iIndex, $aRow[4], 4) ; Focus
        _GUICtrlListView_AddSubItem($hListView, $iIndex, $aRow[5], 5) ; Stems
        _GUICtrlListView_AddSubItem($hListView, $iIndex, $aRow[6], 6) ; Description
        _GUICtrlListView_AddSubItem($hListView, $iIndex, $aRow[7], 7) ; Comments
        _GUICtrlListView_AddSubItem($hListView, $iIndex, $aRow[8], 8) ; CommandLine
        _Log("Added model to ListView: ModelID=" & $aRow[0] & ", Name=" & $aRow[2])
    Next
    GUICtrlSetState($hListView, BitOR($GUI_SHOW, $GUI_ENABLE))
    _Log("Loaded " & $iRows & " models into ListView")
    _Log("Exiting _LoadModelsIntoListView")
EndFunc


Func _AddModel($sApp, $sName, $sPath, $sFocus, $iStems, $sDescription, $sComments, $sCommandLine)
    _Log("Entering _AddModel: Name=" & $sName)
    Local $sQuery = "INSERT INTO Models (App, Name, Path, Focus, Stems, Description, Comments, CommandLine) VALUES (" & _
        _SQLite_Escape($sApp) & "," & _SQLite_Escape($sName) & "," & _SQLite_Escape($sPath) & "," & _
        _SQLite_Escape($sFocus) & "," & $iStems & "," & _SQLite_Escape($sDescription) & "," & _
        _SQLite_Escape($sComments) & "," & _SQLite_Escape($sCommandLine) & ");"
    _SQLite_Exec($hDb, $sQuery)
    If @error Then
        _Log("Failed to add model " & $sName & ": " & _SQLite_ErrMsg(), True)
        MsgBox($MB_ICONERROR, "Error", "Failed to add model: " & _SQLite_ErrMsg())
        Return False
    EndIf
    _Log("Model " & $sName & " added successfully")
    Return True
EndFunc

Func _RemoveModel($iModelID)
    _Log("Entering _RemoveModel: ModelID=" & $iModelID)
    Local $sQuery = "DELETE FROM Models WHERE ModelID = " & $iModelID & ";"
    _SQLite_Exec($hDb, $sQuery)
    If @error Then
        _Log("Failed to remove model with ModelID " & $iModelID & ": " & _SQLite_ErrMsg(), True)
        MsgBox($MB_ICONERROR, "Error", "Failed to remove model: " & _SQLite_ErrMsg())
        Return False
    EndIf
    _Log("Model with ModelID " & $iModelID & " removed successfully")
    Return True
EndFunc

Func _UpdateModel($iModelID, $sApp, $sPath, $sFocus, $iStems, $sDescription, $sComments, $sCommandLine)
    _Log("Entering _UpdateModel: ModelID=" & $iModelID)
    Local $sQuery = "UPDATE Models SET " & _
        "App = " & _SQLite_Escape($sApp) & "," & _
        "Path = " & _SQLite_Escape($sPath) & "," & _
        "Focus = " & _SQLite_Escape($sFocus) & "," & _
        "Stems = " & $iStems & "," & _
        "Description = " & _SQLite_Escape($sDescription) & "," & _
        "Comments = " & _SQLite_Escape($sComments) & "," & _
        "CommandLine = " & _SQLite_Escape($sCommandLine) & " " & _
        "WHERE ModelID = " & $iModelID & ";"
    _SQLite_Exec($hDb, $sQuery)
    If @error Then
        _Log("Failed to update model with ModelID " & $iModelID & ": " & _SQLite_ErrMsg(), True)
        MsgBox($MB_ICONERROR, "Error", "Failed to update model: " & _SQLite_ErrMsg())
        Return False
    EndIf
    _Log("Model with ModelID " & $iModelID & " updated successfully")
    Return True
EndFunc
#EndRegion ;**** Database Functions ****

#Region ;**** GUI Functions ****
Func _CreateGUI()
    _Log("Entering _CreateGUI")
    $hGUI = GUICreate("AudioWizard Models DB Maintenance", 1000, 600)

    ; ListView for displaying models
    $hListView = GUICtrlCreateListView("ModelID|App|Name|Path|Focus|Stems|Description|Comments|CommandLine", 10, 10, 980, 500, BitOR($LVS_REPORT, $LVS_SHOWSELALWAYS, $LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT))
    _GUICtrlListView_SetColumnWidth($hListView, 0, 60)  ; ModelID
    _GUICtrlListView_SetColumnWidth($hListView, 1, 80)  ; App
    _GUICtrlListView_SetColumnWidth($hListView, 2, 100) ; Name
    _GUICtrlListView_SetColumnWidth($hListView, 3, 100) ; Path
    _GUICtrlListView_SetColumnWidth($hListView, 4, 80)  ; Focus
    _GUICtrlListView_SetColumnWidth($hListView, 5, 50)  ; Stems
    _GUICtrlListView_SetColumnWidth($hListView, 6, 150) ; Description
    _GUICtrlListView_SetColumnWidth($hListView, 7, 150) ; Comments
    _GUICtrlListView_SetColumnWidth($hListView, 8, 200) ; CommandLine

    ; Buttons
    $hAddButton = GUICtrlCreateButton("Add Model", 10, 520, 100, 30)
    GUICtrlSetOnEvent($hAddButton, "_AddButtonHandler")
    $hRemoveButton = GUICtrlCreateButton("Remove Selected", 120, 520, 120, 30)
    GUICtrlSetOnEvent($hRemoveButton, "_RemoveButtonHandler")
    $hEditButton = GUICtrlCreateButton("Edit Selected", 250, 520, 120, 30)
    GUICtrlSetOnEvent($hEditButton, "_EditButtonHandler")
    $hRebuildButton = GUICtrlCreateButton("Rebuild from Models.ini", 380, 520, 150, 30)
    GUICtrlSetOnEvent($hRebuildButton, "_RebuildButtonHandler")
    $hClearButton = GUICtrlCreateButton("Clear Database", 540, 520, 120, 30)
    GUICtrlSetOnEvent($hClearButton, "_ClearButtonHandler")
    $hRefreshButton = GUICtrlCreateButton("Refresh", 670, 520, 100, 30)
    GUICtrlSetOnEvent($hRefreshButton, "_RefreshButtonHandler")

    GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
    GUISetState(@SW_SHOW)
    _Log("Exiting _CreateGUI")
EndFunc

Func _AddButtonHandler()
    _Log("Entering _AddButtonHandler")
    $hAddGUI = GUICreate("Add Model", 600, 400, -1, -1, -1, -1, $hGUI)
    Local $iY = 10
    Local $iLabelWidth = 100
    Local $iInputWidth = 480

    GUICtrlCreateLabel("App:", 10, $iY, $iLabelWidth, 20)
    $hAppInput = GUICtrlCreateInput("", 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("Name:", 10, $iY, $iLabelWidth, 20)
    $hNameInput = GUICtrlCreateInput("", 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("Path:", 10, $iY, $iLabelWidth, 20)
    $hPathInput = GUICtrlCreateInput("N/A", 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("Focus:", 10, $iY, $iLabelWidth, 20)
    $hFocusInput = GUICtrlCreateInput("N/A", 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("Stems:", 10, $iY, $iLabelWidth, 20)
    $hStemsInput = GUICtrlCreateInput("0", 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("Description:", 10, $iY, $iLabelWidth, 20)
    $hDescInput = GUICtrlCreateInput("", 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("Comments:", 10, $iY, $iLabelWidth, 20)
    $hCommentsInput = GUICtrlCreateInput("", 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("CommandLine:", 10, $iY, $iLabelWidth, 20)
    $hCmdInput = GUICtrlCreateInput("", 110, $iY, $iInputWidth, 50, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL))
    $iY += 60

    Local $hOkButton = GUICtrlCreateButton("OK", 200, $iY, 80, 30)
    GUICtrlSetOnEvent($hOkButton, "_AddOkButtonHandler")
    Local $hCancelButton = GUICtrlCreateButton("Cancel", 300, $iY, 80, 30)
    GUICtrlSetOnEvent($hCancelButton, "_AddCancelButtonHandler")

    GUISetState(@SW_SHOW, $hAddGUI)
    _Log("Add Model dialog opened")
EndFunc

Func _AddOkButtonHandler()
    _Log("Entering _AddOkButtonHandler")
    Local $sApp = GUICtrlRead($hAppInput)
    Local $sName = GUICtrlRead($hNameInput)
    Local $sPath = GUICtrlRead($hPathInput)
    Local $sFocus = GUICtrlRead($hFocusInput)
    Local $iStems = Int(GUICtrlRead($hStemsInput))
    Local $sDescription = GUICtrlRead($hDescInput)
    Local $sComments = GUICtrlRead($hCommentsInput)
    Local $sCommandLine = GUICtrlRead($hCmdInput)

    If $sName = "" Then
        _Log("Cannot add model: Name is empty", True)
        MsgBox($MB_ICONERROR, "Error", "Model Name cannot be empty")
        Return
    EndIf

    If _AddModel($sApp, $sName, $sPath, $sFocus, $iStems, $sDescription, $sComments, $sCommandLine) Then
        _LoadModelsIntoListView()
        GUIDelete($hAddGUI)
    EndIf
    _Log("Exiting _AddOkButtonHandler")
EndFunc

Func _AddCancelButtonHandler()
    _Log("Entering _AddCancelButtonHandler")
    GUIDelete($hAddGUI)
    _Log("Add Model dialog cancelled")
EndFunc

Func _RemoveButtonHandler()
    _Log("Entering _RemoveButtonHandler")
    Local $aSelected = _GUICtrlListView_GetSelectedIndices($hListView, True)
    If $aSelected[0] = 0 Then
        _Log("No models selected for removal", True)
        MsgBox($MB_ICONWARNING, "Warning", "Please select a model to remove")
        Return
    EndIf

    For $i = 1 To $aSelected[0]
        Local $iIndex = $aSelected[$i]
        Local $iModelID = _GUICtrlListView_GetItemText($hListView, $iIndex, 0)
        If _RemoveModel($iModelID) Then
            _Log("Removed model with ModelID " & $iModelID)
        EndIf
    Next
    _LoadModelsIntoListView()
    _Log("Exiting _RemoveButtonHandler")
EndFunc

Func _EditButtonHandler()
    _Log("Entering _EditButtonHandler")
    Local $aSelected = _GUICtrlListView_GetSelectedIndices($hListView, True)
    If $aSelected[0] <> 1 Then
        _Log("Please select exactly one model to edit", True)
        MsgBox($MB_ICONWARNING, "Warning", "Please select exactly one model to edit")
        Return
    EndIf

    Local $iIndex = $aSelected[1]
    $iEditModelID = _GUICtrlListView_GetItemText($hListView, $iIndex, 0)
    Local $sApp = _GUICtrlListView_GetItemText($hListView, $iIndex, 1)
    Local $sName = _GUICtrlListView_GetItemText($hListView, $iIndex, 2)
    Local $sPath = _GUICtrlListView_GetItemText($hListView, $iIndex, 3)
    Local $sFocus = _GUICtrlListView_GetItemText($hListView, $iIndex, 4)
    Local $iStems = _GUICtrlListView_GetItemText($hListView, $iIndex, 5)
    Local $sDescription = _GUICtrlListView_GetItemText($hListView, $iIndex, 6)
    Local $sComments = _GUICtrlListView_GetItemText($hListView, $iIndex, 7)
    Local $sCommandLine = _GUICtrlListView_GetItemText($hListView, $iIndex, 8)

    $hEditGUI = GUICreate("Edit Model", 600, 400, -1, -1, -1, -1, $hGUI)
    Local $iY = 10
    Local $iLabelWidth = 100
    Local $iInputWidth = 480

    GUICtrlCreateLabel("ModelID:", 10, $iY, $iLabelWidth, 20)
    GUICtrlCreateLabel($iEditModelID, 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("App:", 10, $iY, $iLabelWidth, 20)
    $hAppInput = GUICtrlCreateInput($sApp, 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("Name:", 10, $iY, $iLabelWidth, 20)
    GUICtrlCreateLabel($sName, 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("Path:", 10, $iY, $iLabelWidth, 20)
    $hPathInput = GUICtrlCreateInput($sPath, 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("Focus:", 10, $iY, $iLabelWidth, 20)
    $hFocusInput = GUICtrlCreateInput($sFocus, 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("Stems:", 10, $iY, $iLabelWidth, 20)
    $hStemsInput = GUICtrlCreateInput($iStems, 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("Description:", 10, $iY, $iLabelWidth, 20)
    $hDescInput = GUICtrlCreateInput($sDescription, 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("Comments:", 10, $iY, $iLabelWidth, 20)
    $hCommentsInput = GUICtrlCreateInput($sComments, 110, $iY, $iInputWidth, 20)
    $iY += 30

    GUICtrlCreateLabel("CommandLine:", 10, $iY, $iLabelWidth, 20)
    $hCmdInput = GUICtrlCreateInput($sCommandLine, 110, $iY, $iInputWidth, 50, BitOR($ES_MULTILINE, $ES_AUTOVSCROLL))
    $iY += 60

    Local $hOkButton = GUICtrlCreateButton("OK", 200, $iY, 80, 30)
    GUICtrlSetOnEvent($hOkButton, "_EditOkButtonHandler")
    Local $hCancelButton = GUICtrlCreateButton("Cancel", 300, $iY, 80, 30)
    GUICtrlSetOnEvent($hCancelButton, "_EditCancelButtonHandler")

    GUISetState(@SW_SHOW, $hEditGUI)
    _Log("Edit Model dialog opened for ModelID " & $iEditModelID)
EndFunc

Func _EditOkButtonHandler()
    _Log("Entering _EditOkButtonHandler")
    Local $sApp = GUICtrlRead($hAppInput)
    Local $sPath = GUICtrlRead($hPathInput)
    Local $sFocus = GUICtrlRead($hFocusInput)
    Local $iStems = Int(GUICtrlRead($hStemsInput))
    Local $sDescription = GUICtrlRead($hDescInput)
    Local $sComments = GUICtrlRead($hCommentsInput)
    Local $sCommandLine = GUICtrlRead($hCmdInput)

    If _UpdateModel($iEditModelID, $sApp, $sPath, $sFocus, $iStems, $sDescription, $sComments, $sCommandLine) Then
        _LoadModelsIntoListView()
        GUIDelete($hEditGUI)
    EndIf
    _Log("Exiting _EditOkButtonHandler")
EndFunc

Func _EditCancelButtonHandler()
    _Log("Entering _EditCancelButtonHandler")
    GUIDelete($hEditGUI)
    _Log("Edit Model dialog cancelled")
EndFunc

Func _RebuildButtonHandler()
    _Log("Entering _RebuildButtonHandler")
    If _RebuildDatabaseFromIni() Then
        _Log("Database rebuilt successfully")
        MsgBox($MB_ICONINFORMATION, "Success", "Database rebuilt successfully from Models.ini")
        _LoadModelsIntoListView()
    EndIf
    _Log("Exiting _RebuildButtonHandler")
EndFunc

Func _ClearButtonHandler()
    _Log("Entering _ClearButtonHandler")
    If _ClearDatabase() Then
        _Log("Database cleared successfully")
        MsgBox($MB_ICONINFORMATION, "Success", "Database cleared successfully")
        _LoadModelsIntoListView()
    EndIf
    _Log("Exiting _ClearButtonHandler")
EndFunc

Func _RefreshButtonHandler()
    _Log("Entering _RefreshButtonHandler")
    _LoadModelsIntoListView()
    _Log("Exiting _RefreshButtonHandler")
EndFunc

Func _Exit()
    _Log("Exiting script")
    _SQLite_Close($hDb)
    _SQLite_Shutdown()
    GUIDelete($hGUI)
    Exit
EndFunc
#EndRegion ;**** GUI Functions ****

#Region ;**** Main Script ****
Opt("GUIOnEventMode", 1)
_Log("Starting AudioWizard Models DB Maintenance")
_SQLite_Startup()
If @error Then
    _Log("Failed to start SQLite: Error " & @error, True)
    Exit
EndIf
$hDb = _SQLite_Open($sDbFile)
If @error Then
    _Log("Failed to open database " & $sDbFile & ": Error " & @error & ", SQLite Error: " & _SQLite_ErrMsg(), True)
    _SQLite_Shutdown()
    Exit
EndIf
_Log("Database opened successfully: " & $sDbFile)

If Not _InitializeModels() Then
    _Log("Failed to initialize database", True)
    _SQLite_Close($hDb)
    _SQLite_Shutdown()
    Exit
EndIf

_CreateGUI()
_LoadModelsIntoListView()

While 1
    Sleep(100)
WEnd
#EndRegion ;**** Main Script ****