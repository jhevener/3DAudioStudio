# Test-DimT-Models.ps1
# Script to test DimT values for kuielab models and determine permissible range

# Configuration
$scriptDir = "C:\Git\3DAudioStudio\scripts\autoit\1.3"
$modelsIni = "$scriptDir\models.INI"
$inputFile = "$scriptDir\songs\song0.flac"
$outputDirBase = "$scriptDir\stems_test"
$logFile = "$scriptDir\logs\dimt_test_log.txt"
$dimTRange = 7..11  # Practical range: DimT from 7 to 11 (self.dim_t from 128 to 2048)
$timeoutSeconds = 300  # 5-minute timeout

# Ensure output and log directories exist
if (-not (Test-Path $outputDirBase)) { New-Item -ItemType Directory -Path $outputDirBase | Out-Null }
if (-not (Test-Path "$scriptDir\logs")) { New-Item -ItemType Directory -Path "$scriptDir\logs" | Out-Null }

# Function to log messages
function Write-Log {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

# Function to parse models.ini and extract kuielab models
function Get-KuielabModels {
    $content = Get-Content $modelsIni -Raw
    $sections = $content -split '\[(.*?)\]\s*\r?\n'
    $models = @{}
    for ($i = 1; $i -lt $sections.Length; $i += 2) {
        $sectionName = $sections[$i]
        if ($sectionName -notlike "kuielab*") { continue }
        $sectionContent = $sections[$i + 1]
        $modelSettings = @{}
        foreach ($line in ($sectionContent -split '\r?\n')) {
            if ($line -match '^(.*?)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $modelSettings[$key] = $value
            }
        }
        $models[$sectionName] = $modelSettings
    }
    return $models
}

# Function to run separation with a timeout and capture output
function Test-Separation {
    param (
        [string]$Command,
        [string]$Model,
        [int]$DimT,
        [string]$OutputDir
    )
    Write-Log "Testing Model: $Model, DimT: $DimT (self.dim_t: $([math]::Pow(2, $DimT)))"

    # Create a unique output directory for this test
    if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

    # Start the process with a timeout
    $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $Command" -NoNewWindow -PassThru -RedirectStandardOutput "$OutputDir\stdout.txt" -RedirectStandardError "$OutputDir\stderr.txt"

    # Wait for the process to complete or timeout
    $waitResult = $process.WaitForExit($timeoutSeconds * 1000)
    if (-not $waitResult) {
        Write-Log "Process timed out after $timeoutSeconds seconds for Model: $Model, DimT: $DimT"
        $process.Kill()
        return $false, "Timeout after $timeoutSeconds seconds"
    }

    # Read stdout and stderr
    $stdout = Get-Content "$OutputDir\stdout.txt" -Raw
    $stderr = Get-Content "$OutputDir\stderr.txt" -Raw
    $output = "$stdout`n$stderr"

    # Check for errors in output
    if ($output -match "ONNXRuntimeError" -or $output -match "Traceback" -or $output -match "ModuleNotFoundError") {
        Write-Log "Failure for Model: $Model, DimT: $DimT - Error in output: $output"
        return $false, $output
    }

    # Check if expected stems were generated
    $stems = ($models[$Model]["OutputStems"] -split ",").Trim()
    $filename = [System.IO.Path]::GetFileNameWithoutExtension($inputFile)
    $allStemsExist = $true
    foreach ($stem in $stems) {
        $stemFile = "$OutputDir\$filename`_$stem.wav"
        if (-not (Test-Path $stemFile)) {
            Write-Log "Failure for Model: $Model, DimT: $DimT - Missing stem: $stemFile"
            $allStemsExist = $false
        }
    }

    if ($allStemsExist) {
        Write-Log "Success for Model: $Model, DimT: $DimT - All stems generated"
        return $true, $output
    } else {
        return $false, "Missing stems"
    }
}

# Main script
Write-Log "Starting DimT testing for kuielab models"

# Load models from models.ini
$models = Get-KuielabModels
if ($models.Count -eq 0) {
    Write-Log "No kuielab models found in $modelsIni"
    exit 1
}

# Iterate through each model and DimT value
foreach ($model in $models.Keys) {
    $modelSettings = $models[$model]
    Write-Log "Processing Model: $model"

    foreach ($dimT in $dimTRange) {
        # Prepare output directory for this test
        $testOutputDir = "$outputDirBase\$model`_DimT_$dimT"
        
        # Resolve the CommandLine with current DimT
        $cmd = $modelSettings["CommandLine"]
        $cmd = $cmd -replace "@ScriptDir@", $scriptDir
        $cmd = $cmd -replace "@SongPath@", $inputFile
        $cmd = $cmd -replace "@OutputDir@", $testOutputDir
        $cmd = $cmd -replace "@SegmentSize@", $modelSettings["SegmentSize"]
        $cmd = $cmd -replace "@Overlap@", $modelSettings["Overlap"]
        $cmd = $cmd -replace "@NFFT@", $modelSettings["NFFT"]
        $cmd = $cmd -replace "@DimF@", $modelSettings["DimF"]
        $cmd = $cmd -replace "@DimT@", $dimT
        $cmd = $cmd -replace "@Path@", ($modelSettings["Path"] -replace "@ScriptDir@", $scriptDir)
        $cmd = $cmd -replace "@EnvPath@", ($modelSettings["EnvPath"] -replace "@ScriptDir@", $scriptDir)
        $cmd = $cmd -replace "@PythonScript@", $modelSettings["PythonScript"]
        $cmd = $cmd -replace "@OutputStems@", $modelSettings["OutputStems"]

        # Run the test
        $success, $output = Test-Separation -Command $cmd -Model $model -DimT $dimT -OutputDir $testOutputDir
    }
}

Write-Log "DimT testing completed"