#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <EditConstants.au3>
#include <StringConstants.au3>
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>
#include <String.au3>
#include <Array.au3>
#include <File.au3>
#include <ComboConstants.au3>
#include <ProgressConstants.au3>
#include <StaticConstants.au3>
#include <GuiButton.au3>
#include <MsgBoxConstants.au3>

Global $g_sIniPath = @ScriptDir & "\models.ini"
Global $g_sUserSettingsPath = @ScriptDir & "\usersettings.ini"
Global $g_sLogPath = @ScriptDir & "\logs\gui_log.txt"
Global $g_sModelsDir = "C:\Git\3DAudioStudio\models\"
Global $g_aModels[1][15]
Global $idArchitectureCombo, $idModelCombo, $idQualityCombo, $idInputFile, $idOutputDir, $idOutputList, $idRunButton
Global $idInputBrowseButton, $idOutputBrowseButton
Global $idComboChunks, $idComboOverlap, $idComboNFFT, $idComboDimF, $idComboDimT
Global $idComboShifts, $idComboWindowSize, $idComboAggression
Global $idStemCombo, $idGPUConversion, $idPrimaryStemOnly, $idSecondaryStemOnly
Global $idBtnSaveSettings, $idBtnLoadSettings, $idBtnImportModels
Global $idProgressLabel, $idProgressBar
Global $idGroupMDX, $idGroupDemucs, $idGroupVR, $idGroupBandit, $idGroupRoformer, $idGroupSCnet
Global $idComboMarginMDX, $idComboMarginDemucs, $idComboMarginBandit, $idComboMarginRoformer

; GUI dimensions based on screen size (75%)
Global $iGuiWidth = @DesktopWidth * 0.75
Global $iGuiHeight = @DesktopHeight * 0.75
Global $iFontSize = 14
Global $iListViewFontSize = $iFontSize - 2
Global $sFontName = "Segoe UI"

Func LogMessage($sLevel, $sMessage)
    Local $sLogDir = @ScriptDir & "\logs"
    If Not FileExists($sLogDir) Then
        DirCreate($sLogDir)
    EndIf

    Local $sLogEntry = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & " - " & $sLevel & " - " & $sMessage & @CRLF
    FileWrite($g_sLogPath, $sLogEntry)
EndFunc

Func DiscoverModels()
    If Not FileExists($g_sModelsDir) Then
        DirCreate($g_sModelsDir)
        LogMessage("INFO", "Created models directory: " & $g_sModelsDir)
    EndIf

    LogMessage("INFO", "Starting model discovery in directory: " & $g_sModelsDir)
    Local $aAllFiles = _FileListToArrayRec($g_sModelsDir, "*.*", $FLTAR_FILES + $FLTAR_RECUR, $FLTAR_SORT, $FLTAR_FULLPATH)
    If @error Then
        If @error = 1 Then
            LogMessage("INFO", "No files found in models directory: " & $g_sModelsDir & ". Please add model files to proceed.")
        Else
            LogMessage("ERROR", "Failed to list files in models directory: " & $g_sModelsDir & ". Error code: " & @error)
        EndIf
        GUICtrlSetData($idModelCombo, "No models found")
        Return
    EndIf

    LogMessage("INFO", "Found " & $aAllFiles[0] & " files in models directory.")
    Local $iSkippedFiles = 0
    Local $iProcessedModels = 0

    For $i = 1 To $aAllFiles[0]
        Local $sFilePath = $aAllFiles[$i]
        Local $sExt = StringLower(StringRegExpReplace($sFilePath, "^.*\.", ""))
        If $sExt = "yaml" Then
            $iSkippedFiles += 1
            LogMessage("DEBUG", "Skipped file (not a model): " & $sFilePath)
            ContinueLoop
        EndIf

        Local $sArchitecture = ""
        If StringInStr($sFilePath, "\MDXNet\") Then
            $sArchitecture = "MDX-Net"
        ElseIf StringInStr($sFilePath, "\MDX23C\") Then
            $sArchitecture = "MDX-Net"
        ElseIf StringInStr($sFilePath, "\Demucs\") Then
            $sArchitecture = "Demucs"
        ElseIf StringInStr($sFilePath, "\VR_Arch\") Then
            $sArchitecture = "VR"
        ElseIf StringInStr($sFilePath, "\Bandit\") Then
            $sArchitecture = "Bandit"
        ElseIf StringInStr($sFilePath, "\Roformer\") Then
            $sArchitecture = "Roformer"
        ElseIf StringInStr($sFilePath, "\SCnet\") Then
            $sArchitecture = "SCnet"
        Else
            $iSkippedFiles += 1
            LogMessage("WARNING", "Skipping file with unknown architecture: " & $sFilePath)
            ContinueLoop
        EndIf

        Local $sModelName = StringRegExpReplace($sFilePath, "^.*\\", "")
        $sModelName = StringRegExpReplace($sModelName, "\.(onnx|th|ckpt|pth)$", "")

        Local $sExistingArch = IniRead($g_sIniPath, $sModelName, "Architecture", "")
        If $sExistingArch = "" Or $sExistingArch <> $sArchitecture Then
            $iProcessedModels += 1
            LogMessage("INFO", "Adding/Updating model: " & $sModelName & " (" & $sArchitecture & ") at path: " & $sFilePath)
            IniWrite($g_sIniPath, $sModelName, "Path", $sFilePath)
            IniWrite($g_sIniPath, $sModelName, "Architecture", $sArchitecture)
            IniWrite($g_sIniPath, $sModelName, "EnvPath", "@ScriptDir@\installs\UVR\uvr_env\Scripts")
            IniWrite($g_sIniPath, $sModelName, "PythonScript", "separate.py")
            IniWrite($g_sIniPath, $sModelName, "OutputFormat", "wav")
            Switch $sArchitecture
                Case "MDX-Net"
                    If StringInStr($sFilePath, "\MDX23C\") Then
                        IniWrite($g_sIniPath, $sModelName, "CommandLine", "cmd /c ""cd @EnvPath@ && activate.bat && cd @ScriptDir@ && python @PythonScript@ ""@SongPath@"" -m ""@Path@"" -o ""@OutputDir@"" --chunks @Chunks@ --mdx23_overlap @Overlap@ --margin @Margin@ --n_fft @NFFT@ --dim_f @DimF@ --dim_t @DimT@ --stem ""@Stem@"" && deactivate""")
                        IniWrite($g_sIniPath, $sModelName, "FastSettings", "256,8,44100,4096,2048,8")
                        IniWrite($g_sIniPath, $sModelName, "NormalSettings", "1024,8,44100,6144,3072,32")
                        IniWrite($g_sIniPath, $sModelName, "HighSettings", "2048,16,44100,16384,4096,64")
                    Else
                        IniWrite($g_sIniPath, $sModelName, "CommandLine", "cmd /c ""cd @EnvPath@ && activate.bat && cd @ScriptDir@ && python @PythonScript@ ""@SongPath@"" -m ""@Path@"" -o ""@OutputDir@"" --chunks @Chunks@ --margin @Margin@ --overlap @Overlap@ --n_fft @NFFT@ --dim_f @DimF@ --dim_t @DimT@ --stem ""@Stem@"" && deactivate""")
                        IniWrite($g_sIniPath, $sModelName, "FastSettings", "256,0.5,44100,4096,2048,8")
                        IniWrite($g_sIniPath, $sModelName, "NormalSettings", "1024,0.5,44100,6144,3072,32")
                        IniWrite($g_sIniPath, $sModelName, "HighSettings", "2048,0.75,44100,16384,4096,64")
                    EndIf
                    IniWrite($g_sIniPath, $sModelName, "OutputStems", "vocals,instrumental")
                    IniWrite($g_sIniPath, $sModelName, "Denoise", "True")
                Case "Demucs"
                    IniWrite($g_sIniPath, $sModelName, "CommandLine", "cmd /c ""cd @EnvPath@ && activate.bat && cd @ScriptDir@ && python @PythonScript@ ""@SongPath@"" -m ""@Path@"" -o ""@OutputDir@"" --segment @Segment@ --margin @Margin@ --overlap @Overlap@ --shifts @Shifts@ --stem ""@Stem@"" && deactivate""")
                    IniWrite($g_sIniPath, $sModelName, "FastSettings", "1,0.25,44100,2")
                    IniWrite($g_sIniPath, $sModelName, "NormalSettings", "Default,0.5,44100,2")
                    IniWrite($g_sIniPath, $sModelName, "HighSettings", "50,0.75,44100,10")
                    If StringInStr($sModelName, "htdemucs_6s") Then
                        IniWrite($g_sIniPath, $sModelName, "OutputStems", "vocals,other,bass,drums,guitar,piano")
                    Else
                        IniWrite($g_sIniPath, $sModelName, "OutputStems", "vocals,other,bass,drums")
                    EndIf
                Case "VR"
                    IniWrite($g_sIniPath, $sModelName, "CommandLine", "cmd /c ""cd @EnvPath@ && activate.bat && cd @ScriptDir@ && python @PythonScript@ ""@SongPath@"" -m ""@Path@"" -o ""@OutputDir@"" --window_size @WindowSize@ --aggression @Aggression@ --stem ""@Stem@"" && deactivate""")
                    IniWrite($g_sIniPath, $sModelName, "FastSettings", "1024,0")
                    IniWrite($g_sIniPath, $sModelName, "NormalSettings", "512,5")
                    IniWrite($g_sIniPath, $sModelName, "HighSettings", "320,10")
                    IniWrite($g_sIniPath, $sModelName, "OutputStems", "vocals,instrumental")
                Case "Bandit"
                    IniWrite($g_sIniPath, $sModelName, "CommandLine", "cmd /c ""cd @EnvPath@ && activate.bat && cd @ScriptDir@ && python @PythonScript@ ""@SongPath@"" -m ""@Path@"" -o ""@OutputDir@"" --chunks @Chunks@ --margin @Margin@ --overlap @Overlap@ --stem ""@Stem@"" && deactivate""")
                    IniWrite($g_sIniPath, $sModelName, "FastSettings", "256,0.5,44100")
                    IniWrite($g_sIniPath, $sModelName, "NormalSettings", "1024,0.5,44100")
                    IniWrite($g_sIniPath, $sModelName, "HighSettings", "2048,0.75,44100")
                    IniWrite($g_sIniPath, $sModelName, "OutputStems", "vocals,instrumental")
                Case "Roformer"
                    IniWrite($g_sIniPath, $sModelName, "CommandLine", "cmd /c ""cd @EnvPath@ && activate.bat && cd @ScriptDir@ && python @PythonScript@ ""@SongPath@"" -m ""@Path@"" -o ""@OutputDir@"" --chunks @Chunks@ --margin @Margin@ --overlap @Overlap@ --stem ""@Stem@"" && deactivate""")
                    IniWrite($g_sIniPath, $sModelName, "FastSettings", "256,0.5,44100")
                    IniWrite($g_sIniPath, $sModelName, "NormalSettings", "1024,0.5,44100")
                    IniWrite($g_sIniPath, $sModelName, "HighSettings", "2048,0.75,44100")
                    IniWrite($g_sIniPath, $sModelName, "OutputStems", "vocals,instrumental")
                Case "SCnet"
                    IniWrite($g_sIniPath, $sModelName, "CommandLine", "cmd /c ""cd @EnvPath@ && activate.bat && cd @ScriptDir@ && python @PythonScript@ ""@SongPath@"" -m ""@Path@"" -o ""@OutputDir@"" --window_size @WindowSize@ --aggression @Aggression@ --stem ""@Stem@"" && deactivate""")
                    IniWrite($g_sIniPath, $sModelName, "FastSettings", "1024,0")
                    IniWrite($g_sIniPath, $sModelName, "NormalSettings", "512,5")
                    IniWrite($g_sIniPath, $sModelName, "HighSettings", "320,10")
                    IniWrite($g_sIniPath, $sModelName, "OutputStems", "vocals,instrumental")
            EndSwitch
        EndIf
    Next
    LogMessage("INFO", "Model discovery completed. Total files processed: " & $aAllFiles[0] & ", Models added/updated: " & $iProcessedModels & ", Files skipped: " & $iSkippedFiles)
EndFunc

Func CreateGUI()
    LogMessage("DEBUG", "CreateGUI() called")
    LogMessage("DEBUG", "GUI size set to " & $iGuiWidth & "x" & $iGuiHeight)

    GUICreate("Audio Separation", $iGuiWidth, $iGuiHeight)

    ; Relative dimensions (percentages of GUI width/height)
    Local $iPadding = $iGuiWidth * 0.01 ; 1% of GUI width
    Local $iLabelX = $iPadding
    Local $iLabelWidth = 200 ; Initial width, will adjust dynamically
    Local $iControlHeight = 25
    Local $iRowSpacing = 30
    Local $iY = $iPadding

    ; Create labels first to calculate widest label
    Local $idLabelProcess = GUICtrlCreateLabel("Choose Process Method:", $iLabelX, $iY, $iLabelWidth, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iY += $iRowSpacing

    Local $idLabelModel = GUICtrlCreateLabel("Select Model:", $iLabelX, $iY, $iLabelWidth, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iY += $iRowSpacing

    Local $idLabelQuality = GUICtrlCreateLabel("Quality:", $iLabelX, $iY, $iLabelWidth, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iY += $iRowSpacing

    Local $idLabelInput = GUICtrlCreateLabel("Input Audio File:", $iLabelX, $iY, $iLabelWidth, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iY += $iRowSpacing

    Local $idLabelOutput = GUICtrlCreateLabel("Output Directory:", $iLabelX, $iY, $iLabelWidth, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iY += $iRowSpacing

    Local $idLabelStem = GUICtrlCreateLabel("Select Stem:", $iLabelX, $iY, $iLabelWidth, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iY += $iRowSpacing

    ; Calculate widest label
    Local $aLabels[6] = [$idLabelProcess, $idLabelModel, $idLabelQuality, $idLabelInput, $idLabelOutput, $idLabelStem]
    Local $iWidestLabel = 0
    For $i = 0 To 5
        Local $aPos = GUICtrlGetPos($aLabels[$i])
        If $aPos[2] > $iWidestLabel Then
            $iWidestLabel = $aPos[2]
        EndIf
    Next
    $iLabelWidth = $iWidestLabel
    LogMessage("DEBUG", "Widest label width: " & $iWidestLabel & " pixels")

    ; Adjust label widths to match widest label
    For $i = 0 To 5
        GUICtrlSetPos($aLabels[$i], $iLabelX, GUICtrlGetPos($aLabels[$i])[1], $iLabelWidth, $iControlHeight)
    Next

    ; Control positions
    Local $iControlX = $iLabelX + $iLabelWidth + $iPadding
    Local $iControlWidth = ($iGuiWidth - $iControlX - $iPadding * 3 - 80) ; Subtract space for "Browse" buttons
    Local $iComboWidth = 150
    Local $iButtonWidth = 80

    ; Reset Y for controls
    $iY = $iPadding

    ; Choose Process Method
    $idArchitectureCombo = GUICtrlCreateCombo("MDX-Net", $iControlX, $iY, $iComboWidth, $iControlHeight, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "Demucs|VR|Bandit|Roformer|SCnet")
    LogMessage("DEBUG", "Architecture Combo at x=" & $iControlX & ", y=" & $iY)
    $iY += $iRowSpacing

    ; Select Model
    $idModelCombo = GUICtrlCreateCombo("", $iControlX, $iY, $iComboWidth * 1.5, $iControlHeight, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    LogMessage("DEBUG", "Model Combo at x=" & $iControlX & ", y=" & $iY)
    $iY += $iRowSpacing

    ; Quality
    $idQualityCombo = GUICtrlCreateCombo("Normal", $iControlX, $iY, $iComboWidth, $iControlHeight, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "Fast|Normal|High")
    LogMessage("DEBUG", "Quality Combo at x=" & $iControlX & ", y=" & $iY)
    $iY += $iRowSpacing

    ; Input Audio File
    $idInputFile = GUICtrlCreateInput("", $iControlX, $iY, $iControlWidth, $iControlHeight, $ES_READONLY)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idInputBrowseButton = GUICtrlCreateButton("Browse", $iGuiWidth - $iButtonWidth - $iPadding, $iY, $iButtonWidth, $iControlHeight)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    LogMessage("DEBUG", "Input File at x=" & $iControlX & ", y=" & $iY & ", Browse Button at x=" & ($iGuiWidth - $iButtonWidth - $iPadding))
    $iY += $iRowSpacing

    ; Output Directory
    $idOutputDir = GUICtrlCreateInput(@ScriptDir & "\stems", $iControlX, $iY, $iControlWidth, $iControlHeight, $ES_READONLY)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idOutputBrowseButton = GUICtrlCreateButton("Browse", $iGuiWidth - $iButtonWidth - $iPadding, $iY, $iButtonWidth, $iControlHeight)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    LogMessage("DEBUG", "Output Dir at x=" & $iControlX & ", y=" & $iY & ", Browse Button at x=" & ($iGuiWidth - $iButtonWidth - $iPadding))
    $iY += $iRowSpacing

    ; Select Stem
    $idStemCombo = GUICtrlCreateCombo("All", $iControlX, $iY, $iComboWidth, $iControlHeight, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    LogMessage("DEBUG", "Stem Combo at x=" & $iControlX & ", y=" & $iY)
    $iY += $iRowSpacing

    ; Checkboxes
    Local $iCheckBoxWidth = $iGuiWidth * 0.15 ; 15% of GUI width
    $idGPUConversion = GUICtrlCreateCheckbox("GPU Conversion", $iControlX, $iY, $iCheckBoxWidth, $iControlHeight)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idPrimaryStemOnly = GUICtrlCreateCheckbox("Primary Stem Only", $iControlX + $iCheckBoxWidth + $iPadding, $iY, $iCheckBoxWidth, $iControlHeight)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idSecondaryStemOnly = GUICtrlCreateCheckbox("Secondary Stem Only", $iControlX + 2 * ($iCheckBoxWidth + $iPadding), $iY, $iCheckBoxWidth, $iControlHeight)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    LogMessage("DEBUG", "Checkboxes at x=" & $iControlX & ", y=" & $iY & ", spacing=" & $iCheckBoxWidth)
    $iY += $iRowSpacing + $iPadding

    ; Parameter Groups
    Local $iGroupWidth = $iGuiWidth - 2 * $iPadding
    Local $iGroupX = $iPadding
    Local $iLabelWidthParam = 80
    Local $iComboWidthParam = 80
    Local $iParamRowSpacing = 30
    Local $iParamPadding = $iPadding

    ; MDX-Net Parameters (6 controls, 2 rows, 3 per row)
    $idGroupMDX = GUICtrlCreateGroup("MDX-Net Parameters", $iGroupX, $iY, $iGroupWidth, 90)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    Local $iParamY = $iY + 20
    Local $iParamX = $iGroupX + $iParamPadding
    Local $iControlsPerRow = 3
    Local $iControlSpacing = ($iGroupWidth - 2 * $iParamPadding - $iControlsPerRow * ($iLabelWidthParam + $iComboWidthParam + $iParamPadding)) / ($iControlsPerRow - 1)

    ; Row 1: Chunks, Overlap, Margin
    GUICtrlCreateLabel("Chunks:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboChunks = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "32|256|512|1024|1056|1088|1120|1152|1184|1216|1248|1280|1312|2048|3072|4000", "256")

    $iParamX += $iLabelWidthParam + $iComboWidthParam + $iControlSpacing + $iParamPadding
    GUICtrlCreateLabel("Overlap:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboOverlap = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "0.25|0.5|0.75|0.99", "0.5")

    $iParamX += $iLabelWidthParam + $iComboWidthParam + $iControlSpacing + $iParamPadding
    GUICtrlCreateLabel("Margin:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboMarginMDX = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "44100|22050|11025", "44100")

    ; Row 2: NFFT, DimF, DimT
    $iParamY += $iParamRowSpacing
    $iParamX = $iGroupX + $iParamPadding

    GUICtrlCreateLabel("NFFT:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboNFFT = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "4096|5120|6144|7680|8192|16384", "6144")

    $iParamX += $iLabelWidthParam + $iComboWidthParam + $iControlSpacing + $iParamPadding
    GUICtrlCreateLabel("DimF:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboDimF = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "2048|3072|4096", "2048")

    $iParamX += $iLabelWidthParam + $iComboWidthParam + $iControlSpacing + $iParamPadding
    GUICtrlCreateLabel("DimT:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboDimT = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "8|16|32|48|64", "32")
    GUICtrlSetTip(-1, "Time dimension for MDX-Net models")
    GUICtrlCreateGroup("", -99, -99, 1, 1)
    LogMessage("DEBUG", "MDX-Net Group: 2 rows, 3 controls per row, spacing=" & $iControlSpacing)

    ; Demucs Parameters (4 controls, 2 rows, 2 per row)
    $idGroupDemucs = GUICtrlCreateGroup("Demucs Parameters", $iGroupX, $iY, $iGroupWidth, 90)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iParamY = $iY + 20
    $iParamX = $iGroupX + $iParamPadding
    $iControlsPerRow = 2
    $iControlSpacing = ($iGroupWidth - 2 * $iParamPadding - $iControlsPerRow * ($iLabelWidthParam + $iComboWidthParam + $iParamPadding)) / ($iControlsPerRow - 1)

    ; Row 1: Segment, Overlap
    GUICtrlCreateLabel("Segment:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboChunks = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "Default|1|5|10|15|20|25|30|35|40|45|50|55|60|65|70|75|80|85|90|95|100", "Default")

    $iParamX += $iLabelWidthParam + $iComboWidthParam + $iControlSpacing + $iParamPadding
    GUICtrlCreateLabel("Overlap:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboOverlap = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "0.25|0.5|0.75|0.99", "0.5")

    ; Row 2: Margin, Shifts
    $iParamY += $iParamRowSpacing
    $iParamX = $iGroupX + $iParamPadding

    GUICtrlCreateLabel("Margin:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboMarginDemucs = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "44100|22050|11025", "44100")

    $iParamX += $iLabelWidthParam + $iComboWidthParam + $iControlSpacing + $iParamPadding
    GUICtrlCreateLabel("Shifts:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboShifts = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20", "2")
    GUICtrlCreateGroup("", -99, -99, 1, 1)
    LogMessage("DEBUG", "Demucs Group: 2 rows, 2 controls per row, spacing=" & $iControlSpacing)

    ; VR Parameters (2 controls, 1 row)
    $idGroupVR = GUICtrlCreateGroup("VR Parameters", $iGroupX, $iY, $iGroupWidth, 60)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iParamY = $iY + 20
    $iParamX = $iGroupX + $iParamPadding
    $iControlsPerRow = 2
    $iControlSpacing = ($iGroupWidth - 2 * $iParamPadding - $iControlsPerRow * ($iLabelWidthParam + $iComboWidthParam + $iParamPadding)) / ($iControlsPerRow - 1)

    GUICtrlCreateLabel("Window Size:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboWindowSize = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "320|512|1024", "512")

    $iParamX += $iLabelWidthParam + $iComboWidthParam + $iControlSpacing + $iParamPadding
    GUICtrlCreateLabel("Aggression:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboAggression = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46|47|48|49|50", "5")
    GUICtrlCreateGroup("", -99, -99, 1, 1)
    LogMessage("DEBUG", "VR Group: 1 row, 2 controls, spacing=" & $iControlSpacing)

    ; Bandit Parameters (3 controls, 1 row)
    $idGroupBandit = GUICtrlCreateGroup("Bandit Parameters", $iGroupX, $iY, $iGroupWidth, 60)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iParamY = $iY + 20
    $iParamX = $iGroupX + $iParamPadding
    $iControlsPerRow = 3
    $iControlSpacing = ($iGroupWidth - 2 * $iParamPadding - $iControlsPerRow * ($iLabelWidthParam + $iComboWidthParam + $iParamPadding)) / ($iControlsPerRow - 1)

    GUICtrlCreateLabel("Chunks:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboChunks = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "32|256|512|1024|1056|1088|1120|1152|1184|1216|1248|1280|1312|2048|3072|4000", "256")

    $iParamX += $iLabelWidthParam + $iComboWidthParam + $iControlSpacing + $iParamPadding
    GUICtrlCreateLabel("Overlap:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboOverlap = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "0.25|0.5|0.75|0.99", "0.5")

    $iParamX += $iLabelWidthParam + $iComboWidthParam + $iControlSpacing + $iParamPadding
    GUICtrlCreateLabel("Margin:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboMarginBandit = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "44100|22050|11025", "44100")
    GUICtrlCreateGroup("", -99, -99, 1, 1)
    LogMessage("DEBUG", "Bandit Group: 1 row, 3 controls, spacing=" & $iControlSpacing)

    ; Roformer Parameters (3 controls, 1 row)
    $idGroupRoformer = GUICtrlCreateGroup("Roformer Parameters", $iGroupX, $iY, $iGroupWidth, 60)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iParamY = $iY + 20
    $iParamX = $iGroupX + $iParamPadding
    $iControlsPerRow = 3
    $iControlSpacing = ($iGroupWidth - 2 * $iParamPadding - $iControlsPerRow * ($iLabelWidthParam + $iComboWidthParam + $iParamPadding)) / ($iControlsPerRow - 1)

    GUICtrlCreateLabel("Chunks:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboChunks = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "32|256|512|1024|1056|1088|1120|1152|1184|1216|1248|1280|1312|2048|3072|4000", "256")

    $iParamX += $iLabelWidthParam + $iComboWidthParam + $iControlSpacing + $iParamPadding
    GUICtrlCreateLabel("Overlap:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboOverlap = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "0.25|0.5|0.75|0.99", "0.5")

    $iParamX += $iLabelWidthParam + $iComboWidthParam + $iControlSpacing + $iParamPadding
    GUICtrlCreateLabel("Margin:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboMarginRoformer = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "44100|22050|11025", "44100")
    GUICtrlCreateGroup("", -99, -99, 1, 1)
    LogMessage("DEBUG", "Roformer Group: 1 row, 3 controls, spacing=" & $iControlSpacing)

    ; SCnet Parameters (2 controls, 1 row)
    $idGroupSCnet = GUICtrlCreateGroup("SCnet Parameters", $iGroupX, $iY, $iGroupWidth, 60)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iParamY = $iY + 20
    $iParamX = $iGroupX + $iParamPadding
    $iControlsPerRow = 2
    $iControlSpacing = ($iGroupWidth - 2 * $iParamPadding - $iControlsPerRow * ($iLabelWidthParam + $iComboWidthParam + $iParamPadding)) / ($iControlsPerRow - 1)

    GUICtrlCreateLabel("Window Size:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboWindowSize = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "320|512|1024", "512")

    $iParamX += $iLabelWidthParam + $iComboWidthParam + $iControlSpacing + $iParamPadding
    GUICtrlCreateLabel("Aggression:", $iParamX, $iParamY, $iLabelWidthParam, $iControlHeight, $SS_RIGHT)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idComboAggression = GUICtrlCreateCombo("", $iParamX + $iLabelWidthParam + $iParamPadding, $iParamY, $iComboWidthParam, $iControlHeight, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    GUICtrlSetData(-1, "0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46|47|48|49|50", "5")
    GUICtrlCreateGroup("", -99, -99, 1, 1)
    LogMessage("DEBUG", "SCnet Group: 1 row, 2 controls, spacing=" & $iControlSpacing)

    ; Adjust Y for next section (use tallest group height)
    $iY += 90 + $iPadding

    ; Output List
    $idOutputList = GUICtrlCreateEdit("", $iPadding, $iY, $iGuiWidth - 2 * $iPadding, $iGuiHeight - $iY - 100, BitOR($ES_AUTOVSCROLL, $ES_READONLY, $WS_VSCROLL))
    GUICtrlSetFont(-1, $iListViewFontSize, -1, -1, $sFontName)
    LogMessage("DEBUG", "Output List at x=" & $iPadding & ", y=" & $iY)

    ; Buttons and Progress Bar
    $iY = $iGuiHeight - 60
    Local $iButtonSpacing = $iPadding
    Local $iButtonX = $iPadding

    $idBtnImportModels = GUICtrlCreateButton("Import Models", $iButtonX, $iY, $iButtonWidth, $iControlHeight)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iButtonX += $iButtonWidth + $iButtonSpacing

    $idBtnSaveSettings = GUICtrlCreateButton("Save Settings", $iButtonX, $iY, $iButtonWidth, $iControlHeight)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iButtonX += $iButtonWidth + $iButtonSpacing

    $idRunButton = GUICtrlCreateButton("Run Separation", $iButtonX, $iY, $iButtonWidth, $iControlHeight)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $iButtonX += $iButtonWidth + $iButtonSpacing

    $idBtnLoadSettings = GUICtrlCreateButton("Load Settings", $iButtonX, $iY, $iButtonWidth, $iControlHeight)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    LogMessage("DEBUG", "Buttons at y=" & $iY & ", spacing=" & $iButtonSpacing)

    $iY += 30
    $idProgressLabel = GUICtrlCreateLabel("0%", $iPadding, $iY, 40, $iControlHeight, $SS_CENTER)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    $idProgressBar = GUICtrlCreateProgress($iPadding + 50, $iY, $iGuiWidth - 2 * $iPadding - 60, $iControlHeight)
    GUICtrlSetFont(-1, $iFontSize, -1, -1, $sFontName)
    LogMessage("DEBUG", "Progress Bar at x=" & ($iPadding + 50) & ", y=" & $iY)

    GUISetState(@SW_SHOW)
    LogMessage("DEBUG", "GUI displayed")

    DiscoverModels()
    LoadModels()
    UpdateParameterVisibility()
    GUIRegisterMsg($WM_COMMAND, "WM_COMMAND")
EndFunc

Func LoadModels()
    LogMessage("DEBUG", "LoadModels() called")

    Local $aSections = IniReadSectionNames($g_sIniPath)
    If @error Then
        GUICtrlSetData($idModelCombo, "No models found")
        Return
    EndIf

    Local $sArchitecture = GUICtrlRead($idArchitectureCombo)
    Local $sModels = ""
    ReDim $g_aModels[$aSections[0] + 1][15]
    $g_aModels[0][0] = $aSections[0]

    For $i = 1 To $aSections[0]
        Local $sModelArch = IniRead($g_sIniPath, $aSections[$i], "Architecture", "")
        If $sModelArch = $sArchitecture Then
            $g_aModels[$i][0] = $aSections[$i]
            $g_aModels[$i][1] = IniRead($g_sIniPath, $aSections[$i], "Path", "")
            $g_aModels[$i][2] = IniRead($g_sIniPath, $aSections[$i], "CommandLine", "")
            $g_aModels[$i][3] = IniRead($g_sIniPath, $aSections[$i], "FastSettings", "")
            $g_aModels[$i][4] = IniRead($g_sIniPath, $aSections[$i], "NormalSettings", "")
            $g_aModels[$i][5] = IniRead($g_sIniPath, $aSections[$i], "HighSettings", "")
            $g_aModels[$i][6] = IniRead($g_sIniPath, $aSections[$i], "Denoise", "True")
            $g_aModels[$i][7] = IniRead($g_sIniPath, $aSections[$i], "OutputStems", "")
            $g_aModels[$i][8] = IniRead($g_sIniPath, $aSections[$i], "EnvPath", "")
            $g_aModels[$i][9] = IniRead($g_sIniPath, $aSections[$i], "PythonScript", "")
            $g_aModels[$i][10] = IniRead($g_sIniPath, $aSections[$i], "OutputFormat", "wav")
            $sModels &= $aSections[$i] & "|"
        EndIf
    Next

    $sModels = StringTrimRight($sModels, 1)
    If $sModels = "" Then
        GUICtrlSetData($idModelCombo, "No models found for " & $sArchitecture)
    Else
        GUICtrlSetData($idModelCombo, $sModels)
        UpdateModelSettings(GUICtrlRead($idModelCombo))
    EndIf
EndFunc

Func UpdateParameterVisibility()
    LogMessage("DEBUG", "UpdateParameterVisibility() called")

    Local $sArchitecture = GUICtrlRead($idArchitectureCombo)
    Switch $sArchitecture
        Case "MDX-Net", "VR", "Bandit", "Roformer", "SCnet"
            GUICtrlSetState($idPrimaryStemOnly, $GUI_SHOW)
            GUICtrlSetState($idSecondaryStemOnly, $GUI_SHOW)
            LogMessage("DEBUG", "Showing Primary/Secondary Stem checkboxes for " & $sArchitecture)
        Case "Demucs"
            GUICtrlSetState($idPrimaryStemOnly, $GUI_HIDE)
            GUICtrlSetState($idSecondaryStemOnly, $GUI_HIDE)
            LogMessage("DEBUG", "Hiding Primary/Secondary Stem checkboxes for Demucs")
    EndSwitch

    Switch $sArchitecture
        Case "MDX-Net"
            GUICtrlSetState($idGroupMDX, $GUI_SHOW)
            GUICtrlSetState($idGroupDemucs, $GUI_HIDE)
            GUICtrlSetState($idGroupVR, $GUI_HIDE)
            GUICtrlSetState($idGroupBandit, $GUI_HIDE)
            GUICtrlSetState($idGroupRoformer, $GUI_HIDE)
            GUICtrlSetState($idGroupSCnet, $GUI_HIDE)
            LogMessage("DEBUG", "Showing MDX-Net group, hiding others")
        Case "Demucs"
            GUICtrlSetState($idGroupMDX, $GUI_HIDE)
            GUICtrlSetState($idGroupDemucs, $GUI_SHOW)
            GUICtrlSetState($idGroupVR, $GUI_HIDE)
            GUICtrlSetState($idGroupBandit, $GUI_HIDE)
            GUICtrlSetState($idGroupRoformer, $GUI_HIDE)
            GUICtrlSetState($idGroupSCnet, $GUI_HIDE)
            LogMessage("DEBUG", "Showing Demucs group, hiding others")
        Case "VR"
            GUICtrlSetState($idGroupMDX, $GUI_HIDE)
            GUICtrlSetState($idGroupDemucs, $GUI_HIDE)
            GUICtrlSetState($idGroupVR, $GUI_SHOW)
            GUICtrlSetState($idGroupBandit, $GUI_HIDE)
            GUICtrlSetState($idGroupRoformer, $GUI_HIDE)
            GUICtrlSetState($idGroupSCnet, $GUI_HIDE)
            LogMessage("DEBUG", "Showing VR group, hiding others")
        Case "Bandit"
            GUICtrlSetState($idGroupMDX, $GUI_HIDE)
            GUICtrlSetState($idGroupDemucs, $GUI_HIDE)
            GUICtrlSetState($idGroupVR, $GUI_HIDE)
            GUICtrlSetState($idGroupBandit, $GUI_SHOW)
            GUICtrlSetState($idGroupRoformer, $GUI_HIDE)
            GUICtrlSetState($idGroupSCnet, $GUI_HIDE)
            LogMessage("DEBUG", "Showing Bandit group, hiding others")
        Case "Roformer"
            GUICtrlSetState($idGroupMDX, $GUI_HIDE)
            GUICtrlSetState($idGroupDemucs, $GUI_HIDE)
            GUICtrlSetState($idGroupVR, $GUI_HIDE)
            GUICtrlSetState($idGroupBandit, $GUI_HIDE)
            GUICtrlSetState($idGroupRoformer, $GUI_SHOW)
            GUICtrlSetState($idGroupSCnet, $GUI_HIDE)
            LogMessage("DEBUG", "Showing Roformer group, hiding others")
        Case "SCnet"
            GUICtrlSetState($idGroupMDX, $GUI_HIDE)
            GUICtrlSetState($idGroupDemucs, $GUI_HIDE)
            GUICtrlSetState($idGroupVR, $GUI_HIDE)
            GUICtrlSetState($idGroupBandit, $GUI_HIDE)
            GUICtrlSetState($idGroupRoformer, $GUI_HIDE)
            GUICtrlSetState($idGroupSCnet, $GUI_SHOW)
            LogMessage("DEBUG", "Showing SCnet group, hiding others")
    EndSwitch
EndFunc

Func WM_COMMAND($hWnd, $iMsg, $wParam, $lParam)
    LogMessage("DEBUG", "WM_COMMAND() called")

    Local $iControlID = BitAND($wParam, 0xFFFF)
    Local $iCode = BitShift($wParam, 16)

    If $iControlID = $idArchitectureCombo And $iCode = $CBN_SELCHANGE Then
        LoadModels()
        UpdateParameterVisibility()
    ElseIf $iControlID = $idModelCombo And $iCode = $CBN_SELCHANGE Then
        Local $sModel = GUICtrlRead($idModelCombo)
        UpdateModelSettings($sModel)
    ElseIf $iControlID = $idQualityCombo And $iCode = $CBN_SELCHANGE Then
        Local $sModel = GUICtrlRead($idModelCombo)
        UpdateModelSettings($sModel)
    ElseIf $iControlID = $idInputBrowseButton And $iCode = $BN_CLICKED Then
        Local $sFile = FileOpenDialog("Select Audio File", @ScriptDir, "Audio Files (*.wav;*.mp3;*.flac)")
        If Not @error Then
            GUICtrlSetData($idInputFile, $sFile)
        EndIf
    ElseIf $iControlID = $idOutputBrowseButton And $iCode = $BN_CLICKED Then
        Local $sDir = FileSelectFolder("Select Output Directory", @ScriptDir)
        If Not @error Then
            GUICtrlSetData($idOutputDir, $sDir)
        EndIf
    EndIf
    Return $GUI_RUNDEFMSG
EndFunc

Func UpdateModelSettings($sModel)
    LogMessage("DEBUG", "UpdateModelSettings() called for model: " & $sModel)

    If $sModel = "" Then Return

    Local $iIndex = -1
    For $i = 1 To $g_aModels[0][0]
        If $g_aModels[$i][0] = $sModel Then
            $iIndex = $i
            ExitLoop
        EndIf
    Next

    If $iIndex = -1 Then
        LogMessage("ERROR", "Model not found in array: " & $sModel)
        Return
    EndIf

    Local $sQuality = GUICtrlRead($idQualityCombo)
    Local $sSettings = ""
    Switch $sQuality
        Case "Fast"
            $sSettings = $g_aModels[$iIndex][3]  ; FastSettings
        Case "Normal"
            $sSettings = $g_aModels[$iIndex][4]  ; NormalSettings
        Case "High"
            $sSettings = $g_aModels[$iIndex][5]  ; HighSettings
    EndSwitch

    If $sSettings = "" Then
        LogMessage("WARNING", "No settings found for quality " & $sQuality & " for model " & $sModel)
        Return
    EndIf

    Local $aSettings = StringSplit($sSettings, ",", $STR_NOCOUNT)
    Local $sArchitecture = IniRead($g_sIniPath, $sModel, "Architecture", "")

    Switch $sArchitecture
        Case "MDX-Net"
            If StringInStr($g_aModels[$iIndex][1], "\MDX23C\") Then
                GUICtrlSetData($idComboChunks, $aSettings[0])
                GUICtrlSetData($idComboOverlap, $aSettings[1])
                GUICtrlSetData($idComboMarginMDX, $aSettings[2])
                GUICtrlSetData($idComboNFFT, $aSettings[3])
                GUICtrlSetData($idComboDimF, $aSettings[4])
                GUICtrlSetData($idComboDimT, $aSettings[5])
            Else
                GUICtrlSetData($idComboChunks, $aSettings[0])
                GUICtrlSetData($idComboOverlap, $aSettings[1])
                GUICtrlSetData($idComboMarginMDX, $aSettings[2])
                GUICtrlSetData($idComboNFFT, $aSettings[3])
                GUICtrlSetData($idComboDimF, $aSettings[4])
                GUICtrlSetData($idComboDimT, $aSettings[5])
            EndIf
        Case "Demucs"
            GUICtrlSetData($idComboChunks, $aSettings[0])
            GUICtrlSetData($idComboOverlap, $aSettings[1])
            GUICtrlSetData($idComboMarginDemucs, $aSettings[2])
            GUICtrlSetData($idComboShifts, $aSettings[3])
        Case "VR", "SCnet"
            GUICtrlSetData($idComboWindowSize, $aSettings[0])
            GUICtrlSetData($idComboAggression, $aSettings[1])
        Case "Bandit", "Roformer"
            GUICtrlSetData($idComboChunks, $aSettings[0])
            GUICtrlSetData($idComboOverlap, $aSettings[1])
            GUICtrlSetData($sArchitecture = "Bandit" ? $idComboMarginBandit : $idComboMarginRoformer, $aSettings[2])
    EndSwitch

    Local $sStems = $g_aModels[$iIndex][7]  ; OutputStems
    If $sStems <> "" Then
        GUICtrlSetData($idStemCombo, "All|" & $sStems, "All")
    Else
        GUICtrlSetData($idStemCombo, "All", "All")
    EndIf

    LogMessage("INFO", "Updated settings for model " & $sModel & " with quality " & $sQuality)
EndFunc

; Entry point
LogMessage("DEBUG", "Script started")
LogMessage("DEBUG", "Calling CreateGUI()")
CreateGUI()

; GUI event loop
While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            LogMessage("INFO", "GUI closed by user")
            Exit
    EndSwitch
WEnd