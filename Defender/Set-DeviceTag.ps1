# Microsoft Defender for Endpoint - Device Tag
# Forcefully sets the registry-based MDE device tag to desired tag

$RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection\DeviceTagging"
$ValueName = "Group"
$DesiredValue = "YOURTAGHERE"

Write-Output "Configuring Microsoft Defender for Endpoint device tag..."
Write-Output "Registry Path : $RegistryPath"
Write-Output "Value Name    : $ValueName"
Write-Output "Desired Value : $DesiredValue"

try {
    # Ensure the registry key exists
    if (-not (Test-Path -Path $RegistryPath)) {
        Write-Output "Registry path does not exist. Creating it..."
        New-Item -Path $RegistryPath -Force -ErrorAction Stop | Out-Null
    }

    # Check existing value
    $ExistingValue = (Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue).$ValueName

    if ($null -ne $ExistingValue) {
        Write-Output "Existing device tag: $ExistingValue"
    }
    else {
        Write-Output "No existing device tag found."
    }

    # Forcefully create/overwrite the registry value
    Write-Output "Setting device tag to: $DesiredValue"

    New-ItemProperty `
        -Path $RegistryPath `
        -Name $ValueName `
        -Value $DesiredValue `
        -PropertyType String `
        -Force `
        -ErrorAction Stop | Out-Null

    # Read the value back from the registry
    $ActualValue = (Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction Stop).$ValueName

    # Verify
    if ($ActualValue -eq $DesiredValue) {
        Write-Output "SUCCESS: Defender device tag has been configured correctly."
        Write-Output "Confirmed value: $ActualValue"
        exit 0
    }
    else {
        Write-Error "FAILED: Defender device tag verification failed."
        Write-Error "Expected: $DesiredValue"
        Write-Error "Actual  : $ActualValue"
        exit 1
    }
}
catch {
    Write-Error "FAILED: Unable to configure the Defender device tag."
    Write-Error $_.Exception.Message
    exit 1
}
