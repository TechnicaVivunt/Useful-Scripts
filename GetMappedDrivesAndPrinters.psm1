function Get-MappedDrivesAndPrinters {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]$ComputerName
    )

    $allResults = @()

    $scriptBlock = {
        $results = @()

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

    foreach ($computer in $ComputerName) {
        try {
            Write-Verbose "Connecting to $computer..."
            $data = Invoke-Command -ComputerName $computer -ScriptBlock $scriptBlock -ErrorAction Stop
            $allResults += $data
        } catch {
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

    return $allResults | Select-Object Username, Type, Identifier, Target, Error | Format-Table -AutoSize
}
