# Disable Microsoft 365 Companion Apps startup state
$StartupBase = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.M365Companions_8wekyb3d8bbwe'

$StartupIds = @(
    'CalendarStartupId',
    'FilesStartupId',
    'PeopleStartupId'
)

foreach ($StartupId in $StartupIds) {
    $Path = Join-Path $StartupBase $StartupId

    if (Test-Path $Path) {
        try {
            Set-ItemProperty -Path $Path -Name State -Value 1 -Type DWord -ErrorAction Stop
            Write-Output "Disabled startup state: $StartupId"
        }
        catch {
            Write-Warning "Failed to disable startup state $StartupId : $($_.Exception.Message)"
        }
    }
}

# Unpin from taskbar using shell:AppsFolder
try {
    $Shell = New-Object -ComObject Shell.Application
    $AppsFolder = $Shell.Namespace('shell:AppsFolder')

    $TargetApps = foreach ($Item in $AppsFolder.Items()) {
        $Name = $Item.Name
        $Aumid = $Item.ExtendedProperty('System.AppUserModel.ID')
        $PackageFamilyName = $Item.ExtendedProperty('System.AppUserModel.PackageFamilyName')

        if (
            $PackageFamilyName -eq 'Microsoft.M365Companions_8wekyb3d8bbwe' -or
            $Aumid -like 'Microsoft.M365Companions*' -or
            $Name -match '^(People|File Search|Files|Calendar)$'
        ) {
            [pscustomobject]@{
                Name = $Name
                Item = $Item
            }
        }
    }

    foreach ($App in $TargetApps) {
        try {
            $Verbs = @($App.Item.Verbs())

            $UnpinVerb = $Verbs | Where-Object {
                $_.Name.Replace('&', '') -match 'Unpin from taskbar'
            } | Select-Object -First 1

            if ($UnpinVerb) {
                $UnpinVerb.DoIt()
                Write-Output "Unpinned from taskbar: $($App.Name)"
                Start-Sleep -Milliseconds 500
            }
            else {
                # Canonical verb fallback
                $App.Item.InvokeVerb('taskbarunpin')
                Write-Output "Attempted canonical unpin for: $($App.Name)"
                Start-Sleep -Milliseconds 500
            }
        }
        catch {
            Write-Warning "Failed to unpin $($App.Name): $($_.Exception.Message)"
        }
    }
}
catch {
    Write-Warning "Unable to process shell:AppsFolder items: $($_.Exception.Message)"
}

# Stop currently running companion app processes
try {
    $Packages = Get-AppxPackage -Name 'Microsoft.M365Companions' -ErrorAction SilentlyContinue

    foreach ($Package in $Packages) {
        $InstallLocation = $Package.InstallLocation

        if ($InstallLocation) {
            Get-Process -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Path -and $_.Path -like "$InstallLocation*"
                } |
                Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }
}
catch {
    Write-Warning "Failed to stop running Microsoft 365 Companion processes: $($_.Exception.Message)"
}

# Refresh shell
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
start-process explorer

exit 0
