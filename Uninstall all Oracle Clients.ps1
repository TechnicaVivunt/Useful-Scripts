# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
     $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
     Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
     Exit
    }
    }

# Define the registry paths to search
$registryPaths = @(
    "HKLM:\Software\Oracle"
    "HKLM:\Software\WOW6432Node\Oracle"
)

# Define the key to search for
$keyToFind = "KEY_OraClient"

# Define the value to find within the key
$valueToFind = "ORACLE_HOME"

# Define the path to deinstall.bat relative to ORACLE_HOME
$deinstallPathRelative = "deinstall\deinstall.bat"

# Define the log file path and name
$logFilePath = "C:\OracleDeinstallLog_$(Get-Date -Format yyyyMMdd).log"

# Create the log file if it doesn't exist
if (!(Test-Path -Path $logFilePath)) {
    New-Item -Path $logFilePath -ItemType File | Out-Null
}

# Function to write to the log file
function Write-Log {
    param (
        [string]$Message,
        [string]$LogLevel = "INFO"
    )
    $timestamp = Get-Date -Format yyyy-MM-dd
    "$timestamp [$LogLevel] $Message" | Add-Content -Path $logFilePath
}

# Loop through each registry path
foreach ($path in $registryPaths) {
    # Get all subkeys that match the key we're looking for
    $matchingKeys = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
                    Where-Object { $_.PSChildName -like "*$keyToFind*" }

    # Loop through each matching key
    foreach ($key in $matchingKeys) {
        # Construct the full path to the key
        $keyPath = $key.PSPath

        # Try to get the value of ORACLE_HOME from the key
        $oracleHomeValue = (Get-ItemProperty -Path $keyPath -Name $valueToFind -ErrorAction SilentlyContinue).$valueToFind

        # If the value is found, process it
        if ($oracleHomeValue) {
            Write-Log "Path: $keyPath"
            Write-Log "$valueToFind = $oracleHomeValue"

            # Construct the full path to deinstall.bat
            $deinstallFullPath = Join-Path -Path $oracleHomeValue -ChildPath $deinstallPathRelative

            # Check if deinstall.bat exists before attempting to run
            if (Test-Path -Path $deinstallFullPath) {
                Write-Log "Executing: $deinstallFullPath" -LogLevel "EXECUTE"
                Write-Output "Generating Deinstall Response File"
                # Run deinstall.bat to generate .rsp
                $executionResult = & $deinstallFullPath -silent -checkonly -o "$oracleHomeValue\deinstall\response"
                Write-Log "Execution Result: $($executionResult | Out-String)" -LogLevel "RESULT"
                # Find the .rsp file in the specified directory
                $rspFile = Get-ChildItem -Path "$oraclehomevalue\deinstall\response" -Filter *.rsp -Recurse | Select-Object -First 1
                # Check if a response file was found
                if ($rspFile -ne $null) {    
                # Run the deinstall.bat with the -paramfile option
                Write-Output "Response File Generated; proceeding with deinstallation"
                $deinstallResult = & $deinstallFullPath -silent -paramfile "$($rspFile.FullName)"
                Write-Log "Deinstall Result: $($deinstallResult | Out-String)" -LogLevel "RESULT"
                } 
                else {
                Write-Log "No response file found."
                }
                # Alternatively, if you want to run it within the current PowerShell context (might not work as expected with interactive batches):
                # & $deinstallFullPath
            } else {
                Write-Log "deinstall.bat not found at expected path: $deinstallFullPath" -LogLevel "WARNING"
            }

            Read-Host "-Deinstall Complete Check the Log at $logFilePath-" # Divider for readability
        }
    }
}

# If no matching values were found, indicate so
if (-not $oracleHomeValue) {
    Write-Log "No '$valueToFind' values found under keys matching '$keyToFind' in the specified registry paths."
    Read-Host "No Installations Found"
}