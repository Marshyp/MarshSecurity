# Allow-list (exact names)
$AllowedExact = @(
    'LAPSAdmin',
    'WDAGUtilityAccount',
    'Administrator',
    'Guest',
    'DefaultAccount'
)

try {
    $removable = Get-LocalUser | Where-Object {
        $name = $_.Name
        $sid = $_.Sid.Value
        # Built-ins have RID < 1000 (e.g., 500, 501, 503, 504). User-created start at 1000+.
        $rid = [int]($sid.Split('-')[-1])

        $isBuiltin = ($rid -lt 1000)
        $isAllowedExact = $AllowedExact -contains $name
        $isLapsAdmin = $name -match '^(?i)Admin'  # prefix match for LAPS accounts with randomized suffix

        -not $isBuiltin -and -not $isAllowedExact -and -not $isLapsAdmin
    }
}
catch {
    # If anything untoward occurs, signal non-compliant so remediation can attempt cleanup
    Write-Output "Error enumerating local users: $($_.Exception.Message)"
    exit 1
}

if ($removable -and $removable.Count -gt 0) {
    $removable | ForEach-Object { $_.Name } | Sort-Object | ForEach-Object { Write-Output $_ }
    exit 1  # Non-compliant -> triggers remediation
} else {
    Write-Output "Compliant"
    exit 0
}
