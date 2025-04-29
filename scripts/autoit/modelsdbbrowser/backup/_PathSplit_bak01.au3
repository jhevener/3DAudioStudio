#include <Array.au3>
#include <File.au3>

Local $sDrive = "", $sDir = "", $sFileName = "", $sExtension = ""
Local $aPathSplit = _PathSplit(@ScriptFullPath, "", $sDir, $sFileName, $sExtension)
_ArrayDisplay($aPathSplit, "_PathSplit of " & @ScriptFullPath)
