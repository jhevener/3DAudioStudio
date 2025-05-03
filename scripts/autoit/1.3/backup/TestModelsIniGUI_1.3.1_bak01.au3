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
        ; Handle the error: no files found or access issue
        If @error = 1 Then
            LogMessage("INFO", "No files found in models directory: " & $g_sModelsDir & ". Please add model files to proceed.")
        Else
            LogMessage("ERROR", "Failed to list files in models directory: " & $g_sModelsDir & ". Error code: " & @error)
        EndIf
        ; Ensure the script continues by setting the model combo box
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

    GUICreate("Audio Separation", 850, 600)
    Local $iFontSize = 11
    Local $iListViewFontSize = $iFontSize - 2

    GUICtrlCreateLabel("Choose Process Method:", 10, 10, 130, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idArchitectureCombo = GUICtrlCreateCombo("MDX-Net", 140, 10, 120, 20, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idArchitectureCombo, "Demucs|VR|Bandit|Roformer|SCnet")

    GUICtrlCreateLabel("Select Model:", 10, 35, 130, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idModelCombo = GUICtrlCreateCombo("", 140, 35, 250, 20, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)

    GUICtrlCreateLabel("Quality:", 10, 60, 130, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idQualityCombo = GUICtrlCreateCombo("Normal", 140, 60, 120, 20, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idQualityCombo, "Fast|Normal|High")

    GUICtrlCreateLabel("Input Audio File:", 10, 85, 130, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idInputFile = GUICtrlCreateInput("", 140, 85, 600, 20, $ES_READONLY)
    GUICtrlSetFont(-1, $iFontSize)
    $idInputBrowseButton = GUICtrlCreateButton("Browse", 750, 85, 80, 20)
    GUICtrlSetFont(-1, $iFontSize)

    GUICtrlCreateLabel("Output Directory:", 10, 110, 130, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idOutputDir = GUICtrlCreateInput(@ScriptDir & "\stems", 140, 110, 600, 20, $ES_READONLY)
    GUICtrlSetFont(-1, $iFontSize)
    $idOutputBrowseButton = GUICtrlCreateButton("Browse", 750, 110, 80, 20)
    GUICtrlSetFont(-1, $iFontSize)

    GUICtrlCreateLabel("Select Stem:", 10, 135, 130, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idStemCombo = GUICtrlCreateCombo("All", 140, 135, 120, 20, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)

    $idGPUConversion = GUICtrlCreateCheckbox("GPU Conversion", 10, 160, 120, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idPrimaryStemOnly = GUICtrlCreateCheckbox("Primary Stem Only", 140, 160, 120, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idSecondaryStemOnly = GUICtrlCreateCheckbox("Secondary Stem Only", 270, 160, 130, 20)
    GUICtrlSetFont(-1, $iFontSize)

    $idGroupMDX = GUICtrlCreateGroup("MDX-Net Parameters", 10, 185, 830, 90)
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlCreateLabel("Chunks:", 20, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboChunks = GUICtrlCreateCombo("", 70, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboChunks, "32|256|512|1024|1056|1088|1120|1152|1184|1216|1248|1280|1312|2048|3072|4000", "256")
    GUICtrlCreateLabel("Overlap:", 140, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboOverlap = GUICtrlCreateCombo("", 190, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboOverlap, "0.25|0.5|0.75|0.99", "0.5")
    GUICtrlCreateLabel("Margin:", 260, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboMarginMDX = GUICtrlCreateCombo("", 310, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboMarginMDX, "44100|22050|11025", "44100")
    GUICtrlCreateLabel("NFFT:", 380, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboNFFT = GUICtrlCreateCombo("", 430, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboNFFT, "4096|5120|6144|7680|8192|16384", "6144")
    GUICtrlCreateLabel("DimF:", 500, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboDimF = GUICtrlCreateCombo("", 550, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboDimF, "2048|3072|4096", "2048")
    GUICtrlCreateLabel("DimT:", 620, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboDimT = GUICtrlCreateCombo("", 670, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboDimT, "8|16|32|48|64", "32")
    GUICtrlSetTip($idComboDimT, "Time dimension for MDX-Net models")
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    $idGroupDemucs = GUICtrlCreateGroup("Demucs Parameters", 10, 185, 830, 90)
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlCreateLabel("Segment:", 20, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboChunks = GUICtrlCreateCombo("", 70, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboChunks, "Default|1|5|10|15|20|25|30|35|40|45|50|55|60|65|70|75|80|85|90|95|100", "Default")
    GUICtrlCreateLabel("Overlap:", 140, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboOverlap = GUICtrlCreateCombo("", 190, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboOverlap, "0.25|0.5|0.75|0.99", "0.5")
    GUICtrlCreateLabel("Margin:", 260, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboMarginDemucs = GUICtrlCreateCombo("", 310, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboMarginDemucs, "44100|22050|11025", "44100")
    GUICtrlCreateLabel("Shifts:", 380, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboShifts = GUICtrlCreateCombo("", 430, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboShifts, "0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20", "2")
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    $idGroupVR = GUICtrlCreateGroup("VR Parameters", 10, 185, 830, 90)
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlCreateLabel("Window Size:", 20, 205, 80, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboWindowSize = GUICtrlCreateCombo("", 100, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboWindowSize, "320|512|1024", "512")
    GUICtrlCreateLabel("Aggression:", 170, 205, 80, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboAggression = GUICtrlCreateCombo("", 250, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboAggression, "0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46|47|48|49|50", "5")
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    $idGroupBandit = GUICtrlCreateGroup("Bandit Parameters", 10, 185, 830, 90)
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlCreateLabel("Chunks:", 20, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboChunks = GUICtrlCreateCombo("", 70, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboChunks, "32|256|512|1024|1056|1088|1120|1152|1184|1216|1248|1280|1312|2048|3072|4000", "256")
    GUICtrlCreateLabel("Overlap:", 140, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboOverlap = GUICtrlCreateCombo("", 190, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboOverlap, "0.25|0.5|0.75|0.99", "0.5")
    GUICtrlCreateLabel("Margin:", 260, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboMarginBandit = GUICtrlCreateCombo("", 310, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboMarginBandit, "44100|22050|11025", "44100")
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    $idGroupRoformer = GUICtrlCreateGroup("Roformer Parameters", 10, 185, 830, 90)
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlCreateLabel("Chunks:", 20, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboChunks = GUICtrlCreateCombo("", 70, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboChunks, "32|256|512|1024|1056|1088|1120|1152|1184|1216|1248|1280|1312|2048|3072|4000", "256")
    GUICtrlCreateLabel("Overlap:", 140, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboOverlap = GUICtrlCreateCombo("", 190, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboOverlap, "0.25|0.5|0.75|0.99", "0.5")
    GUICtrlCreateLabel("Margin:", 260, 205, 50, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboMarginRoformer = GUICtrlCreateCombo("", 310, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboMarginRoformer, "44100|22050|11025", "44100")
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    $idGroupSCnet = GUICtrlCreateGroup("SCnet Parameters", 10, 185, 830, 90)
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlCreateLabel("Window Size:", 20, 205, 80, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboWindowSize = GUICtrlCreateCombo("", 100, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboWindowSize, "320|512|1024", "512")
    GUICtrlCreateLabel("Aggression:", 170, 205, 80, 20)
    GUICtrlSetFont(-1, $iFontSize)
    $idComboAggression = GUICtrlCreateCombo("", 250, 205, 60, 20, BitOR($CBS_DROPDOWN, $CBS_AUTOHSCROLL))
    GUICtrlSetFont(-1, $iFontSize)
    GUICtrlSetData($idComboAggression, "0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46|47|48|49|50", "5")
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    $idOutputList = GUICtrlCreateEdit("", 10, 285, 830, 250, BitOR($ES_AUTOVSCROLL, $ES_READONLY, $WS_VSCROLL))
    GUICtrlSetFont(-1, $iListViewFontSize)

    $idBtnImportModels = GUICtrlCreateButton("Import Models", 10, 545, 120, 25)
    GUICtrlSetFont(-1, $iFontSize)
    $idBtnSaveSettings = GUICtrlCreateButton("Save Settings", 140, 545, 120, 25)
    GUICtrlSetFont(-1, $iFontSize)
    $idRunButton = GUICtrlCreateButton("Run Separation", 270, 545, 120, 25)
    GUICtrlSetFont(-1, $iFontSize)
    $idBtnLoadSettings = GUICtrlCreateButton("Load Settings", 400, 545, 120, 25)
    GUICtrlSetFont(-1, $iFontSize)

    $idProgressLabel = GUICtrlCreateLabel("0%", 10, 575, 40, 20, $SS_CENTER)
    GUICtrlSetFont(-1, $iFontSize)
    $idProgressBar = GUICtrlCreateProgress(60, 575, 780, 20)
    GUICtrlSetFont(-1, $iFontSize)

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
        Case "Demucs"
            GUICtrlSetState($idPrimaryStemOnly, $GUI_HIDE)
            GUICtrlSetState($idSecondaryStemOnly, $GUI_HIDE)
    EndSwitch

    Switch $sArchitecture
        Case "MDX-Net"
            GUICtrlSetState($idGroupMDX, $GUI_SHOW)
            GUICtrlSetState($idGroupDemucs, $GUI_HIDE)
            GUICtrlSetState($idGroupVR, $GUI_HIDE)
            GUICtrlSetState($idGroupBandit, $GUI_HIDE)
            GUICtrlSetState($idGroupRoformer, $GUI_HIDE)
            GUICtrlSetState($idGroupSCnet, $GUI_HIDE)
        Case "Demucs"
            GUICtrlSetState($idGroupMDX, $GUI_HIDE)
            GUICtrlSetState($idGroupDemucs, $GUI_SHOW)
            GUICtrlSetState($idGroupVR, $GUI_HIDE)
            GUICtrlSetState($idGroupBandit, $GUI_HIDE)
            GUICtrlSetState($idGroupRoformer, $GUI_HIDE)
            GUICtrlSetState($idGroupSCnet, $GUI_HIDE)
        Case "VR"
            GUICtrlSetState($idGroupMDX, $GUI_HIDE)
            GUICtrlSetState($idGroupDemucs, $GUI_HIDE)
            GUICtrlSetState($idGroupVR, $GUI_SHOW)
            GUICtrlSetState($idGroupBandit, $GUI_HIDE)
            GUICtrlSetState($idGroupRoformer, $GUI_HIDE)
            GUICtrlSetState($idGroupSCnet, $GUI_HIDE)
        Case "Bandit"
            GUICtrlSetState($idGroupMDX, $GUI_HIDE)
            GUICtrlSetState($idGroupDemucs, $GUI_HIDE)
            GUICtrlSetState($idGroupVR, $GUI_HIDE)
            GUICtrlSetState($idGroupBandit, $GUI_SHOW)
            GUICtrlSetState($idGroupRoformer, $GUI_HIDE)
            GUICtrlSetState($idGroupSCnet, $GUI_HIDE)
        Case "Roformer"
            GUICtrlSetState($idGroupMDX, $GUI_HIDE)
            GUICtrlSetState($idGroupDemucs, $GUI_HIDE)
            GUICtrlSetState($idGroupVR, $GUI_HIDE)
            GUICtrlSetState($idGroupBandit, $GUI_HIDE)
            GUICtrlSetState($idGroupRoformer, $GUI_SHOW)
            GUICtrlSetState($idGroupSCnet, $GUI_HIDE)
        Case "SCnet"
            GUICtrlSetState($idGroupMDX, $GUI_HIDE)
            GUICtrlSetState($idGroupDemucs, $GUI_HIDE)
            GUICtrlSetState($idGroupVR, $GUI_HIDE)
            GUICtrlSetState($idGroupBandit, $GUI_HIDE)
            GUICtrlSetState($idGroupRoformer, $GUI_HIDE)
            GUICtrlSetState($idGroupSCnet, $GUI_SHOW)
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