function Get-AppDeployToolkitVersions {
    <#
    .SYNOPSIS
        Scans a network drive for Invoke-AppDeployToolkit.ps1 files and reports DeployAppScriptVersion.

    .DESCRIPTION
        Recursively searches the given root path for Invoke-AppDeployToolkit.ps1,
        skips unwanted structures (e.g. \PSAppDeployToolkit\Frontend\v4),
        extracts DeployAppScriptVersion, and exports results to a CSV file
        chosen via a Save File dialog.

    .PARAMETER RootPath
        The root folder to scan (e.g. \\YourNetworkDrive\Path).

    .EXAMPLE
        Get-AppDeployToolkitVersions -RootPath "\\Server\Share"
    #>

    param (
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    # Load Windows Forms assembly for SaveFileDialog
    Add-Type -AssemblyName System.Windows.Forms

    $results = @()

    # Search recursively for Invoke-AppDeployToolkit.ps1
    Get-ChildItem -Path $RootPath -Filter "Invoke-AppDeployToolkit.ps1" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $filePath   = $_.FullName
        $folderName = $_.DirectoryName

        # Skip unwanted structure
        if ($folderName -like "*\PSAppDeployToolkit\Frontend\v4*") {
            return
        }

        # Read file contents
        $content = Get-Content -Path $filePath -ErrorAction SilentlyContinue

        # Look for DeployAppScriptVersion line
        $versionLine = $content | Where-Object { $_ -match "DeployAppScriptVersion" }

        # Extract version number
        if ($versionLine) {
            $version = ($versionLine -split "=")[1].Trim(" '""")
        } else {
            $version = "Not Found"
        }

        # Add to results
        $results += [PSCustomObject]@{
            Folder   = $folderName
            File     = $filePath
            Version  = $version
        }
    }

    # Prompt user for CSV export location
    $SaveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $SaveDialog.Filter = "CSV files (*.csv)|*.csv"
    $SaveDialog.Title  = "Select location to save AppDeployToolkitVersions.csv"
    $SaveDialog.FileName = "AppDeployToolkitVersions.csv"
    $null = $SaveDialog.ShowDialog()
    $exportPath = $SaveDialog.FileName

    if (![string]::IsNullOrWhiteSpace($exportPath)) {
        $results | Export-Csv -Path $exportPath -NoTypeInformation
        Write-Host "Report exported to $exportPath"
    } else {
        Write-Host "Export cancelled by user."
    }

    # Return results to pipeline
    return $results
}
