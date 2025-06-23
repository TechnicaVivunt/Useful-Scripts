Add-Type -AssemblyName System.Windows.Forms

# Prompt for computer names
$computerInput = Read-Host "Enter computer names (comma-separated)"
$computerList = $computerInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

# Save File dialog for export path
$saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
$saveFileDialog.Title = "Select Export Location"
$saveFileDialog.Filter = "CSV files (*.csv)|*.csv"
$saveFileDialog.FileName = "UserMappedDrivesAndPrinters.csv"
$saveFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

if ($saveFileDialog.ShowDialog() -eq "OK") {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $exportPath = [System.IO.Path]::ChangeExtension($saveFileDialog.FileName, $null) + "_$timestamp.csv"
} else {
    Write-Host "Export cancelled by user." -ForegroundColor Red
    exit
}

# Prepare results list
$allResults = @()

# Script block to run on remote computers
$scriptBlock = {
    $results = @()
    $computerName = $env:COMPUTERNAME

    function Get-UsernameFromSID {
        param([string]$SID)
        try {
            $objSID = New-Object System.Security.Principal.SecurityIdentifier($SID)
            $account = $objSID.Translate([System.Security.Principal.NTAccount])
            return $account.Value
        } catch {
            return "Unknown"
        }
    }

    $userSIDs = Get-ChildItem Registry::HKEY_USERS | Where-Object {
        ($_ -notmatch '_Classes$') -and ($_ -notmatch '^S-1-5-18$') -and ($_ -notmatch '^S-1-5-19$') -and ($_ -notmatch '^S-1-5-20$')
    }

    foreach ($sid in $userSIDs) {
        $sidStr = $sid.PSChildName
        $username = Get-UsernameFromSID $sidStr

        # Mapped Drives
        $networkKeyPath = "Registry::HKEY_USERS\$sidStr\Network"
        if (Test-Path $networkKeyPath) {
            $drives = Get-ChildItem $networkKeyPath
            foreach ($drive in $drives) {
                $driveLetter = $drive.PSChildName
                $remotePath = Get-ItemPropertyValue -Path $drive.PSPath -Name RemotePath -ErrorAction SilentlyContinue
                $results += [PSCustomObject]@{
                    ComputerName = $computerName
                    UserSID      = $sidStr
                    Username     = $username
                    Type         = "MappedDrive"
                    Identifier   = "$driveLetter"
                    Target       = $remotePath
                    Error        = ""
                }
            }
        }

        # Printer Connections
        $printerKeyPath = "Registry::HKEY_USERS\$sidStr\Printers\Connections"
        if (Test-Path $printerKeyPath) {
            $printers = Get-ChildItem $printerKeyPath
            foreach ($printer in $printers) {
            $cleanIdentifier = $printer.PSChildName -replace ",", "\"
                $results += [PSCustomObject]@{
                    ComputerName = $computerName
                    Username     = $username
                    Type         = "Printer"
                    Identifier   = $cleanIdentifier
                    Target       = ""
                    Error        = ""
                }
            }
        }
    }

    return $results
}

# Loop through each machine
foreach ($computer in $computerList) {
    Write-Host "`n=== Connecting to $computer ===" -ForegroundColor Yellow
    try {
        $data = Invoke-Command -ComputerName $computer -ScriptBlock $scriptBlock -ErrorAction Stop
        $allResults += $data
    } catch {
        Write-Warning "Failed to connect to $computer $_"
        $allResults += [PSCustomObject]@{
            ComputerName = $computer
            UserSID      = ""
            Username     = ""
            Type         = "Error"
            Identifier   = ""
            Target       = ""
            Error        = "Failed to connect or access registry"
        }
    }
}

# Export results
$allResults | Select-Object ComputerName, Username, Type, Identifier, Target, Error |
    Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8

# Echo to console
Write-Host "`n==== Aggregated Results ====" -ForegroundColor Cyan
$allResults | Select-Object ComputerName, Username, Type, Identifier, Target, Error | Format-Table -AutoSize

Read-Host "`nExport completed: $exportPath Press Enter to Exit" -ForegroundColor Green
