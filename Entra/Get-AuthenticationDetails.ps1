## This script will export the authentication details and registered devices
## of any user in Entra. 
##
## Reference: https://enclave.ai/blog/authmask-we-made-microsoft-authenticator-hand-over-tokens
##

Connect-MgGraph -Scopes "User.Read.All","UserAuthMethod-MicrosoftAuthApp.Read.All"

$Users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled

$Results = foreach ($User in $Users) {

    try {

        $Methods = Get-MgUserAuthenticationMicrosoftAuthenticatorMethod `
            -UserId $User.Id `
            -ErrorAction Stop

        foreach ($Method in $Methods) 

            [PSCustomObject]@{
                DisplayName       = $User.DisplayName
                UserPrincipalName = $User.UserPrincipalName
                AccountEnabled    = $User.AccountEnabled
                AuthenticatorId   = $Method.Id
                DisplayNameDevice = $Method.DisplayName
                DeviceTag         = $Method.DeviceTag
                PhoneAppVersion   = $Method.PhoneAppVersion
                CreatedDateTime   = $Method.CreatedDateTime
            }
        }
    }
    catch {

        Write-Warning "Failed to query $($User.UserPrincipalName): $($_.Exception.Message)"
    }
}

$Results |
    Sort-Object UserPrincipalName |
    Format-Table -AutoSize

$Results |
    Export-Csv ".\MicrosoftAuthenticatorRegistrations.csv" -NoTypeInformation
