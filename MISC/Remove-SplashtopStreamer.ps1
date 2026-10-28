# Uninstall Splashtop Streamer
# Designed for interactive execution or deployment via Intune
# Run as Administrator / SYSTEM

$ErrorActionPreference = "Stop"

Write-Output "Searching for Splashtop Streamer..."

$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$SplashtopApps = Get-ItemProperty $RegistryPaths -ErrorAction SilentlyContinue |
    Where-Object {
        $_.DisplayName -like "*Splashtop Streamer*"
    }

if (-not $SplashtopApps) {
    Write-Output "Splashtop Streamer is not installed."
    exit 0
}

foreach ($App in $SplashtopApps) {

    Write-Output "Found: $($App.DisplayName)"
    Write-Output "Version: $($App.DisplayVersion)"

    # Prefer the vendor-provided silent uninstall command when available
    $UninstallString = $App.QuietUninstallString

    if ([string]::IsNullOrWhiteSpace($UninstallString)) {
        $UninstallString = $App.UninstallString
    }

    if ([string]::IsNullOrWhiteSpace($UninstallString)) {
        Write-Error "No uninstall command found for $($App.DisplayName)"
        exit 1
    }

    Write-Output "Uninstall command found: $UninstallString"

    # Check whether the uninstall command contains an MSI product GUID
    if ($UninstallString -match "\{[A-Fa-f0-9\-]{36}\}") {

        $ProductCode = $Matches[0]

        Write-Output "MSI product code: $ProductCode"
        Write-Output "Starting silent MSI uninstall..."

        $Process = Start-Process `
            -FilePath "msiexec.exe" `
            -ArgumentList "/x $ProductCode /qn /norestart" `
            -Wait `
            -PassThru
    }
    else {

        # Handle an EXE-based uninstall command
        $Command = $UninstallString.Trim()

        if ($Command -match '^"([^"]+)"\s*(.*)$') {
            $Executable = $Matches[1]
            $Arguments = $Matches[2]
        }
        else {
            $Parts = $Command -split "\s+", 2

            $Executable = $Parts[0]

            if ($Parts.Count -gt 1) {
                $Arguments = $Parts[1]
            }
            else {
                $Arguments = ""
            }
        }

        # If we're using UninstallString rather than QuietUninstallString,
        # add /S when no obvious silent argument is already present.
        if ($Arguments -notmatch "(?i)(/quiet|/qn|/silent|/s\b)") {
            $Arguments = "$Arguments /S".Trim()
        }

        Write-Output "Executable: $Executable"
        Write-Output "Arguments: $Arguments"
        Write-Output "Starting uninstall..."

        try {
            $Process = Start-Process `
                -FilePath $Executable `
                -ArgumentList $Arguments `
                -Wait `
                -PassThru
        }
        catch {
            Write-Error "Failed to start Splashtop uninstaller: $($_.Exception.Message)"
            exit 1
        }
    }

    Write-Output "Uninstaller exit code: $($Process.ExitCode)"

    # Common successful / acceptable Windows Installer exit codes:
    # 0    = Success
    # 1605 = Product not installed
    # 1614 = Product already uninstalled
    # 1641 = Success, reboot initiated
    # 3010 = Success, reboot required
    if ($Process.ExitCode -notin @(0, 1605, 1614, 1641, 3010)) {
        Write-Error "Splashtop Streamer uninstall failed with exit code $($Process.ExitCode)"
        exit $Process.ExitCode
    }
}

Write-Output "Uninstall process completed. Verifying removal..."

Start-Sleep -Seconds 3

$Remaining = Get-ItemProperty $RegistryPaths -ErrorAction SilentlyContinue |
    Where-Object {
        $_.DisplayName -like "*Splashtop Streamer*"
    }

if ($Remaining) {

    foreach ($App in $Remaining) {
        Write-Output "Still detected: $($App.DisplayName) $($App.DisplayVersion)"
    }

    Write-Error "Splashtop Streamer is still detected after the uninstall."
    exit 1
}

Write-Output "Splashtop Streamer successfully removed."
exit 0
