function Update-PSADTScript {
    param (
        [Parameter(Mandatory=$true)]
        [string]$OldScriptPath,
        [Parameter(Mandatory=$true)]
        [string]$NewTemplatePath,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )

    # Read old and new scripts
    $oldContent = Get-Content $OldScriptPath -Raw
    $newContent = Get-Content $NewTemplatePath -Raw

    # Extract App Variables section
    $appVars = [regex]::Match($oldContent, "(?s)(?<=##* App Variables).*?(?=##)").Value

    # Extract Perform Installation tasks section
    $installTasks = [regex]::Match($oldContent, "(?s)(?<=## <Perform Installation tasks here>).*?(?=##=+)").Value

    # Extract Uninstall tasks section
    $uninstallTasks = [regex]::Match($oldContent, "(?s)(?<=## <Perform Uninstallation tasks here>).*?(?=##=+)").Value

    # Extract Pre-Installation tasks
    $oldPreInstall = [regex]::Match($oldContent, "(?s)(?<=##* Pre-Installation).*?(?=##)").Value
    $newPreInstall = [regex]::Match($newContent, "(?s)(?<=##* Pre-Installation).*?(?=##)").Value

    if ($oldPreInstall.Trim() -ne $newPreInstall.Trim()) {
        Write-Warning "Difference detected in Pre-Installation tasks for $OldScriptPath"
    }

    # Extract Post-Installation tasks
    $oldPostInstall = [regex]::Match($oldContent, "(?s)(?<=##* Post-Installation).*?(?=##)").Value
    $newPostInstall = [regex]::Match($newContent, "(?s)(?<=##* Post-Installation).*?(?=##)").Value

    if ($oldPostInstall.Trim() -ne $newPostInstall.Trim()) {
        Write-Warning "Difference detected in Post-Installation tasks for $OldScriptPath"
    }

    # Insert App Variables into new template
    $newContent = $newContent -replace "(?s)(?<=##* App Variables).*?(?=##)", "`r`n$appVars`r`n"

    # Insert Install Tasks into new template
    $newContent = $newContent -replace "(?s)(?<=## <Perform Installation tasks here>).*?(?=##=+)", "`r`n$installTasks`r`n"

    # Insert Uninstall Tasks into new template
    $newContent = $newContent -replace "(?s)(?<=## <Perform Uninstallation tasks here>).*?(?=##=+)", "`r`n$uninstallTasks`r`n"

    # Save merged script
    Set-Content -Path $OutputPath -Value $newContent -Force

    Write-Host "Updated script created at $OutputPath"
}
