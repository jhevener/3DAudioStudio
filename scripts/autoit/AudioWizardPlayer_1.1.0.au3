#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=AudioWizard.ico
#AutoIt3Wrapper_Outfile=AudioWizard.exe
#AutoIt3Wrapper_Res_Description=AudioWizard
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#AutoIt3Wrapper_Res_ProductName=AudioWizard
#AutoIt3Wrapper_Res_ProductVersion=1.0
#AutoIt3Wrapper_Res_CompanyName=FretzCapo Productions
#AutoIt3Wrapper_Res_LegalCopyright=© 2025 FretzCapo Productions
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include "Bass.au3"
#include "BassFLAC.au3"

Opt("GUIOnEventMode", 1)

Global $g_sLogFile = @ScriptDir & "\AudioWizard.log"
Global $hStream = 0
Global $sFilePath = ""

Global $hGUI, $idChooseButton, $idPlayButton, $idStopButton, $idDisplay

Main()

Func Main()
    LogMessage("Starting AudioWizard")
    If Not _BASS_Startup(@ScriptDir & "\bass.dll") Then
        LogMessage("Failed to load bass.dll")
        MsgBox(16, "Error", "Failed to load bass.dll")
        Exit
    EndIf
    LogMessage("BASS version: " & StringFormat("%d.%d.%d.%d", BitShift(_BASS_GetVersion(), 24), BitShift(BitAND(_BASS_GetVersion(), 0xFF0000), 16), BitShift(BitAND(_BASS_GetVersion(), 0xFF00), 8), BitAND(_BASS_GetVersion(), 0xFF)))

    If Not _BASS_Init(-1, 44100, 0, 0, 0) Then
        LogMessage("Failed to initialize BASS: " & _BASS_ErrorGetCode())
        MsgBox(16, "Error", "Failed to initialize BASS: " & _BASS_ErrorGetCode())
        Exit
    EndIf
    LogMessage("BASS initialized successfully")

    If Not _BASS_FLAC_Startup(@ScriptDir & "\bassflac.dll") Then
        LogMessage("Failed to load bassflac.dll: " & _BASS_ErrorGetCode())
        MsgBox(16, "Error", "Failed to initialize BassFLAC: " & _BASS_ErrorGetCode())
        _BASS_Free()
        Exit
    EndIf
    LogMessage("BassFLAC initialized successfully")

    CreateGUI()
    GUISetState(@SW_SHOW)

    While 1
        Sleep(100)
    WEnd
EndFunc

Func CreateGUI()
    $hGUI = GUICreate("AudioWizard", 500, 400, -1, -1)
    GUISetOnEvent($GUI_EVENT_CLOSE, "OnExit")

    $idChooseButton = GUICtrlCreateButton("Choose File", 10, 10, 100, 30)
    GUICtrlSetOnEvent(-1, "ButtonHandler")

    $idPlayButton = GUICtrlCreateButton("Play", 120, 10, 100, 30)
    GUICtrlSetOnEvent(-1, "ButtonHandler")

    $idStopButton = GUICtrlCreateButton("Stop", 230, 10, 100, 30)
    GUICtrlSetOnEvent(-1, "ButtonHandler")

    $idDisplay = GUICtrlCreateEdit("", 10, 50, 480, 340, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL))
EndFunc

Func ButtonHandler()
    Switch @GUI_CtrlId
        Case $idChooseButton
            $sFilePath = FileOpenDialog("Select an Audio File", @ScriptDir, "Audio Files (*.wav;*.mp3;*.flac)", 1)
            If @error Or $sFilePath = "" Then Return
            If Not FileExists($sFilePath) Then
                LogMessage("File does not exist: " & $sFilePath)
                MsgBox(16, "Error", "File does not exist: " & $sFilePath)
                Return
            EndIf
            LogMessage("Selected file: " & $sFilePath)
            LogMessage("File verified exists: " & $sFilePath)

            If $hStream <> 0 Then
                _BASS_StreamFree($hStream)
                $hStream = 0
                LogMessage("Freed previous stream")
            EndIf

            Local $sExt = StringLower(StringRight($sFilePath, 4))
            If $sExt = ".wav" Then
                $hStream = _BASS_StreamCreateFile(False, $sFilePath, 0, 0, 0) ; No Unicode
            ElseIf $sExt = ".mp3" Then
                $hStream = _BASS_StreamCreateFile(False, $sFilePath, 0, 0, 0x20000) ; BASS_STREAM_PRESCAN, no Unicode
            ElseIf $sExt = "flac" Then
                $hStream = _BASS_FLAC_StreamCreateFile(False, $sFilePath, 0, 0, 0x80000000) ; BASS_UNICODE
            Else
                LogMessage("Unsupported file type: " & $sExt)
                MsgBox(16, "Error", "Unsupported file type: " & $sExt)
                Return
            EndIf

            If $hStream = 0 Then
                Local $err = _BASS_ErrorGetCode()
                LogMessage("Failed to create stream for " & $sFilePath & ": " & $err)
                MsgBox(16, "Error", "Stream creation failed: " & $err)
                Return
            EndIf
            LogMessage("Stream created for " & $sFilePath)

            Local $tChannelInfo = DllStructCreate("dword freq;dword chans;dword flags;dword type;dword origres;ptr sample;ptr filename")
            If Not _BASS_ChannelGetInfo($hStream, $tChannelInfo) Then
                Local $err = _BASS_ErrorGetCode()
                LogMessage("Failed to get channel info: " & $err)
                MsgBox(16, "Error", "Failed to get channel info: " & $err)
                _BASS_StreamFree($hStream)
                $hStream = 0
                Return
            EndIf
            Local $freq = DllStructGetData($tChannelInfo, "freq")
            Local $chans = DllStructGetData($tChannelInfo, "chans")
            LogMessage("Channel info - Frequency: " & $freq & " Hz, Channels: " & $chans)

            If Not _BASS_ChannelPlay($hStream, True) Then
                Local $err = _BASS_ErrorGetCode()
                LogMessage("Failed to play stream for " & $sFilePath & ": " & $err)
                MsgBox(16, "Error", "Playback failed: " & $err)
                _BASS_StreamFree($hStream)
                $hStream = 0
                Return
            EndIf
            LogMessage("Playback started")
            GUICtrlSetData($idDisplay, "File: " & $sFilePath & @CRLF & "Frequency: " & $freq & " Hz" & @CRLF & "Channels: " & $chans)

        Case $idPlayButton
            If $hStream <> 0 Then
                If Not _BASS_ChannelPlay($hStream, False) Then
                    Local $err = _BASS_ErrorGetCode()
                    LogMessage("Failed to resume playback: " & $err)
                    MsgBox(16, "Error", "Playback failed: " & $err)
                Else
                    LogMessage("Playback resumed")
                EndIf
            Else
                MsgBox(48, "Warning", "No file loaded to play")
            EndIf

        Case $idStopButton
            If $hStream <> 0 Then
                _BASS_ChannelStop($hStream)
                GUICtrlSetData($idDisplay, GUICtrlRead($idDisplay) & @CRLF & "Playback stopped")
                LogMessage("Playback stopped")
            EndIf
    EndSwitch
EndFunc

Func LogMessage($sMessage)
    Local $hFile = FileOpen($g_sLogFile, 1 + 8)
    If $hFile = -1 Then
        FileWriteLine(@ScriptDir & "\AudioWizard_error.log", "Cannot write to log file: " & $g_sLogFile)
        MsgBox(16, "Log Error", "Cannot write to log file: " & $g_sLogFile)
        Return
    EndIf
    Local $sTimestamp = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
    FileWriteLine($hFile, "[" & $sTimestamp & "] " & $sMessage)
    FileClose($hFile)
EndFunc

Func OnExit()
    If $hStream <> 0 Then
        _BASS_StreamFree($hStream)
        LogMessage("Freed stream")
    EndIf
    _BASS_FLAC_Shutdown()
    LogMessage("BassFLAC shutdown")
    _BASS_Free()
    LogMessage("BASS shutdown")
    Exit
EndFunc