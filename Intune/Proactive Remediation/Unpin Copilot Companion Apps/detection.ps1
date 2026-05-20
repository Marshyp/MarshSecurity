$NonCompliant = $false

# Microsoft 365 Companion Apps startup state
$StartupBase = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.M365Companions_8wekyb3d8bbwe'

$StartupIds = @(
    'CalendarStartupId',
    'FilesStartupId',
    'PeopleStartupId'
)

foreach ($StartupId in $StartupIds) {
    $Path = Join-Path $StartupBase $StartupId

    if (Test-Path $Path) {
        $State = (Get-ItemProperty -Path $Path -Name State -ErrorAction SilentlyContinue).State

        # 0 = enabled, 1 = disabled
        if ($State -eq 0) {
            Write-Output "$StartupId is enabled"
            $NonCompliant = $true
        }
    }
}

# Check for AppsFolder taskbar pins
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
        $VerbNames = @($App.Item.Verbs()) | ForEach-Object {
            $_.Name.Replace('&', '')
        }

        if (($VerbNames -join '|') -match 'Unpin from taskbar') {
            Write-Output "$($App.Name) appears to be pinned to the taskbar"
            $NonCompliant = $true
        }
    }
}
catch {
    Write-Warning "Unable to query shell:AppsFolder taskbar state: $($_.Exception.Message)"
}

if ($NonCompliant) {
    exit 1
}

exit 0
