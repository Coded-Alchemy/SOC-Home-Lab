<#
.SYNOPSIS
    Provisions a single Active Directory user account with standardized attributes.

.DESCRIPTION
    Creates a new AD user in the appropriate OU based on account type (Employee, Contractor,
    or Admin Tier). Enforces naming conventions, sets security attributes, and logs the
    provisioning event.

.PARAMETER FirstName
    User's first name.

.PARAMETER LastName
    User's last name.

.PARAMETER Type
    Account type: Employee | Contractor | Admin0 | Admin1 | Admin2 | Service

.PARAMETER Department
    Department name (e.g., "IT Operations").

.PARAMETER Title
    Job title (e.g., "Systems Administrator").

.PARAMETER Manager
    SAMAccountName of the user's manager.

.PARAMETER DomainFQDN
    Fully qualified domain name (default: corp.lab).

.PARAMETER ExpiryDays
    Number of days until account expires. 0 = no expiry. Defaults to 90 for Contractors.

.EXAMPLE
    .\New-LabUser.ps1 -FirstName "Alice" -LastName "Walker" -Type Employee `
        -Department "IT Operations" -Title "Network Engineer" -Manager "john.smith"

.EXAMPLE
    .\New-LabUser.ps1 -FirstName "Dave" -LastName "Chen" -Type Contractor `
        -Department "External" -Title "Contractor"

.NOTES
    Requires: ActiveDirectory PowerShell module, Domain Admin or delegated OU Create-User rights.
    Lab: corp.lab — adjust $DomainFQDN and OU paths for other environments.
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)] [string] $FirstName,
    [Parameter(Mandatory)] [string] $LastName,
    [Parameter(Mandatory)]
    [ValidateSet("Employee","Contractor","Admin0","Admin1","Admin2","Service")]
    [string] $Type,

    [string] $Department  = "",
    [string] $Title       = "",
    [string] $Manager     = "",
    [string] $DomainFQDN  = "corp.lab",
    [int]    $ExpiryDays  = -1,   # -1 = use type default
    [switch] $ForcePasswordChange = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Derived domain components ─────────────────────────────────────────────────
$DomainDN = ($DomainFQDN.Split('.') | ForEach-Object { "DC=$_" }) -join ","
$BaseDN   = "OU=_CORP,$DomainDN"
$UPNSuffix = "@$DomainFQDN"

# ── OU Paths per account type ─────────────────────────────────────────────────
$OUMap = @{
    Employee   = "OU=Employees,OU=Users,$BaseDN"
    Contractor = "OU=Contractors,OU=Users,$BaseDN"
    Admin0     = "OU=Tier0,OU=Admin Accounts,$BaseDN"
    Admin1     = "OU=Tier1,OU=Admin Accounts,$BaseDN"
    Admin2     = "OU=Tier2,OU=Admin Accounts,$BaseDN"
    Service    = "OU=Service Accounts,$BaseDN"
}

# ── Naming convention per type ─────────────────────────────────────────────────
$Prefix = switch ($Type) {
    "Contractor" { "c-"  }
    "Admin0"     { "a0-" }
    "Admin1"     { "a1-" }
    "Admin2"     { "a2-" }
    "Service"    { "svc-" }
    Default      { ""    }
}

$BaseName   = "$($FirstName.ToLower()).$($LastName.ToLower())"
$SamAccount = "$Prefix$BaseName"
$UPN        = "$SamAccount$UPNSuffix"
$DisplayName = switch ($Type) {
    { $_ -match "Admin" } { "[$($SamAccount.ToUpper())] $FirstName $LastName" }
    Default               { "$FirstName $LastName" }
}
$OUPath = $OUMap[$Type]

# ── Expiry logic ───────────────────────────────────────────────────────────────
if ($ExpiryDays -eq -1) {
    $ExpiryDays = if ($Type -eq "Contractor") { 90 } else { 0 }
}
$AccountExpiry = if ($ExpiryDays -gt 0) { (Get-Date).AddDays($ExpiryDays) } else { $null }

# ── Duplicate check ────────────────────────────────────────────────────────────
$Existing = Get-ADUser -Filter { SamAccountName -eq $SamAccount } -ErrorAction SilentlyContinue
if ($Existing) {
    Write-Error "Account '$SamAccount' already exists (DN: $($Existing.DistinguishedName)). Aborting."
    exit 1
}

# ── Resolve manager ────────────────────────────────────────────────────────────
$ManagerDN = $null
if ($Manager) {
    $ManagerObj = Get-ADUser -Filter { SamAccountName -eq $Manager } -ErrorAction SilentlyContinue
    if ($ManagerObj) {
        $ManagerDN = $ManagerObj.DistinguishedName
    } else {
        Write-Warning "Manager '$Manager' not found in AD — manager field will be left blank."
    }
}

# ── Password prompt ────────────────────────────────────────────────────────────
$SecurePass = Read-Host -Prompt "Initial password for '$SamAccount'" -AsSecureString

# ── Summary ────────────────────────────────────────────────────────────────────
Write-Host "`n--- Account to be created ---" -ForegroundColor Cyan
Write-Host "  SAMAccountName : $SamAccount"
Write-Host "  UPN            : $UPN"
Write-Host "  Display Name   : $DisplayName"
Write-Host "  Type           : $Type"
Write-Host "  OU             : $OUPath"
Write-Host "  Expiry         : $(if ($AccountExpiry) { $AccountExpiry.ToString('yyyy-MM-dd') } else { 'None' })"
Write-Host "  Manager        : $(if ($ManagerDN) { $Manager } else { 'N/A' })"
Write-Host ""

# ── Create account ─────────────────────────────────────────────────────────────
$Params = @{
    SamAccountName        = $SamAccount
    UserPrincipalName     = $UPN
    Name                  = $DisplayName
    GivenName             = $FirstName
    Surname               = $LastName
    DisplayName           = $DisplayName
    Department            = $Department
    Title                 = $Title
    Path                  = $OUPath
    AccountPassword       = $SecurePass
    ChangePasswordAtLogon = [bool]$ForcePasswordChange
    Enabled               = $true
    PasswordNeverExpires  = ($Type -eq "Service")
    CannotChangePassword  = ($Type -eq "Service")
    Description           = "$Type account - provisioned $(Get-Date -Format 'yyyy-MM-dd')"
}

if ($ManagerDN)      { $Params.Manager                 = $ManagerDN }
if ($AccountExpiry)  { $Params.AccountExpirationDate   = $AccountExpiry }

if ($PSCmdlet.ShouldProcess($SamAccount, "Create AD User")) {
    try {
        New-ADUser @Params
        Write-Host "[SUCCESS] User '$SamAccount' created." -ForegroundColor Green

        # Service accounts: restrict to specific workstations (extend as needed)
        if ($Type -eq "Service") {
            Write-Host "[INFO] Service account created. Remember to restrict LogonWorkstations." -ForegroundColor Yellow
        }

        # Log provisioning event
        $LogLine = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | CREATED | $SamAccount | $Type | $OUPath | $env:USERNAME"
        Add-Content -Path ".\provisioning-audit.log" -Value $LogLine

    } catch {
        Write-Error "Failed to create user '$SamAccount': $($_.Exception.Message)"
        exit 1
    }
}
