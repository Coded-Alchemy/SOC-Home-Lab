<#
.SYNOPSIS
    Performs professional offboarding for an Active Directory user account.

.DESCRIPTION
    Disables the account, strips all group memberships, clears manager reference,
    sets a descriptive offboard note in the Description field, moves the account
    to the _STAGING OU for audit retention, and logs all actions. Does NOT delete
    the account — retention for 90 days is the default policy.

.PARAMETER SamAccountName
    The username to offboard.

.PARAMETER TicketRef
    ITSM ticket reference number for audit trail (e.g., "INC-1234").

.PARAMETER OffboardingOU
    Target OU for disabled accounts. Defaults to OU=_STAGING,DC=corp,DC=lab.

.PARAMETER RetentionDays
    Days after which the account should be reviewed for deletion. Stored in Description.
    Default: 90.

.EXAMPLE
    .\Invoke-ADOffboard.ps1 -SamAccountName "john.smith" -TicketRef "INC-5521"

.NOTES
    Requires: ActiveDirectory PowerShell module, rights to disable/move accounts.
    Always run with -WhatIf first to preview changes.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory)]
    [string] $SamAccountName,

    [string] $TicketRef      = "NO-TICKET",
    [string] $OffboardingOU  = "OU=_STAGING,DC=corp,DC=lab",
    [int]    $RetentionDays  = 90,
    [string] $LogDir         = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory -ErrorAction Stop

# ── Resolve user ───────────────────────────────────────────────────────────────
$User = Get-ADUser -Identity $SamAccountName `
    -Properties MemberOf, Description, Manager, DisplayName, DistinguishedName `
    -ErrorAction SilentlyContinue

if (-not $User) {
    Write-Error "User '$SamAccountName' not found in Active Directory."
    exit 1
}

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host "  OFFBOARDING: $SamAccountName" -ForegroundColor Yellow
Write-Host "  Display Name : $($User.DisplayName)" -ForegroundColor Yellow
Write-Host "  DN           : $($User.DistinguishedName)" -ForegroundColor Yellow
Write-Host "  Ticket       : $TicketRef" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Yellow

if (-not $PSCmdlet.ShouldProcess($SamAccountName, "Offboard AD User")) {
    Write-Host "[DryRun] No changes made." -ForegroundColor Cyan
    exit 0
}

$Actions = [System.Collections.Generic.List[string]]::new()
$Errors  = [System.Collections.Generic.List[string]]::new()

# Step 1 — Disable account
try {
    Disable-ADAccount -Identity $SamAccountName
    $Actions.Add("Account disabled")
    Write-Host "[1/6] Account disabled." -ForegroundColor Green
} catch {
    $Errors.Add("Disable failed: $($_.Exception.Message)")
    Write-Warning "[1/6] Failed to disable account: $($_.Exception.Message)"
}

# Step 2 — Update description
try {
    $ReviewDate  = (Get-Date).AddDays($RetentionDays).ToString("yyyy-MM-dd")
    $NewDesc     = "OFFBOARDED $(Get-Date -Format 'yyyy-MM-dd') | Ticket: $TicketRef | ReviewDeletion: $ReviewDate | PrevDesc: $($User.Description)"
    Set-ADUser -Identity $SamAccountName -Description $NewDesc
    $Actions.Add("Description updated")
    Write-Host "[2/6] Description updated with offboard metadata." -ForegroundColor Green
} catch {
    $Errors.Add("Description update failed: $($_.Exception.Message)")
    Write-Warning "[2/6] Failed to update description: $($_.Exception.Message)"
}

# Step 3 — Remove group memberships
$RemovedGroups = @()
try {
    $Groups = @($User.MemberOf)
    if ($Groups.Count -gt 0) {
        foreach ($GroupDN in $Groups) {
            try {
                $GroupName = (Get-ADGroup -Identity $GroupDN).Name
                Remove-ADGroupMember -Identity $GroupDN -Members $SamAccountName -Confirm:$false
                $RemovedGroups += $GroupName
                Write-Host "  [-] Removed from: $GroupName" -ForegroundColor DarkYellow
            } catch {
                Write-Warning "  [!] Could not remove from ${GroupDN}: $($_.Exception.Message)"
                $Errors.Add("Group removal failed ($GroupDN): $($_.Exception.Message)")
            }
        }
        $Actions.Add("Removed from $($RemovedGroups.Count) group(s): $($RemovedGroups -join ', ')")
        Write-Host "[3/6] Removed from $($RemovedGroups.Count) group(s)." -ForegroundColor Green
    } else {
        Write-Host "[3/6] No additional group memberships to remove." -ForegroundColor Gray
        $Actions.Add("No additional group memberships found")
    }
} catch {
    $Errors.Add("Group enumeration failed: $($_.Exception.Message)")
    Write-Warning "[3/6] Group removal encountered errors."
}

# Step 4 — Clear manager
try {
    Set-ADUser -Identity $SamAccountName -Clear Manager
    $Actions.Add("Manager reference cleared")
    Write-Host "[4/6] Manager reference cleared." -ForegroundColor Green
} catch {
    $Errors.Add("Manager clear failed: $($_.Exception.Message)")
    Write-Warning "[4/6] Failed to clear manager: $($_.Exception.Message)"
}

# Step 5 — Set expiry to now (belt-and-suspenders)
try {
    Set-ADUser -Identity $SamAccountName -AccountExpirationDate (Get-Date)
    $Actions.Add("Account expiry set to now")
    Write-Host "[5/6] Account expiration set to current time." -ForegroundColor Green
} catch {
    $Errors.Add("Expiry set failed: $($_.Exception.Message)")
    Write-Warning "[5/6] Failed to set expiry: $($_.Exception.Message)"
}

# Step 6 — Move to offboarding OU
try {
    # Re-fetch DN after modifications
    $FreshUser = Get-ADUser -Identity $SamAccountName
    Move-ADObject -Identity $FreshUser.DistinguishedName -TargetPath $OffboardingOU
    $Actions.Add("Moved to $OffboardingOU")
    Write-Host "[6/6] Account moved to $OffboardingOU." -ForegroundColor Green
} catch {
    $Errors.Add("OU move failed: $($_.Exception.Message)")
    Write-Warning "[6/6] Failed to move account: $($_.Exception.Message)"
}

# ── Audit log ──────────────────────────────────────────────────────────────────
$LogPath  = Join-Path $LogDir "offboarding-audit.log"
$LogEntry = @"
=====================================
OFFBOARD EVENT
Timestamp  : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Account    : $SamAccountName
Display    : $($User.DisplayName)
Ticket     : $TicketRef
Executed By: $env:USERNAME on $env:COMPUTERNAME
Actions    :
$($Actions | ForEach-Object { "  - $_" } | Out-String)
Errors     :
$(if ($Errors.Count -gt 0) { $Errors | ForEach-Object { "  ! $_" } | Out-String } else { "  None" })
=====================================

"@
Add-Content -Path $LogPath -Value $LogEntry

# ── Summary ────────────────────────────────────────────────────────────────────
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  OFFBOARDING COMPLETE: $SamAccountName" -ForegroundColor Cyan
Write-Host "  Actions taken: $($Actions.Count)" -ForegroundColor Cyan
if ($Errors.Count -gt 0) {
    Write-Host "  Errors: $($Errors.Count) — review log" -ForegroundColor Red
} else {
    Write-Host "  Errors: 0" -ForegroundColor Green
}
Write-Host "  Log: $LogPath" -ForegroundColor Cyan
Write-Host "  Account retained in $_STAGING for $RetentionDays-day audit hold." -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan
