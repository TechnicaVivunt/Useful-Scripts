function Update-PSADTScript {
    param (
        [Parameter(Mandatory=$true)]
        [string]$OldScriptsFolder,
        [Parameter(Mandatory=$true)]
        [string]$NewTemplatePath,
        [Parameter(Mandatory=$true)]
        [string]$OutputFolder
    )

    if (-not (Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    }

    # --- Copy all template files except Invoke-AppDeployToolkit.ps1 ---
    $templateFolder = Split-Path $NewTemplatePath
    $templateFiles = Get-ChildItem -Path $templateFolder -File -Recurse | Where-Object { $_.Name -ne "Invoke-AppDeployToolkit.ps1" }

    foreach ($file in $templateFiles) {
        $relativePath = $file.FullName.Substring($templateFolder.Length).TrimStart('\')
        $destPath = Join-Path $OutputFolder $relativePath
        $destDir = Split-Path $destPath
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item $file.FullName -Destination $destPath -Force
    }

    # --- Process Invoke-AppDeployToolkit.ps1 files from old scripts ---
    $oldScripts = Get-ChildItem -Path $OldScriptsFolder -Filter Invoke-AppDeployToolkit.ps1 -File -Recurse

    foreach ($script in $oldScripts) {
        if ($script.FullName -like "*\PSAppDeployToolkit\Frontend\v4*") {
            Write-Host "⏭️ Skipping $($script.FullName)"
            continue
        }

        Write-Host "Processing $($script.FullName)..."

        $oldContent = Get-Content $script.FullName -Raw
        $newContent = Get-Content $NewTemplatePath -Raw

        # --- Replace adtSession values field-by-field ---
        $fields = @(
            "AppVendor",
            "AppName",
            "AppVersion",
            "AppArch",
            "AppLang",
            "AppRevision",
            "AppSuccessExitCodes",
            "AppRebootExitCodes",
            "AppProcessesToClose",
            "AppScriptVersion",
            "AppScriptAuthor"
        )

        foreach ($field in $fields) {
            $oldValue = [regex]::Match($oldContent, "(?m)^\s*$field\s*=\s*(.+)$").Groups[1].Value.Trim()
            if ($oldValue) {
                $newContent = [regex]::Replace($newContent, "(?m)^\s*($field\s*=\s*)(.+)$", "`$1$oldValue")
            }
        }

        # --- Override AppScriptDate with today's date ---
        $todayDate = (Get-Date).ToString("yyyy-MM-dd")
        $newContent = [regex]::Replace($newContent, "(?m)^\s*(AppScriptDate\s*=\s*)'.*'$", "`$1'$todayDate'")

        # --- Ensure DeployAppScriptVersion stays from template ---
        $templateVersion = [regex]::Match($newContent, "(?m)^\s*DeployAppScriptVersion\s*=\s*'.*'$").Value
        if ($templateVersion) {
            $newContent = [regex]::Replace($newContent, "(?m)^\s*DeployAppScriptVersion\s*=\s*'.*'$", $templateVersion)
        }

        # --- Copy Install/Uninstall task blocks ---
        $installBlockOld = [regex]::Match(
            $oldContent,
            "(?ms)^\s*##\s*<Perform Installation tasks here>\s*\r?\n(?<body>.*?)(?=^\s*##\s*<|^\s*#\s*End of Script|^\s*$)"
        ).Groups['body'].Value

        $uninstallBlockOld = [regex]::Match(
            $oldContent,
            "(?ms)^\s*##\s*<Perform Uninstallation tasks here>\s*\r?\n(?<body>.*?)(?=^\s*##\s*<|^\s*#\s*End of Script|^\s*$)"
        ).Groups['body'].Value

        if ($installBlockOld) {
            $newContent = [regex]::Replace(
                $newContent,
                "(?ms)(^\s*##\s*<Perform Installation tasks here>\s*\r?\n).*?(?=^\s*##\s*<|^\s*#\s*End of Script|^\s*$)",
                "`$1$installBlockOld"
            )
        }

        if ($uninstallBlockOld) {
            $newContent = [regex]::Replace(
                $newContent,
                "(?ms)(^\s*##\s*<Perform Uninstallation tasks here>\s*\r?\n).*?(?=^\s*##\s*<|^\s*#\s*End of Script|^\s*$)",
                "`$1$uninstallBlockOld"
            )
        }

        # --- Save merged script preserving folder structure ---
        $relativePath = $script.FullName.Substring($OldScriptsFolder.Length).TrimStart('\')
        $outputPath   = Join-Path $OutputFolder $relativePath

        $outputDir = Split-Path $outputPath
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        $newContent | Out-File -FilePath $outputPath -Force -Encoding UTF8
        Write-Host "✅ Updated Invoke-AppDeployToolkit.ps1 created at $outputPath"
    }

# --- Copy Files and SupportFiles folders from old path ---
foreach ($folderName in @("Files","SupportFiles")) {
    $src = Join-Path $OldScriptsFolder $folderName
    if (Test-Path $src) {
        $dest = Join-Path $OutputFolder $folderName
        if (-not (Test-Path $dest)) {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
        }
        # Copy contents, not the folder itself
        Get-ChildItem $src -Recurse | ForEach-Object {
            $relativePath = $_.FullName.Substring($src.Length).TrimStart('\')
            $targetPath = Join-Path $dest $relativePath
            $targetDir = Split-Path $targetPath
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            Copy-Item $_.FullName -Destination $targetPath -Force
        }
        Write-Host "📂 Copied contents of $folderName to $dest"
    }
}

    }
