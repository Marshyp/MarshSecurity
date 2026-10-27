# Purview eDiscovery repeated HardDelete purge
# Each PowerShell purge processes up to 10 items per mailbox.
#
# Prerequisites:
# ExchangeOnlineManagement 3.9.0+
# Search And Purge permissions
# Existing and VALIDATED Purview Content Search

$SearchName = "SearchNameHere"
$MaxBatches = 100

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Purview repeated HardDelete purge"
Write-Host " Search: $SearchName"
Write-Host " Maximum batches: $MaxBatches"
Write-Host "============================================" -ForegroundColor Cyan

# Connect using the required search-only session
Connect-IPPSSession -EnableSearchOnlySession -DisableWAM

# Validate that the search exists and has completed
$Search = Get-ComplianceSearch -Identity $SearchName

if (-not $Search) {
    throw "Compliance Search '$SearchName' could not be found."
}

if ($Search.Status -ne "Completed") {
    throw "Compliance Search '$SearchName' is not complete. Current status: $($Search.Status)"
}

Write-Host ""
Write-Host "Search found." -ForegroundColor Green
Write-Host "Status: $($Search.Status)"
Write-Host "Items:  $($Search.Items)"
Write-Host ""

for ($Batch = 1; $Batch -le $MaxBatches; $Batch++) {

    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "Starting purge batch $Batch of $MaxBatches"
    Write-Host "============================================" -ForegroundColor Yellow

    $PurgeActionName = "${SearchName}_Purge"

    # Check for an existing purge action
    $ExistingAction = Get-ComplianceSearchAction `
        -Identity $PurgeActionName `
        -ErrorAction SilentlyContinue

    if ($ExistingAction) {

        Write-Host "Existing purge action found:"
        Write-Host "$PurgeActionName"
        Write-Host "Status: $($ExistingAction.Status)"

        # Never remove a purge action that is still running
        if ($ExistingAction.Status -notin @("Completed", "Failed")) {
            Write-Host "Waiting for existing purge action to finish..."

            do {
                Start-Sleep -Seconds 10

                $ExistingAction = Get-ComplianceSearchAction `
                    -Identity $PurgeActionName `
                    -ErrorAction SilentlyContinue

                if ($ExistingAction) {
                    Write-Host "Purge status: $($ExistingAction.Status)"
                }

            } while (
                $ExistingAction -and
                $ExistingAction.Status -notin @("Completed", "Failed")
            )
        }

        Write-Host "Removing previous purge action..."

        Remove-ComplianceSearchAction `
            -Identity $PurgeActionName `
            -Confirm:$false

        # Wait until the action has actually disappeared
        do {
            Start-Sleep -Seconds 5

            $ExistingAction = Get-ComplianceSearchAction `
                -Identity $PurgeActionName `
                -ErrorAction SilentlyContinue

        } while ($ExistingAction)

        Write-Host "Previous purge action removed."
    }

    Write-Host "Creating HardDelete purge action..."

    New-ComplianceSearchAction `
        -SearchName $SearchName `
        -Purge `
        -PurgeType HardDelete `
        -Confirm:$false

    Write-Host "Purge submitted."

    # Wait for the purge to complete
    do {
        Start-Sleep -Seconds 10

        $PurgeAction = Get-ComplianceSearchAction `
            -Identity $PurgeActionName `
            -ErrorAction SilentlyContinue

        if ($PurgeAction) {
            Write-Host "Batch $Batch status: $($PurgeAction.Status)"
        }

    } while (
        -not $PurgeAction -or
        $PurgeAction.Status -notin @("Completed", "Failed")
    )

    if ($PurgeAction.Status -eq "Failed") {

        Write-Error "Purge batch $Batch failed."

        $PurgeAction |
            Format-List Name, Status, Results, Errors

        break
    }

    Write-Host ""
    Write-Host "Batch $Batch completed successfully." -ForegroundColor Green
    Write-Host ""

    # Remove completed purge action ready for the next batch
    Write-Host "Removing completed purge action..."

    Remove-ComplianceSearchAction `
        -Identity $PurgeActionName `
        -Confirm:$false

    do {
        Start-Sleep -Seconds 5

        $ExistingAction = Get-ComplianceSearchAction `
            -Identity $PurgeActionName `
            -ErrorAction SilentlyContinue

    } while ($ExistingAction)

    Write-Host "Completed purge action removed."
    Write-Host ""
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Purge loop finished."
Write-Host "Maximum batches executed: $MaxBatches"
Write-Host ""
Write-Host "IMPORTANT:"
Write-Host "Re-run the Compliance Search and verify the"
Write-Host "remaining results before closing the RTBF."
Write-Host "============================================" -ForegroundColor Cyan
