# Allow-list (exact names)
$AllowedExact = @(
    'LAPSAdmin',
    'WDAGUtilityAccount',
    'Administrator',
    'Guest',
    'DefaultAccount'
)

try {
    $targets = Get-LocalUser | Where-Object {
        $name = $_.Name
        $sid = $_.Sid.Value
        $rid = [int]($sid.Split('-')[-1])

        $isBuiltin = ($rid -lt 1000)
        $isAllowedExact = $AllowedExact -contains $name
        $isLapsAdmin = $name -match '^(?i)Admin'  # prefix match for LAPS accounts with randomized suffix

        -not $isBuiltin -and -not $isAllowedExact -and -not $isLapsAdmin
    }

    foreach ($acct in $targets) {
        try {
            Remove-LocalUser -Name $acct.Name -ErrorAction Stop
        }
        catch {
            # Suppress logging
        }
    }
}
catch {
    # Intentionally suppress logging
}
