# PowerShell script to generate a directory tree view of a remote GitHub repository

# Parameters
$repoOwner = "jhevener"
$repoName = "3DAudioStudio"
$branch = "main"  # Change to the desired branch if different
$apiBaseUrl = "https://api.github.com/repos/$repoOwner/$repoName/contents"

# Function to fetch repository contents recursively
function Get-RepoContents {
    param (
        [string]$path = "",
        [string]$url,
        [int]$depth = 0
    )

    try {
        # Make API request
        $response = Invoke-RestMethod -Uri "$url/$path" -Method Get -Headers @{ "Accept" = "application/vnd.github.v3+json" }

        # Process each item in the response
        foreach ($item in $response) {
            # Calculate indentation (avoid negative depth)
            $indent = ""
            if ($depth -gt 0) {
                $indent = "|   " * ($depth - 1) + "|-- "
            }

            if ($item.type -eq "file") {
                # Print file name
                Write-Output "$indent$($item.name)"
            }
            elseif ($item.type -eq "dir") {
                # Print directory name
                Write-Output "$indent$($item.name)/"
                # Recursively fetch contents of the directory
                Get-RepoContents -path $item.path -url $url -depth ($depth + 1)
            }
        }
    }
    catch {
        Write-Error "Failed to fetch contents for path '$path': $_"
    }
}

# Main execution
Write-Output "$repoName/"
Get-RepoContents -url $apiBaseUrl