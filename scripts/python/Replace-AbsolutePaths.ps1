<#
.SYNOPSIS
    Replaces absolute paths in an AutoIt script with relative paths using @ScriptDir.

.DESCRIPTION
    This script searches for absolute paths (e.g., C:\temp\s2S\, C:\Git\3DAudioStudio\src\AutoIt\)
    in an AutoIt script and replaces them with @ScriptDir & "\ to make the script more portable.
    It also adds validation checks for critical paths.

.PARAMETER ScriptPath
    The path to the AutoIt script file to modify (default: .\src\AutoIt\AudioWizardSeparator_041825_25_uvrworks.au3).

.PARAMETER Backup
    If specified, creates a backup of the original script before modifying it.

.EXAMPLE
    .\Replace-AbsolutePaths.ps1 -ScriptPath ".\src\AutoIt\AudioWizardSeparator_041825_25_uvrworks.au3" -Backup
    Replaces absolute paths in the specified script and creates a backup.
#>

param (
    [string]$ScriptPath = ".\src\AutoIt\AudioWizardSeparator_041825_25_uvrworks.au3",
    [switch]$Backup
)

# Function to log messages
function Write-Log {
    param ($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message"
}

# Validate script file exists
if (-not (Test-Path $ScriptPath)) {
    Write-Log "Error: Script file not found at $ScriptPath"
    exit 1
}

# Create a backup if requested
if ($Backup) {
    $backupPath = $ScriptPath + ".bak"
    Copy-Item -Path $ScriptPath -Destination $backupPath -Force
    Write-Log "Created backup at $backupPath"
}

# Read the script content
Write-Log "Reading script content from $ScriptPath"
try {
    $content = Get-Content -Path $ScriptPath -Raw
}
catch {
    Write-Log "Error: Failed to read script file. $_"
    exit 1
}

# Define the absolute paths to replace and their replacements
$pathReplacements = @(
    @{ Pattern = 'C:\\temp\\s2S\\'; Replacement = '@ScriptDir & "\' },
    @{ Pattern = 'C:\\Git\\3DAudioStudio\\src\\AutoIt\\'; Replacement = '@ScriptDir & "\' }
)

# Escape backslashes for regex
foreach ($replacement in $pathReplacements) {
    $replacement.Pattern = $replacement.Pattern -replace '\\', '\\\\'
}

# Replace absolute paths
Write-Log "Replacing absolute paths..."
$modifiedContent = $content
foreach ($replacement in $pathReplacements) {
    $modifiedContent = $modifiedContent -replace $replacement.Pattern, $replacement.Replacement
}

# Add validation checks for key paths (FFmpeg, Demucs Python, UVR Python)
# We'll look for these variables and insert validation after their declaration
$validationSnippets = @(
    @{
        Variable = '\$sFFmpegPath';
        Validation = @"
If Not FileExists(\$sFFmpegPath) Then
    _LogError("FFmpeg not found at " & \$sFFmpegPath)
    MsgBox(16, "Error", "FFmpeg not found. Please ensure FFmpeg is installed in 'installs\\uvr\\ffmpeg\\bin'.")
    Exit
EndIf
"@
    },
    @{
        Variable = '\$sPythonPath';
        Validation = @"
If Not FileExists(\$sPythonPath) Then
    _LogError("Demucs Python not found at " & \$sPythonPath)
    MsgBox(16, "Error", "Demucs Python environment not found. Please ensure the Demucs environment is set up in 'installs\\Demucs\\demucs_env\\Scripts'.")
    Return 0
EndIf
"@
    },
    @{
        Variable = '\$sUVRPath';
        Validation = @"
If Not FileExists(\$sUVRPath) Then
    _LogError("UVR Python not found at " & \$sUVRPath)
    MsgBox(16, "Error", "UVR Python environment not found. Please ensure the UVR environment is set up in 'installs\\UVR\\uvr_env\\Scripts'.")
    Return 0
EndIf
"@
    }
)

# Split content into lines for easier manipulation
$lines = $modifiedContent -split "`r`n"
$newLines = @()

$inValidationBlock = $false
foreach ($line in $lines) {
    $newLines += $line

    # Skip adding validation if we're already in a validation block
    if ($line -match 'If Not FileExists\(') {
        $inValidationBlock = $true
    }
    elseif ($line -match 'EndIf') {
        $inValidationBlock = $false
    }

    if (-not $inValidationBlock) {
        foreach ($snippet in $validationSnippets) {
            if ($line -match $snippet.Variable -and $line -match '=') {
                Write-Log "Adding validation for $($snippet.Variable) after line: $line"
                $newLines += $snippet.Validation -split "`r`n"
                break
            }
        }
    }
}

# Ensure directories are created for $sBaseOutputDir and $sLogDir
$dirCreationSnippet = @"
; Ensure directories exist
DirCreate(\$sBaseOutputDir)
DirCreate(\$sLogDir)
"@

# Find the declaration of $sLogDir and add directory creation
$finalLines = @()
$dirCreationAdded = $false
foreach ($line in $newLines) {
    $finalLines += $line
    if ($line -match '\$sLogDir\s*=' -and -not $dirCreationAdded) {
        Write-Log "Adding directory creation code after \$sLogDir declaration"
        $finalLines += $dirCreationSnippet -split "`r`n"
        $dirCreationAdded = $true
    }
}

# Join the lines back together
$modifiedContent = $finalLines -join "`r`n"

# Write the modified content back to the file
Write-Log "Writing modified content back to $ScriptPath"
try {
    Set-Content -Path $ScriptPath -Value $modifiedContent -Force
    Write-Log "Successfully updated the script with relative paths and validation checks."
}
catch {
    Write-Log "Error: Failed to write to script file. $_"
    exit 1
}

# Output a summary of changes
Write-Log "Replacement summary:"
foreach ($replacement in $pathReplacements) {
    Write-Log "  Replaced $($replacement.Pattern) with $($replacement.Replacement)"
}
Write-Log "Added validation checks for FFmpeg, Demucs Python, and UVR Python paths."
Write-Log "Added directory creation for \$sBaseOutputDir and \$sLogDir."