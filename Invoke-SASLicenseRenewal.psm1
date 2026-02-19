function Invoke-SASLicenseRenewal {
    <#
    .SYNOPSIS
        Copies a SAS SID file to remote PCs and runs SASRenew.exe remotely.

    .DESCRIPTION
        Uses a GUI file picker to select the SID file, prompts for remote PCs,
        copies the file, detects SAS architecture, verifies SASRenew.exe exists,
        executes it remotely, and logs all results.
    #>

    Add-Type -AssemblyName System.Windows.Forms

    # --- GUI SID File Picker ---
    $FileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $FileDialog.Filter = "SID Text File (*.txt)|*.txt"
    $FileDialog.Title = "Select SAS SID File"

    if ($FileDialog.ShowDialog() -ne "OK") {
        Write-Host "No file selected. Exiting."
        return
    }

    $SidFile = $FileDialog.FileName
    Write-Host "Selected SID file: $SidFile"

    # --- Prompt for remote PCs ---
    Write-Host "Enter remote PC names separated by commas:"
    $RemotePCs = (Read-Host).Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }

    if ($RemotePCs.Count -eq 0) {
        Write-Host "ERROR: No remote PCs provided. Exiting."
        return
    }

    # --- Log file setup ---
    $LogDir = "$PSScriptRoot\Logs"
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

    $LogFile = Join-Path $LogDir ("SAS_Renewal_Log_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
    "=== SAS Renewal Execution Log - $(Get-Date) ===" | Out-File $LogFile

    # --- Remote SID destination ---
    $RemoteSidPath = "C:\SAS94_renewal.sid.txt"

    # --- Begin processing ---
    foreach ($PC in $RemotePCs) {

        Add-Content $LogFile "`n--- Processing $PC ---"
        Write-Host "`n--- Processing $PC ---"

        # Connectivity check
        if (-not (Test-Connection -ComputerName $PC -Count 1 -Quiet)) {
            Write-Host "ERROR: $PC unreachable."
            Add-Content $LogFile "ERROR: $PC unreachable."
            continue
        }

        # Copy SID file
        try {
            Copy-Item -Path $SidFile -Destination "\\$PC\C$\SAS94_renewal.sid.txt" -Force
            Write-Host "Copied SID file to $PC"
            Add-Content $LogFile "Copied SID file successfully."
        }
        catch {
            Write-Host "ERROR copying SID file to $PC: $_"
            Add-Content $LogFile "ERROR copying SID file: $_"
            continue
        }

        # --- Detect SAS architecture + verify SASRenew.exe ---
        $PathsToCheck = @(
            "C:\Program Files\SASHome\SASRenewalUtility\9.4\SASRenew.exe",          # 64-bit
            "C:\Program Files (x86)\SASHome\SASRenewalUtility\9.4\SASRenew.exe"     # 32-bit
        )

        $DetectedPath = Invoke-Command -ComputerName $PC -ScriptBlock {
            param($CheckPaths)
            foreach ($p in $CheckPaths) {
                if (Test-Path $p) { return $p }
            }
            return $null
        } -ArgumentList ($PathsToCheck)

        if (-not $DetectedPath) {
            Write-Host "ERROR: SASRenew.exe not found on $PC"
            Add-Content $LogFile "ERROR: SASRenew.exe not found. Skipping PC."
            continue
        }

        # Determine architecture
        $Arch = if ($DetectedPath -like "*Program Files (x86)*") { "32-bit" } else { "64-bit" }

        Write-Host "Detected $Arch SAS on $PC"
        Add-Content $LogFile "Detected $Arch SAS. Using: $DetectedPath"

        # --- Build remote command ---
        $RemoteCommand = "`"$DetectedPath`" -s `"$RemoteSidPath`""

        Write-Host "Executing SASRenew.exe on $PC..."
        Add-Content $LogFile "Executing: $RemoteCommand"

        try {
            $Result = Invoke-Command -ComputerName $PC -ScriptBlock {
                param($Cmd)
                Invoke-Expression $Cmd 2>&1
            } -ArgumentList $RemoteCommand

            Write-Host "Execution complete on $PC"
            Add-Content $LogFile "Execution output:"
            Add-Content $LogFile $Result
        }
        catch {
            Write-Host "ERROR executing SASRenew.exe on $PC: $_"
            Add-Content $LogFile "ERROR executing SASRenew.exe: $_"
        }
    }

    Write-Host "`nAll operations completed. Log saved to:"
    Write-Host $LogFile
}
