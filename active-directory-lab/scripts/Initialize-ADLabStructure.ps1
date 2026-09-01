<#
.SYNOPSIS
    Initializes the full Active Directory lab OU hierarchy and security groups.

.DESCRIPTION
    Creates all Organizational Units, security groups, and Fine-Grained Password
    Policies (PSOs) required for the corp.lab AD User Management Lab. Idempotent
    — safely re-runnable; existing objects are detected and skipped.

.PARAMETER DomainFQDN
    Fully qualified domain name (default: corp.lab).

.PARAMETER SkipPSO
    Skip PSO creation (useful if domain functional level < 2008).

.PARAMETER SkipGroups
    Skip security group creation.

.EXAMPLE
    .\Initialize-ADLabStructure.ps1

.EXAMPLE
    .\Initialize-ADLabStructure.ps1 -DomainFQDN "lab.internal" -SkipPSO

.NOTES
    Must be run as Domain Admin or equivalent.
    Domain Functional Level must be Windows Server 2008 or higher for PSOs.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $DomainFQDN  = "corp.lab",
    [switch] $SkipPSO,
    [switch] $SkipGroups
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory -ErrorAction Stop

$DomainDN = ($DomainFQDN.Split('.') | ForEach-Object { "DC=$_" }) -join ","
$BaseDN   = "OU=_CORP,$DomainDN"

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  AD Lab Structure Initialization" -ForegroundColor Cyan
Write-Host "  Domain: $DomainFQDN ($DomainDN)" -ForegroundColor Cyan
Write-Host "==================================================`n" -ForegroundColor Cyan

# ── Helper: Safe-NewOU ─────────────────────────────────────────────────────────
function Safe-NewOU {
    param([string]$Name, [string]$Path)
    $DN = "OU=$Name,$Path"
    if (Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $DN } -ErrorAction SilentlyContinue) {
        Write-Host "  [SKIP] OU exists: $DN" -ForegroundColor Gray
    } else {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
        Write-Host "  [+]    OU created: $DN" -ForegroundColor Green
    }
}

# ── Helper: Safe-NewGroup ──────────────────────────────────────────────────────
function Safe-NewGroup {
    param([string]$Name, [string]$Scope, [string]$Path, [string]$Desc)
    if (Get-ADGroup -Filter { SamAccountName -eq $Name } -ErrorAction SilentlyContinue) {
        Write-Host "  [SKIP] Group exists: $Name" -ForegroundColor Gray
    } else {
        New-ADGroup -Name $Name -SamAccountName $Name -GroupScope $Scope `
            -GroupCategory Security -Path $Path -Description $Desc
        Write-Host "  [+]    Group created: $Name ($Scope)" -ForegroundColor Green
    }
}

# ── Helper: Safe-NewPSO ────────────────────────────────────────────────────────
function Safe-NewPSO {
    param([hashtable]$PSO, [string[]]$Subjects)
    if (Get-ADFineGrainedPasswordPolicy -Filter { Name -eq $PSO.Name } -ErrorAction SilentlyContinue) {
        Write-Host "  [SKIP] PSO exists: $($PSO.Name)" -ForegroundColor Gray
    } else {
        New-ADFineGrainedPasswordPolicy @PSO
        foreach ($Subject in $Subjects) {
            Add-ADFineGrainedPasswordPolicySubject -Identity $PSO.Name -Subjects $Subject -ErrorAction SilentlyContinue
        }
        Write-Host "  [+]    PSO created: $($PSO.Name) — Subjects: $($Subjects -join ', ')" -ForegroundColor Green
    }
}

# ════════════════════════════════════════════════════════════
# SECTION 1: OU HIERARCHY
# ════════════════════════════════════════════════════════════
Write-Host "[ OU Structure ]" -ForegroundColor Magenta

Safe-NewOU -Name "_CORP"    -Path $DomainDN
Safe-NewOU -Name "_STAGING" -Path $DomainDN

# Users
Safe-NewOU -Name "Users"       -Path $BaseDN
Safe-NewOU -Name "Employees"   -Path "OU=Users,$BaseDN"
Safe-NewOU -Name "Contractors" -Path "OU=Users,$BaseDN"
Safe-NewOU -Name "Executives"  -Path "OU=Users,$BaseDN"

# Computers
Safe-NewOU -Name "Computers"   -Path $BaseDN
Safe-NewOU -Name "Workstations"-Path "OU=Computers,$BaseDN"
Safe-NewOU -Name "Servers"     -Path "OU=Computers,$BaseDN"
Safe-NewOU -Name "Laptops"     -Path "OU=Computers,$BaseDN"

# Groups
Safe-NewOU -Name "Groups"      -Path $BaseDN
Safe-NewOU -Name "Security"    -Path "OU=Groups,$BaseDN"
Safe-NewOU -Name "Distribution"-Path "OU=Groups,$BaseDN"

# Service Accounts
Safe-NewOU -Name "Service Accounts" -Path $BaseDN

# Admin Tier Model
Safe-NewOU -Name "Admin Accounts" -Path $BaseDN
Safe-NewOU -Name "Tier0"          -Path "OU=Admin Accounts,$BaseDN"
Safe-NewOU -Name "Tier1"          -Path "OU=Admin Accounts,$BaseDN"
Safe-NewOU -Name "Tier2"          -Path "OU=Admin Accounts,$BaseDN"

# ════════════════════════════════════════════════════════════
# SECTION 2: SECURITY GROUPS
# ════════════════════════════════════════════════════════════
if (-not $SkipGroups) {
    Write-Host "`n[ Security Groups ]" -ForegroundColor Magenta
    $GroupOU = "OU=Security,OU=Groups,$BaseDN"

    $Groups = @(
        @{ Name="GRP-IT-Staff";        Scope="Global";      Desc="All IT department staff" },
        @{ Name="GRP-Finance-Staff";   Scope="Global";      Desc="All Finance department staff" },
        @{ Name="GRP-HR-Staff";        Scope="Global";      Desc="All HR department staff" },
        @{ Name="GRP-Executives";      Scope="Global";      Desc="Executive accounts" },
        @{ Name="GRP-Contractors";     Scope="Global";      Desc="All contractor accounts" },
        @{ Name="DL-FileShare-IT-RW";  Scope="DomainLocal"; Desc="Read/Write on IT file share" },
        @{ Name="DL-FileShare-HR-RO";  Scope="DomainLocal"; Desc="Read-Only on HR file share" },
        @{ Name="DL-FileShare-HR-RW";  Scope="DomainLocal"; Desc="Read/Write on HR file share" },
        @{ Name="DL-VPN-Users";        Scope="DomainLocal"; Desc="Permitted VPN users" },
        @{ Name="DL-RDP-Workstations"; Scope="DomainLocal"; Desc="RDP access to workstations" },
        @{ Name="GRP-AdminTier0";      Scope="Global";      Desc="Tier 0 admins - DC access only" },
        @{ Name="GRP-AdminTier1";      Scope="Global";      Desc="Tier 1 admins - Server access" },
        @{ Name="GRP-AdminTier2";      Scope="Global";      Desc="Tier 2 admins - Workstation/Helpdesk" }
    )

    foreach ($g in $Groups) {
        Safe-NewGroup -Name $g.Name -Scope $g.Scope -Path $GroupOU -Desc $g.Desc
    }
}

# ════════════════════════════════════════════════════════════
# SECTION 3: FINE-GRAINED PASSWORD POLICIES
# ════════════════════════════════════════════════════════════
if (-not $SkipPSO) {
    Write-Host "`n[ Fine-Grained Password Policies ]" -ForegroundColor Magenta

    Safe-NewPSO -PSO @{
        Name                        = "PSO-Privileged-Admins"
        DisplayName                 = "Privileged Admin Accounts Password Policy"
        Precedence                  = 10
        MinPasswordLength           = 20
        PasswordHistoryCount        = 24
        MaxPasswordAge              = "60.00:00:00"
        MinPasswordAge              = "1.00:00:00"
        ComplexityEnabled           = $true
        ReversibleEncryptionEnabled = $false
        LockoutThreshold            = 3
        LockoutObservationWindow    = "00:30:00"
        LockoutDuration             = "00:30:00"
    } -Subjects @("GRP-AdminTier0","GRP-AdminTier1")

    Safe-NewPSO -PSO @{
        Name                        = "PSO-Standard-Users"
        DisplayName                 = "Standard User Password Policy"
        Precedence                  = 20
        MinPasswordLength           = 14
        PasswordHistoryCount        = 24
        MaxPasswordAge              = "90.00:00:00"
        MinPasswordAge              = "1.00:00:00"
        ComplexityEnabled           = $true
        ReversibleEncryptionEnabled = $false
        LockoutThreshold            = 5
        LockoutObservationWindow    = "00:15:00"
        LockoutDuration             = "00:15:00"
    } -Subjects @("GRP-IT-Staff","GRP-Finance-Staff","GRP-HR-Staff")

    Safe-NewPSO -PSO @{
        Name                        = "PSO-Contractors"
        DisplayName                 = "Contractor Password Policy"
        Precedence                  = 30
        MinPasswordLength           = 14
        PasswordHistoryCount        = 12
        MaxPasswordAge              = "30.00:00:00"
        MinPasswordAge              = "1.00:00:00"
        ComplexityEnabled           = $true
        ReversibleEncryptionEnabled = $false
        LockoutThreshold            = 3
        LockoutObservationWindow    = "00:15:00"
        LockoutDuration             = "00:15:00"
    } -Subjects @("GRP-Contractors")
}

# ════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  Initialization Complete" -ForegroundColor Cyan
Write-Host "  Run .\Verify-ADLabStructure.ps1 to confirm." -ForegroundColor Cyan
Write-Host "==================================================`n" -ForegroundColor Cyan
