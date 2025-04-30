;**************************************************
;********************Part 1************************
;**************************************************
#Region Part1
#include <Array.au3>
#include <File.au3>
#include <GDIPlus.au3>
#include <GUIConstantsEx.au3>
#include <GuiListView.au3>
#include <GuiTab.au3>
#include <SQLite.au3>
#include <StringConstants.au3>
#include <WinAPI.au3>
#include <WindowsConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>

Opt("GUIOnEventMode", 1) ; Enable event mode for the script

#Region ;**** Global Variables and Constants ****
Global Const $GOOGLE_BLUE = 0xFF4285F4
Global Const $GOOGLE_GREEN = 0xFF34A853
Global Const $GOOGLE_YELLOW = 0xFFF4B400
Global Const $GRAY = 0xFF808080
Global $hGUI, $hTab
Global $hMainGUI, $hInputButton, $hOutputButton
Global $hInputListView, $hOutputListView, $hBatchList
Global $hModelCombo, $hStemsDisplay, $hFocusDisplay, $hDescEdit, $hCommentsEdit
Global $hModelNameLabel, $hStemsLabel, $hFocusLabel, $hDescLabel, $hCommentsLabel
Global $hGraphicGUI, $hDC, $hGraphics, $hPen, $hBrushGray, $hBrushGreen, $hBrushYellow
Global $hProgressLabel, $hCountLabel
Global $iGuiWidth = 800, $iGuiHeight = 600
Global $sInputPath = "", $sOutputPath = ""
Global $hMDXSegmentSize = 0, $hMDXOverlap = 0, $hMDXDenoise = 0
Global $hMDXBatchSize = 0, $hMDXAggressiveness = 0, $hMDXTTA = 0, $hMDXHighEndProcess = 0
Global $sSettingsIni = @ScriptDir & "\settings.ini"
Global $sModelsIni = @ScriptDir & "\Models.ini"
Global $sUserIni = @ScriptDir & "\user.ini"
Global $sModelsDb = @ScriptDir & "\models.db"
Global $hDb
#EndRegion ;**** Global Variables and Constants ****

#Region ;**** Logging Functions ****
Global $sLogFile = @ScriptDir & "\logs\StemSeparator_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & ".log.txt"
DirCreate(@ScriptDir & "\logs")

Func _Log($sMessage, $bError = False)
    Local $sTimeStamp = "[" & @YEAR & "/" & @MON & "/" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & "] " & ($bError ? "ERROR" : "INFO") & ": "
    Local $hFile = FileOpen($sLogFile, 1)
    FileWrite($hFile, $sTimeStamp & $sMessage & @CRLF)
    FileClose($hFile)
    ConsoleWrite($sTimeStamp & $sMessage & @CRLF)
EndFunc

Func _LogStartupInfo()
    _Log("Entering _LogStartupInfo")
    _Log("Script started")
    _Log("Script Directory: " & @ScriptDir)
    _Log("Working Directory: " & @WorkingDir)
    _Log("OS: " & @OSVersion & " (" & @OSArch & ")")
    _Log("User: " & @UserName)
    _Log("FFmpeg Path: " & @ScriptDir & "\installs\uvr\ffmpeg\bin\ffmpeg.exe")
    _Log("Models Database File: " & $sModelsDb)
    _Log("Settings INI: " & $sSettingsIni)
    _Log("Models INI: " & $sModelsIni)
    _Log("User INI: " & $sUserIni)
    _Log("Exiting _LogStartupInfo")
EndFunc
#EndRegion ;**** Logging Functions ****

#Region ;**** Model Management Functions ****
Func _InitializeModels()
    _Log("Entering _InitializeModels")
    _SQLite_Startup()
    If @error Then
        _Log("Failed to load SQLite library: " & @error, True)
        MsgBox($MB_ICONERROR, "Error", "Failed to load SQLite library.")
        Exit
    EndIf

    $hDb = _SQLite_Open($sModelsDb)
    If @error Then
        _Log("Failed to open database " & $sModelsDb & ": " & @error, True)
        MsgBox($MB_ICONERROR, "Error", "Failed to open models database.")
        _SQLite_Shutdown()
        Exit
    EndIf
    _Log("Opened existing database: " & $sModelsDb)

    Local $aResult, $iRows, $iCols
    Local $sQuery = "SELECT COUNT(*) FROM Models"
    _Log("Executing query: " & $sQuery)
    _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If @error Then
        _Log("Failed to query model count: " & _SQLite_ErrMsg(), True)
        MsgBox($MB_ICONERROR, "Error", "Failed to query model count: " & _SQLite_ErrMsg())
        _SQLite_Close($hDb)
        _SQLite_Shutdown()
        Exit
    EndIf
    _Log("Found " & $aResult[1][0] & " models in database")

    $sQuery = "SELECT Name FROM Models WHERE Name = 'htdemucs'"
    _Log("Executing query: " & $sQuery)
    _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRows = 0 Then
        _Log("Default model 'htdemucs' not found in database", True)
        MsgBox($MB_ICONERROR, "Error", "Default model 'htdemucs' not found in database.")
        _SQLite_Close($hDb)
        _SQLite_Shutdown()
        Exit
    EndIf
    _Log("Confirmed default model 'htdemucs' exists")

    $sQuery = "SELECT Name FROM Models WHERE Name = '2stems'"
    _Log("Executing query: " & $sQuery)
    _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRows = 0 Then
        _Log("Spleeter model '2stems' not found in database", True)
        MsgBox($MB_ICONERROR, "Error", "Spleeter model '2stems' not found in database.")
        _SQLite_Close($hDb)
        _SQLite_Shutdown()
        Exit
    EndIf
    _Log("Confirmed Spleeter model '2stems' exists")

    _Log("Exiting _InitializeModels")
    Return True
EndFunc

Func _GetModelDetails($sModel)
    _Log("Entering _GetModelDetails for model: " & $sModel)
    Local $sQuery = "SELECT ModelApps.App, ModelFocuses.Focus, Models.Name, ModelFocuses.Stems, Models.Path, Models.CommandLine, Models.Description, Models.Comments " & _
                    "FROM Models LEFT JOIN ModelApps ON Models.ModelID = ModelApps.ModelID " & _
                    "LEFT JOIN ModelFocuses ON Models.ModelID = ModelFocuses.ModelID " & _
                    "WHERE Models.Name = '" & $sModel & "';"
    _Log("Executing query: " & $sQuery)
    Local $aResult, $iRows, $iCols
    Local $iRet = _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRet <> $SQLITE_OK Then
        _Log("Failed to get model details for " & $sModel & ": " & _SQLite_ErrMsg(), True)
        Return SetError(1, 0, 0)
    EndIf
    If $iRows = 0 Then
        _Log("Model " & $sModel & " not found in database", True)
        Return SetError(2, 0, 0)
    EndIf
    _Log("Retrieved details for model " & $sModel)
    Return $aResult[1]
EndFunc

Func _UpdateModelDetails($sModel)
    _Log("Entering _UpdateModelDetails for model: " & $sModel)
    If $sModel = "" Then
        GUICtrlSetData($hStemsDisplay, "")
        GUICtrlSetData($hFocusDisplay, "")
        GUICtrlSetData($hDescEdit, "")
        GUICtrlSetData($hCommentsEdit, "")
        _Log("Cleared model details display")
        Return
    EndIf
    Local $aDetails = _GetModelDetails($sModel)
    If @error Then
        _Log("Failed to update model details for " & $sModel & ": " & @error, True)
        GUICtrlSetData($hStemsDisplay, "")
        GUICtrlSetData($hFocusDisplay, "")
        GUICtrlSetData($hDescEdit, "")
        GUICtrlSetData($hCommentsEdit, "")
        Return
    EndIf
    _Log("Setting Stems: " & $aDetails[3])
    GUICtrlSetData($hStemsDisplay, $aDetails[3])
    _Log("Setting Focus: " & $aDetails[1])
    GUICtrlSetData($hFocusDisplay, $aDetails[1])
    _Log("Setting Description: " & $aDetails[6])
    GUICtrlSetData($hDescEdit, $aDetails[6])
    _Log("Setting Comments: " & $aDetails[7])
    GUICtrlSetData($hCommentsEdit, $aDetails[7])
    _Log("Updated model details display for " & $sModel)
    _Log("Exiting _UpdateModelDetails")
EndFunc

Func _UpdateModelDroplist()
    _Log("Entering _UpdateModelDroplist")
    Local $sApp
    Switch _GUICtrlTab_GetCurSel($hTab)
        Case 0
            $sApp = "Demucs"
        Case 1
            $sApp = "Spleeter"
        Case 2
            $sApp = "UVR5"
        Case Else
            _Log("Invalid tab index for model droplist", True)
            Return
    EndSwitch

    Local $sQuery = "SELECT Models.Name FROM Models INNER JOIN ModelApps ON Models.ModelID = ModelApps.ModelID WHERE ModelApps.App = '" & $sApp & "' ORDER BY Models.Name;"
    _Log("Executing query: " & $sQuery)
    Local $aResult, $iRows, $iCols
    Local $iRet = _SQLite_GetTable2d($hDb, $sQuery, $aResult, $iRows, $iCols)
    If $iRet <> $SQLITE_OK Then
        _Log("Failed to query models for " & $sApp & ": " & _SQLite_ErrMsg(), True)
        GUICtrlSetData($hModelCombo, "No models available")
        Return
    EndIf

    Local $sModelList = ""
    If $iRows > 0 Then
        For $i = 1 To $iRows
            $sModelList &= $aResult[$i][0] & "|"
        Next
        $sModelList = StringTrimRight($sModelList, 1) ; Remove trailing "|"
    Else
        $sModelList = "No models available"
    EndIf
    _Log("Model list string: " & $sModelList)

    ; Clear and set the combo box data
    GUICtrlSetData($hModelCombo, "", "") ; Clear existing items
    GUICtrlSetData($hModelCombo, $sModelList)
    ; Verify the combo box contents
    Local $sCurrentData = GUICtrlRead($hModelCombo)
    If $sCurrentData = "" And $sModelList <> "No models available" Then
        _Log("Combo box is empty after setting data. Forcing first model selection.", True)
        Local $aModels = StringSplit($sModelList, "|")
        If $aModels[0] >= 1 Then
            GUICtrlSetData($hModelCombo, $aModels[1])
            _Log("Set combo box to first model: " & $aModels[1])
        EndIf
    EndIf
    ; Force GUI refresh
    GUICtrlSetState($hModelCombo, $GUI_FOCUS)
    _Log("Exiting _UpdateModelDroplist")
EndFunc
#EndRegion ;**** Model Management Functions ****
#EndRegion Part1



;**************************************************
;********************Part 2************************
;**************************************************
#Region Part2
#Region ;**** GUI Creation ****
Func _CreateGUI()
    _Log("Entering _CreateGUI")
    ; Create the main window
    $hMainGUI = GUICreate("Stem Separator", $iGuiWidth, $iGuiHeight)
    GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")

    ; Define quadrant positions and sizes
    Local $iLeftQuadX = 10
    Local $iRightQuadX = ($iGuiWidth - 30) / 2 + 20
    Local $iTopQuadY = 35
    Local $iBottomQuadY = $iTopQuadY + ($iGuiHeight - 110) / 2 + 10
    Local $iQuadWidth = ($iGuiWidth - 30) / 2
    Local $iQuadHeight = ($iGuiHeight - 110) / 2
    Local $iTabTopY = $iTopQuadY + 30

    ; Left quadrant: Input and Output Files
    GUICtrlCreateGroup("INPUT FILES", $iLeftQuadX, 5, $iQuadWidth, $iQuadHeight)
    $hInputButton = GUICtrlCreateButton("Input Dir", $iLeftQuadX + 5, 20, 70, 25)
    GUICtrlSetOnEvent($hInputButton, "_InputButtonHandler")
    $hInputListView = GUICtrlCreateListView("", $iLeftQuadX + 5, 50, $iQuadWidth - 10, $iQuadHeight - 60, BitOR($LVS_REPORT, $LVS_SINGLESEL, $LVS_NOCOLUMNHEADER))
    GUICtrlSetStyle($hInputListView, $LVS_NOCOLUMNHEADER)
    _GUICtrlListView_SetColumn($hInputListView, 0, "", $iQuadWidth - 10)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    GUICtrlCreateGroup("OUTPUT FILES", $iLeftQuadX, $iBottomQuadY - 30, $iQuadWidth, $iQuadHeight + 30)
    $hOutputButton = GUICtrlCreateButton("Output Dir", $iLeftQuadX + 5, $iBottomQuadY - 10, 70, 25)
    GUICtrlSetOnEvent($hOutputButton, "_OutputButtonHandler")
    $hOutputListView = GUICtrlCreateListView("", $iLeftQuadX + 5, $iBottomQuadY + 20, $iQuadWidth - 10, $iQuadHeight - 10, BitOR($LVS_REPORT, $LVS_SINGLESEL, $LVS_NOCOLUMNHEADER))
    GUICtrlSetStyle($hOutputListView, $LVS_NOCOLUMNHEADER)
    _GUICtrlListView_SetColumn($hOutputListView, 0, "", $iQuadWidth - 10)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    ; Right quadrant: Tabs and Process Queue
    $hTab = GUICtrlCreateTab($iRightQuadX, $iTopQuadY, $iQuadWidth, $iQuadHeight + 30)
    GUICtrlSetOnEvent($hTab, "_TabHandler")

    ; Tab 1: Demucs
    GUICtrlCreateTabItem("Demucs")
    GUICtrlCreateLabel("Model Name:", $iRightQuadX + 5, $iTabTopY, 70, 20)
    GUICtrlCreateCombo("", $iRightQuadX + 80, $iTabTopY, 150, 25, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL, $WS_VSCROLL))
    GUICtrlCreateLabel("Stems:", $iRightQuadX + 235, $iTabTopY, 40, 20)
    GUICtrlCreateLabel("", $iRightQuadX + 275, $iTabTopY, 30, 20)
    GUICtrlCreateLabel("Focus:", $iRightQuadX + 5, $iTabTopY + 30, 80, 20)
    GUICtrlCreateLabel("", $iRightQuadX + 85, $iTabTopY + 30, $iQuadWidth - 90, 20)
    GUICtrlCreateLabel("Description:", $iRightQuadX + 5, $iTabTopY + 55, 80, 20)
    GUICtrlCreateEdit("", $iRightQuadX + 5, $iTabTopY + 75, $iQuadWidth - 10, 80, BitOR($ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL))
    GUICtrlCreateLabel("Comments:", $iRightQuadX + 5, $iTabTopY + 165, 80, 20)
    GUICtrlCreateEdit("", $iRightQuadX + 5, $iTabTopY + 185, $iQuadWidth - 10, 80, BitOR($ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL))

    ; Tab 2: Spleeter
    GUICtrlCreateTabItem("Spleeter")
    GUICtrlCreateLabel("Model Name:", $iRightQuadX + 5, $iTabTopY, 70, 20)
    GUICtrlCreateCombo("", $iRightQuadX + 80, $iTabTopY, 150, 25, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL, $WS_VSCROLL))
    GUICtrlCreateLabel("Stems:", $iRightQuadX + 235, $iTabTopY, 40, 20)
    GUICtrlCreateLabel("", $iRightQuadX + 275, $iTabTopY, 30, 20)
    GUICtrlCreateLabel("Focus:", $iRightQuadX + 5, $iTabTopY + 30, 80, 20)
    GUICtrlCreateLabel("", $iRightQuadX + 85, $iTabTopY + 30, $iQuadWidth - 90, 20)
    GUICtrlCreateLabel("Description:", $iRightQuadX + 5, $iTabTopY + 55, 80, 20)
    GUICtrlCreateEdit("", $iRightQuadX + 5, $iTabTopY + 75, $iQuadWidth - 10, 80, BitOR($ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL))
    GUICtrlCreateLabel("Comments:", $iRightQuadX + 5, $iTabTopY + 165, 80, 20)
    GUICtrlCreateEdit("", $iRightQuadX + 5, $iTabTopY + 185, $iQuadWidth - 10, 80, BitOR($ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL))

    ; Tab 3: UVR5
    GUICtrlCreateTabItem("UVR5")
    ; Model selection controls
    GUICtrlCreateLabel("Model Name:", $iRightQuadX + 5, $iTabTopY, 70, 20)
    $hModelCombo = GUICtrlCreateCombo("", $iRightQuadX + 80, $iTabTopY, 150, 25, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL, $WS_VSCROLL))
    $hStemsLabel = GUICtrlCreateLabel("Stems:", $iRightQuadX + 235, $iTabTopY, 40, 20)
    $hStemsDisplay = GUICtrlCreateLabel("", $iRightQuadX + 275, $iTabTopY, 30, 20)
    ; MDX-Net controls (horizontal-then-vertical layout)
    Local $iMDXStartY = $iTabTopY + 30
    ; Row 1: Segment Size + Overlap
    GUICtrlCreateLabel("Segment Size:", $iRightQuadX + 5, $iMDXStartY, 80, 20)
    $hMDXSegmentSize = GUICtrlCreateInput("256", $iRightQuadX + 85, $iMDXStartY, 60, 20, $ES_NUMBER)
    GUICtrlCreateLabel("Overlap (0-1):", $iRightQuadX + 155, $iMDXStartY, 80, 20)
    $hMDXOverlap = GUICtrlCreateInput("0.25", $iRightQuadX + 235, $iMDXStartY, 60, 20)
    ; Row 2: Denoise + TTA
    GUICtrlCreateLabel("Denoise:", $iRightQuadX + 5, $iMDXStartY + 25, 80, 20)
    $hMDXDenoise = GUICtrlCreateCheckbox("", $iRightQuadX + 85, $iMDXStartY + 25, 20, 20)
    GUICtrlCreateLabel("TTA:", $iRightQuadX + 155, $iMDXStartY + 25, 80, 20)
    $hMDXTTA = GUICtrlCreateCheckbox("", $iRightQuadX + 235, $iMDXStartY + 25, 20, 20)
    ; Row 3: Batch Size + Aggressiveness
    GUICtrlCreateLabel("Batch Size:", $iRightQuadX + 5, $iMDXStartY + 50, 80, 20)
    $hMDXBatchSize = GUICtrlCreateInput("1", $iRightQuadX + 85, $iMDXStartY + 50, 60, 20, $ES_NUMBER)
    GUICtrlCreateLabel("Aggressiveness (0-100):", $iRightQuadX + 155, $iMDXStartY + 50, 120, 20)
    $hMDXAggressiveness = GUICtrlCreateInput("10", $iRightQuadX + 275, $iMDXStartY + 50, 60, 20, $ES_NUMBER)
    ; Row 4: High End Process
    GUICtrlCreateLabel("High End Process:", $iRightQuadX + 5, $iMDXStartY + 75, 80, 20)
    $hMDXHighEndProcess = GUICtrlCreateCombo("", $iRightQuadX + 85, $iMDXStartY + 75, 100, 25, $CBS_DROPDOWNLIST)
    GUICtrlSetData($hMDXHighEndProcess, "none|mirroring|mirroring2", "mirroring")
    ; Remaining controls
    Local $iDetailsY = $iMDXStartY + 100
    $hFocusLabel = GUICtrlCreateLabel("Focus:", $iRightQuadX + 5, $iDetailsY, 80, 20)
    $hFocusDisplay = GUICtrlCreateLabel("", $iRightQuadX + 85, $iDetailsY, $iQuadWidth - 90, 20)
    GUICtrlCreateLabel("Description:", $iRightQuadX + 5, $iDetailsY + 25, 80, 20)
    $hDescEdit = GUICtrlCreateEdit("", $iRightQuadX + 5, $iDetailsY + 45, $iQuadWidth - 10, 30, BitOR($ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL))
    GUICtrlCreateLabel("Comments:", $iRightQuadX + 5, $iDetailsY + 80, 80, 20)
    $hCommentsEdit = GUICtrlCreateEdit("", $iRightQuadX + 5, $iDetailsY + 100, $iQuadWidth - 10, 30, BitOR($ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL))

    GUICtrlCreateTabItem("")

    ; Process Queue (Bottom Right)
    GUICtrlCreateGroup("PROCESS QUEUE", $iRightQuadX, $iBottomQuadY - 30, $iQuadWidth, $iQuadHeight + 30)
    $hAddButton = GUICtrlCreateButton("Add", $iRightQuadX + 5, $iBottomQuadY - 10, 50, 25)
    GUICtrlSetOnEvent($hAddButton, "_AddButtonHandler")
    $hClearButton = GUICtrlCreateButton("Clear", $iRightQuadX + 60, $iBottomQuadY - 10, 50, 25)
    GUICtrlSetOnEvent($hClearButton, "_ClearButtonHandler")
    $hDeleteButton = GUICtrlCreateButton("Delete", $iRightQuadX + 115, $iBottomQuadY - 10, 50, 25)
    GUICtrlSetOnEvent($hDeleteButton, "_DeleteButtonHandler")
    $hBatchList = GUICtrlCreateListView("", $iRightQuadX + 5, $iBottomQuadY + 20, $iQuadWidth - 10, $iQuadHeight - 50, BitOR($LVS_REPORT, $LVS_SINGLESEL, $LVS_NOCOLUMNHEADER, $LVS_LIST, $LVS_SHOWSELALWAYS))
    GUICtrlSetStyle($hBatchList, $LVS_NOCOLUMNHEADER)
    _GUICtrlListView_SetColumn($hBatchList, 0, "", $iQuadWidth - 10)
    _GUICtrlListView_SetExtendedListViewStyle($hBatchList, $LVS_EX_CHECKBOXES)
    $hSeparateButton = GUICtrlCreateButton("Separate", $iRightQuadX + 5, $iBottomQuadY + $iQuadHeight - 25, 70, 25)
    GUICtrlSetOnEvent($hSeparateButton, "_SeparateButtonHandler")
    $hSaveSettingsButton = GUICtrlCreateButton("Save Settings", $iRightQuadX + 80, $iBottomQuadY + $iQuadHeight - 25, 90, 25)
    GUICtrlSetOnEvent($hSaveSettingsButton, "_SaveSettingsButtonHandler")
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    ; Progress Bar and Labels
    $hGraphicGUI = GUICreate("", $iGuiWidth - 20, 20, 10, $iGuiHeight - 35, $WS_POPUP, $WS_EX_MDICHILD, $hMainGUI)
    $hDC = _WinAPI_GetDC($hGraphicGUI)
    $hGraphics = _GDIPlus_GraphicsCreateFromHDC($hDC)
    $hPen = _GDIPlus_PenCreate($GOOGLE_BLUE, 2)
    $hBrushGray = _GDIPlus_BrushCreateSolid($GRAY)
    $hBrushGreen = _GDIPlus_BrushCreateSolid($GOOGLE_GREEN)
    $hBrushYellow = _GDIPlus_BrushCreateSolid($GOOGLE_YELLOW)
    _GDIPlus_GraphicsDrawRect($hGraphics, 0, 0, $iGuiWidth - 20, 20, $hPen)
    $hProgressLabel = GUICtrlCreateLabel("Task Progress: 0%", 10, $iGuiHeight - 65, $iGuiWidth - 20, 20)
    $hCountLabel = GUICtrlCreateLabel("Tasks Completed: 0/0", 10, $iGuiHeight - 85, $iGuiWidth - 20, 20)

    ; Ensure both GUI windows are shown
    GUISetState(@SW_SHOW, $hMainGUI)
    GUISetState(@SW_SHOW, $hGraphicGUI)

    _Log("Exiting _CreateGUI")
EndFunc
#EndRegion ;**** GUI Creation ****
#EndRegion Part2



;**************************************************
;********************Part 3************************
;**************************************************
#Region Part3
#Region ;**** Processing Functions ****
Func _ProcessFile($sFile, $sModel, $sOutputDir)
    _Log("Entering _ProcessFile: File=" & $sFile & ", Model=" & $sModel & ", OutputDir=" & $sOutputDir)
    Local $aDetails = _GetModelDetails($sModel)
    If @error Then
        _Log("Failed to get model details for " & $sModel, True)
        Return False
    EndIf
    Local $sApp = $aDetails[0] ; ModelApps.App
    _Log("Processing with " & $sApp & " model: " & $sModel)

    Local $bSuccess = False
    Switch $sApp
        Case "Demucs"
            $bSuccess = _ProcessDemucs($sFile, $sModel, $sOutputDir)
        Case "Spleeter"
            $bSuccess = _ProcessSpleeter($sFile, $sModel, $sOutputDir)
        Case "UVR5"
            $bSuccess = _ProcessUVR5($sFile, $sModel, $sOutputDir)
        Case Else
            _Log("Unsupported application: " & $sApp, True)
            MsgBox($MB_ICONERROR, "Error", "Unsupported application: " & $sApp)
            Return False
    EndSwitch

    If Not $bSuccess Then
        _Log("Failed to process " & $sFile & " with model " & $sModel, True)
        Local $sExpectedOutputs = $aDetails[3] ; Number of stems
        MsgBox($MB_ICONERROR, "Error", "Failed to process " & $sFile & @CRLF & "Expected " & $sExpectedOutputs & " output files, found 0")
        Return False
    EndIf

    _Log("Successfully processed " & $sFile)
    Return True
EndFunc

Func _ProcessDemucs($sFile, $sModel, $sOutputDir)
    _Log("Entering _ProcessDemucs: File=" & $sFile & ", Model=" & $sModel & ", OutputDir=" & $sOutputDir)
    ; Placeholder for Demucs processing
    _Log("Demucs processing not implemented in this example")
    Return False
EndFunc

Func _ProcessSpleeter($sFile, $sModel, $sOutputDir)
    _Log("Entering _ProcessSpleeter: File=" & $sFile & ", Model=" & $sModel & ", OutputDir=" & $sOutputDir)
    ; Placeholder for Spleeter processing
    _Log("Spleeter processing not implemented in this example")
    Return False
EndFunc

Func _ProcessUVR5($sFile, $sModel, $sOutputDir)
    _Log("Entering _ProcessUVR5: File=" & $sFile & ", Model=" & $sModel & ", OutputDir=" & $sOutputDir)
    Local $sVirtualEnv = @ScriptDir & "\installs\UVR\uvr_env\Scripts\activate.bat"
    If Not FileExists($sVirtualEnv) Then
        _Log("Virtual environment not found: " & $sVirtualEnv, True)
        Return False
    EndIf
    _Log("Virtual environment found: " & $sVirtualEnv)

    Local $aDetails = _GetModelDetails($sModel)
    If @error Then
        _Log("Failed to get model details for " & $sModel, True)
        Return False
    EndIf
    Local $sModelPath = $aDetails[4] ; Models.Path
    If Not FileExists($sModelPath) Then
        _Log("Model file not found: " & $sModelPath, True)
        Return False
    EndIf
    _Log("Resolved model path: " & $sModelPath)

    Local $sPythonPath = @ScriptDir & "\installs\UVR\uvr_env\Scripts\python.exe"
    Local $sScriptPath = @ScriptDir & "\installs\UVR\uvr-main\separate.py"
    Local $sSegmentSize = GUICtrlRead($hMDXSegmentSize)
    Local $sOverlap = GUICtrlRead($hMDXOverlap)
    Local $sDenoise = GUICtrlRead($hMDXDenoise) = $GUI_CHECKED ? "true" : "false"
    Local $sBatchSize = GUICtrlRead($hMDXBatchSize)
    Local $sAggressiveness = GUICtrlRead($hMDXAggressiveness)
    Local $sTTA = GUICtrlRead($hMDXTTA) = $GUI_CHECKED ? "true" : "false"
    Local $sHighEndProcess = GUICtrlRead($hMDXHighEndProcess)

    Local $sCommand = 'cmd /c "' & $sVirtualEnv & ' && "' & $sPythonPath & '" "' & $sScriptPath & '" --model "' & $sModelPath & '" --input_file "' & $sFile & '" --output_dir "' & $sOutputDir & '" --segment_size ' & $sSegmentSize & ' --overlap ' & $sOverlap & ' --denoise ' & $sDenoise & ' --batch_size ' & $sBatchSize & ' --aggressiveness ' & $sAggressiveness & ' --tta ' & $sTTA & ' --high_end_process "' & $sHighEndProcess & '" && exit'
    _Log("UVR5 command: " & $sCommand)

    Local $sLogFile = @ScriptDir & "\logs\uvr5_log.txt"
    Local $hLogFile = FileOpen($sLogFile, 2)
    If $hLogFile = -1 Then
        _Log("Failed to open log file for writing: " & $sLogFile, True)
        Return False
    EndIf
    _Log("Opened uvr5_log.txt for writing")

    Local $iPID = Run($sCommand, "", @SW_HIDE, $STDERR_MERGED)
    _Log("Started UVR5 process with PID: " & $iPID)
    Local $sOutput
    While 1
        $sOutput = StdoutRead($iPID)
        If @error Then ExitLoop
        If $sOutput <> "" Then
            FileWrite($hLogFile, $sOutput)
            _Log("[UVR5 STDOUT] " & $sOutput)
        EndIf
        $sOutput = StderrRead($iPID)
        If @error Then ExitLoop
        If $sOutput <> "" Then
            FileWrite($hLogFile, $sOutput)
            _Log("[UVR5 STDERR] " & $sOutput)
        EndIf
    WEnd
    FileClose($hLogFile)

    Local $iExitCode = ProcessWaitClose($iPID)
    _Log("UVR5 process exited with code: " & $iExitCode)
    If $iExitCode <> 0 Then
        _Log("UVR5 process failed with exit code: " & $iExitCode, True)
        Return False
    EndIf

    ; Verify output files (simplified for this example)
    Local $sBaseName = StringRegExpReplace($sFile, "^.*\\", "")
    Local $sVocals = $sOutputDir & "\" & $sBaseName & "_vocals.wav"
    Local $sInstrumental = $sOutputDir & "\" & $sBaseName & "_instrumental.wav"
    If FileExists($sVocals) And FileExists($sInstrumental) Then
        _Log("Output files generated: " & $sVocals & ", " & $sInstrumental)
        Return True
    Else
        _Log("Failed to find expected output files for " & $sFile, True)
        Return False
    EndIf
EndFunc

Func _SaveModelDetails($sModel, $sDescription, $sComments)
    _Log("Entering _SaveModelDetails: Model=" & $sModel)
    Local $sQuery = "UPDATE Models SET Description = '" & $sDescription & "', Comments = '" & $sComments & "' WHERE Name = '" & $sModel & "';"
    _Log("Executing query: " & $sQuery)
    Local $iRet = _SQLite_Exec($hDb, $sQuery)
    If $iRet <> $SQLITE_OK Then
        _Log("Failed to update model details for " & $sModel & ": " & _SQLite_ErrMsg(), True)
        Return False
    EndIf
    _Log("Successfully saved model details for " & $sModel)
    Return True
EndFunc

Func _IsModelCompatibleWithTab($sModel, $iTabIndex)
    _Log("Entering _IsModelCompatibleWithTab: Model=" & $sModel & ", TabIndex=" & $iTabIndex)
    Local $aDetails = _GetModelDetails($sModel)
    If @error Then
        _Log("Failed to get model details for compatibility check: " & $sModel, True)
        Return False
    EndIf
    Local $sApp = $aDetails[0] ; ModelApps.App
    Local $sExpectedApp
    Switch $iTabIndex
        Case 0
            $sExpectedApp = "Demucs"
        Case 1
            $sExpectedApp = "Spleeter"
        Case 2
            $sExpectedApp = "UVR5"
        Case Else
            _Log("Invalid tab index: " & $iTabIndex, True)
            Return False
    EndSwitch
    If $sApp = $sExpectedApp Then
        _Log("Model compatibility check: " & $sModel & " (App: " & $sApp & ") is compatible with tab " & $iTabIndex)
        Return True
    Else
        _Log("Model compatibility check: " & $sModel & " (App: " & $sApp & ") is not compatible with tab " & $iTabIndex & " (expected App: " & $sExpectedApp & ")", True)
        Return False
    EndIf
EndFunc
#EndRegion ;**** Processing Functions ****
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
    ; Save MDX-Net settings if in UVR5 tab
    If _GUICtrlTab_GetCurSel($hTab) = 2 Then
        _MDXSettingsHandler(False)
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
        ; Delete MDX-Net controls if they exist
        If $hMDXSegmentSize <> 0 Then
            GUICtrlDelete($hMDXSegmentSize)
            GUICtrlDelete($hMDXOverlap)
            GUICtrlDelete($hMDXDenoise)
            GUICtrlDelete($hMDXBatchSize)
            GUICtrlDelete($hMDXAggressiveness)
            GUICtrlDelete($hMDXTTA)
            GUICtrlDelete($hMDXHighEndProcess)
            ; Reset handles
            $hMDXSegmentSize = 0
            $hMDXOverlap = 0
            $hMDXDenoise = 0
            $hMDXBatchSize = 0
            $hMDXAggressiveness = 0
            $hMDXTTA = 0
            $hMDXHighEndProcess = 0
        EndIf
    EndIf

    ; Recreate controls based on the selected tab
    Local $iRightQuadX = ($iGuiWidth - 30) / 2 + 20
    Local $iTopQuadY = 35
    Local $iTabTopY = $iTopQuadY + 30
    Local $iQuadWidth = ($iGuiWidth - 30) / 2
    Local $iDetailsX = $iRightQuadX + 5
    Local $iDetailsWidth = $iQuadWidth - 10
    Local $iLabelHeight = 20
    Local $iLabelSpacing = 25

    ; Common controls for all tabs
    $hModelNameLabel = GUICtrlCreateLabel("Model Name:", $iRightQuadX + 5, $iTabTopY, 70, 20)
    $hModelCombo = GUICtrlCreateCombo("", $iRightQuadX + 80, $iTabTopY, 150, 25, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL, $WS_VSCROLL))
    $hStemsLabel = GUICtrlCreateLabel("Stems:", $iRightQuadX + 235, $iTabTopY, 40, 20)
    $hStemsDisplay = GUICtrlCreateLabel("", $iRightQuadX + 275, $iTabTopY, 30, 20)

    ; Tab-specific controls
    Local $iDetailsY = $iTabTopY + 30
    If $iTabIndex = 2 Then ; UVR5
        Local $iMDXStartY = $iTabTopY + 30
        ; Row 1: Segment Size + Overlap
        GUICtrlCreateLabel("Segment Size:", $iRightQuadX + 5, $iMDXStartY, 80, 20)
        $hMDXSegmentSize = GUICtrlCreateInput("256", $iRightQuadX + 85, $iMDXStartY, 60, 20, $ES_NUMBER)
        GUICtrlCreateLabel("Overlap (0-1):", $iRightQuadX + 155, $iMDXStartY, 80, 20)
        $hMDXOverlap = GUICtrlCreateInput("0.25", $iRightQuadX + 235, $iMDXStartY, 60, 20)
        ; Row 2: Denoise + TTA
        GUICtrlCreateLabel("Denoise:", $iRightQuadX + 5, $iMDXStartY + 25, 80, 20)
        $hMDXDenoise = GUICtrlCreateCheckbox("", $iRightQuadX + 85, $iMDXStartY + 25, 20, 20)
        GUICtrlCreateLabel("TTA:", $iRightQuadX + 155, $iMDXStartY + 25, 80, 20)
        $hMDXTTA = GUICtrlCreateCheckbox("", $iRightQuadX + 235, $iMDXStartY + 25, 20, 20)
        ; Row 3: Batch Size + Aggressiveness
        GUICtrlCreateLabel("Batch Size:", $iRightQuadX + 5, $iMDXStartY + 50, 80, 20)
        $hMDXBatchSize = GUICtrlCreateInput("1", $iRightQuadX + 85, $iMDXStartY + 50, 60, 20, $ES_NUMBER)
        GUICtrlCreateLabel("Aggressiveness (0-100):", $iRightQuadX + 155, $iMDXStartY + 50, 120, 20)
        $hMDXAggressiveness = GUICtrlCreateInput("10", $iRightQuadX + 275, $iMDXStartY + 50, 60, 20, $ES_NUMBER)
        ; Row 4: High End Process
        GUICtrlCreateLabel("High End Process:", $iRightQuadX + 5, $iMDXStartY + 75, 80, 20)
        $hMDXHighEndProcess = GUICtrlCreateCombo("", $iRightQuadX + 85, $iMDXStartY + 75, 100, 25, $CBS_DROPDOWNLIST)
        GUICtrlSetData($hMDXHighEndProcess, "none|mirroring|mirroring2", "mirroring")
        $iDetailsY = $iMDXStartY + 100
    EndIf

    $hFocusLabel = GUICtrlCreateLabel("Focus:", $iDetailsX, $iDetailsY, 80, $iLabelHeight)
    $hFocusDisplay = GUICtrlCreateLabel("", $iDetailsX + 80, $iDetailsY, $iDetailsWidth - 80, $iLabelHeight)
    $hDescLabel = GUICtrlCreateLabel("Description:", $iDetailsX, $iDetailsY + $iLabelSpacing, 80, $iLabelHeight)
    $hDescEdit = GUICtrlCreateEdit("", $iDetailsX, $iDetailsY + $iLabelSpacing + 20, $iDetailsWidth, 30, BitOR($ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL))
    $hCommentsLabel = GUICtrlCreateLabel("Comments:", $iDetailsX, $iDetailsY + $iLabelSpacing + 55, 80, $iLabelHeight)
    $hCommentsEdit = GUICtrlCreateEdit("", $iDetailsX, $iDetailsY + $iLabelSpacing + 75, $iDetailsWidth, 30, BitOR($ES_AUTOVSCROLL, $ES_WANTRETURN, $WS_VSCROLL))

    ; Set event handlers for the new controls
    GUICtrlSetOnEvent($hModelCombo, "_ModelComboHandler")
    GUICtrlSetOnEvent($hDescEdit, "_DescEditHandler")
    GUICtrlSetOnEvent($hCommentsEdit, "_CommentsEditHandler")

    ; Populate the combo box
    _UpdateModelDroplist()

    ; Load MDX-Net settings for UVR5 tab
    If $iTabIndex = 2 Then
        _MDXSettingsHandler(True)
    EndIf

    ; Set the default model for the current tab
    Local $sDefaultModel
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
            GUICtrlSetData($hModelCombo, $sDefaultModel)
            Local $sSelectedModel = GUICtrlRead($hModelCombo)
            If $sSelectedModel = $sDefaultModel Then
                _Log("Default model " & $sDefaultModel & " set successfully")
                Local $aDetails = _GetModelDetails($sDefaultModel)
                If Not @error Then
                    _UpdateModelDetails($sDefaultModel)
                Else
                    _Log("Failed to get details for default model " & $sDefaultModel, True)
                    _UpdateModelDetails("")
                EndIf
            Else
                _Log("Failed to set default model " & $sDefaultModel & ", current selection: " & $sSelectedModel, True)
                _UpdateModelDetails("")
            EndIf
        Else
            _Log("Default model " & $sDefaultModel & " not found or not compatible with tab " & $iTabIndex & ", selecting first available", True)
            Local $sFirstModel = StringSplit(GUICtrlRead($hModelCombo), "|")[2]
            If $sFirstModel <> "" And $sFirstModel <> "No models available" Then
                _Log("Falling back to first available model: " & $sFirstModel)
                GUICtrlSetData($hModelCombo, $sFirstModel)
                Local $sSelectedModel = GUICtrlRead($hModelCombo)
                If $sSelectedModel = $sFirstModel Then
                    Local $aDetails = _GetModelDetails($sFirstModel)
                    If Not @error Then
                        _UpdateModelDetails($sFirstModel)
                    Else
                        _Log("Failed to get details for first model " & $sFirstModel, True)
                        _UpdateModelDetails("")
                    EndIf
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

Func _MDXSettingsHandler($bLoad = True)
    _Log("Entering _MDXSettingsHandler: Load=" & ($bLoad ? "True" : "False"))
    If $bLoad Then
        ; Load MDX-Net settings from settings.ini
        Local $sSegmentSize = IniRead($sSettingsIni, "MDX", "SegmentSize", "256")
        Local $sOverlap = IniRead($sSettingsIni, "MDX", "Overlap", "0.25")
        Local $sDenoise = IniRead($sSettingsIni, "MDX", "Denoise", "0")
        Local $sBatchSize = IniRead($sSettingsIni, "MDX", "BatchSize", "1")
        Local $sAggressiveness = IniRead($sSettingsIni, "MDX", "Aggressiveness", "10")
        Local $sTTA = IniRead($sSettingsIni, "MDX", "TTA", "0")
        Local $sHighEndProcess = IniRead($sSettingsIni, "MDX", "HighEndProcess", "mirroring")
        GUICtrlSetData($hMDXSegmentSize, $sSegmentSize)
        GUICtrlSetData($hMDXOverlap, $sOverlap)
        GUICtrlSetState($hMDXDenoise, $sDenoise = "1" ? $GUI_CHECKED : $GUI_UNCHECKED)
        GUICtrlSetData($hMDXBatchSize, $sBatchSize)
        GUICtrlSetData($hMDXAggressiveness, $sAggressiveness)
        GUICtrlSetState($hMDXTTA, $sTTA = "1" ? $GUI_CHECKED : $GUI_UNCHECKED)
        GUICtrlSetData($hMDXHighEndProcess, $sHighEndProcess)
        _Log("Loaded MDX-Net settings: SegmentSize=" & $sSegmentSize & ", Overlap=" & $sOverlap & ", Denoise=" & $sDenoise & ", BatchSize=" & $sBatchSize & ", Aggressiveness=" & $sAggressiveness & ", TTA=" & $sTTA & ", HighEndProcess=" & $sHighEndProcess)
    Else
        ; Save MDX-Net settings to settings.ini
        IniWrite($sSettingsIni, "MDX", "SegmentSize", GUICtrlRead($hMDXSegmentSize))
        IniWrite($sSettingsIni, "MDX", "Overlap", GUICtrlRead($hMDXOverlap))
        IniWrite($sSettingsIni, "MDX", "Denoise", GUICtrlRead($hMDXDenoise) = $GUI_CHECKED ? "1" : "0")
        IniWrite($sSettingsIni, "MDX", "BatchSize", GUICtrlRead($hMDXBatchSize))
        IniWrite($sSettingsIni, "MDX", "Aggressiveness", GUICtrlRead($hMDXAggressiveness))
        IniWrite($sSettingsIni, "MDX", "TTA", GUICtrlRead($hMDXTTA) = $GUI_CHECKED ? "1" : "0")
        IniWrite($sSettingsIni, "MDX", "HighEndProcess", GUICtrlRead($hMDXHighEndProcess))
        _Log("Saved MDX-Net settings to settings.ini")
    EndIf
    _Log("Exiting _MDXSettingsHandler")
EndFunc

Func _Exit()
    _Log("Entering _Exit")
    ; Save MDX-Net settings if in UVR5 tab
    If _GUICtrlTab_GetCurSel($hTab) = 2 Then
        _MDXSettingsHandler(False)
    EndIf
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



;**************************************************
;********************Part 5************************
;**************************************************
#Region Part5
#Region ;**** Main Function ****
Func _Main()
    _Log("Entering _Main")

    ; Log startup information
    _LogStartupInfo()

    ; Initialize models
    If Not _InitializeModels() Then
        _Log("Failed to initialize models", True)
        Exit
    EndIf

    ; Create the GUI
    _CreateGUI()

    ; Set defaults (e.g., input/output paths, default tab, etc.)
    SetDefaults()

    _Log("GUI initialized and defaults set")

    ; Main loop to keep the GUI running
    While 1
        Sleep(100) ; Sleep to reduce CPU usage while waiting for events
    WEnd
EndFunc

Func SetDefaults()
    _Log("Entering SetDefaults")

    ; Set default tab (Demucs)
    _Log("Setting default tab to Demucs (index 0)")
    _GUICtrlTab_SetCurSel($hTab, 0)
    _Log("Triggering _TabHandler to initialize Demucs tab controls and set default model")
    _TabHandler()

    ; Set default input path
    $sInputPath = "C:\temp\s2S\songs"
    _Log("Setting default input path to " & $sInputPath)
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

    ; Set default output path
    $sOutputPath = "C:\temp\s2S\stems"
    _Log("Setting default output path to " & $sOutputPath)
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

    ; Add a default song to the Process Queue
    Local $sDefaultSong = "C:\temp\s2S\songs\song6.wav"
    _Log("Adding default song " & $sDefaultSong & " to Process Queue")
    Local $iIndex = _GUICtrlListView_AddItem($hBatchList, $sDefaultSong)
    _GUICtrlListView_SetItemChecked($hBatchList, $iIndex, True)
    _Log("Default song " & $sDefaultSong & " added and checked successfully")

    _Log("Exiting SetDefaults")
EndFunc
#EndRegion ;**** Main Function ****

; Start the script
_Main()
#EndRegion Part5
