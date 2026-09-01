<#
.SYNOPSIS
    Verifies that the AD lab structure is correctly configured.

.DESCRIPTION
    Checks all expected OUs, security groups, PSOs, and audit policy settings.
    Outputs a pass/fail report and saves results to a verification log.

.PARAMETER DomainFQDN
    Fully qualified domain name (default: corp.lab).

.EXAMPLE
    .\Verify-ADLabStructure.ps1

.NOTES
    Run after Initialize-ADLabStructure.ps1 to confirm all objects were created.
    Audit policy checks require elevation on a Domain Controller.
#>

param(
    [string] $DomainFQDN = "corp.lab",
    [string] $LogDir     = "."
)

Import-Module ActiveDirectory -ErrorAction Stop
$DomainDN = ($DomainFQDN.Split('.') | ForEach-Object { "DC=$_" }) -join ","
$BaseDN   = "OU=_CORP,$DomainDN"

$Pass  = 0
$Fail  = 0
$Skips = 0
$Log   = [System.Collections.Generic.List[string]]::new()

function Check {
    param([string]$Label, [bool]$Result, [string]$Detail="")
    if ($Result) {
        Write-Host "  [PASS] $Label" -ForegroundColor Green
        $script:Pass++
        $script:Log.Add("[PASS] $Label")
    } else {
        Write-Host "  [FAIL] $Label$(if ($Detail) {" — $Detail"})" -ForegroundColor Red
        $script:Fail++
        $script:Log.Add("[FAIL] $Label$(if ($Detail) {" — $Detail"})")
    }
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  AD Lab Structure Verification" -ForegroundColor Cyan
Write-Host "  Domain: $DomainFQDN" -ForegroundColor Cyan
Write-Host "==================================================`n" -ForegroundColor Cyan

# ── OU Checks ──────────────────────────────────────────────────────────────────
Write-Host "[ Organizational Units ]" -ForegroundColor Magenta

$ExpectedOUs = @(
    "OU=_CORP,$DomainDN",
    "OU=_STAGING,$DomainDN",
    "OU=Users,$BaseDN",
    "OU=Employees,OU=Users,$BaseDN",
    "OU=Contractors,OU=Users,$BaseDN",
    "OU=Executives,OU=Users,$BaseDN",
    "OU=Computers,$BaseDN",
    "OU=Workstations,OU=Computers,$BaseDN",
    "OU=Servers,OU=Computers,$BaseDN",
    "OU=Laptops,OU=Computers,$BaseDN",
    "OU=Groups,$BaseDN",
    "OU=Security,OU=Groups,$BaseDN",
    "OU=Distribution,OU=Groups,$BaseDN",
    "OU=Service Accounts,$BaseDN",
    "OU=Admin Accounts,$BaseDN",
    "OU=Tier0,OU=Admin Accounts,$BaseDN",
    "OU=Tier1,OU=Admin Accounts,$BaseDN",
    "OU=Tier2,OU=Admin Accounts,$BaseDN"
)

foreach ($OU in $ExpectedOUs) {
    $Exists = Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $OU } -ErrorAction SilentlyContinue
    Check -Label $OU -Result ($null -ne $Exists)
}

# ── Group Checks ───────────────────────────────────────────────────────────────
Write-Host "`n[ Security Groups ]" -ForegroundColor Magenta

$ExpectedGroups = @(
    "GRP-IT-Staff","GRP-Finance-Staff","GRP-HR-Staff","GRP-Executives",
    "GRP-Contractors","DL-FileShare-IT-RW","DL-FileShare-HR-RO","DL-FileShare-HR-RW",
    "DL-VPN-Users","DL-RDP-Workstations","GRP-AdminTier0","GRP-AdminTier1","GRP-AdminTier2"
)

foreach ($Group in $ExpectedGroups) {
    $Exists = Get-ADGroup -Filter { SamAccountName -eq $Group } -ErrorAction SilentlyContinue
    Check -Label $Group -Result ($null -ne $Exists)
}

# ── PSO Checks ────────────────────────────────────────────────────────────────
Write-Host "`n[ Fine-Grained Password Policies ]" -ForegroundColor Magenta

$PSOs = @(
    @{ Name="PSO-Privileged-Admins"; MinLen=20; Precedence=10; Subjects=@("GRP-AdminTier0","GRP-AdminTier1") },
    @{ Name="PSO-Standard-Users";    MinLen=14; Precedence=20; Subjects=@("GRP-IT-Staff") },
    @{ Name="PSO-Contractors";       MinLen=14; Precedence=30; Subjects=@("GRP-Contractors") }
)

foreach ($PSOCheck in $PSOs) {
    $PSO = Get-ADFineGrainedPasswordPolicy -Filter { Name -eq $PSOCheck.Name } -ErrorAction SilentlyContinue
    Check -Label "$($PSOCheck.Name) exists" -Result ($null -ne $PSO)
    if ($PSO) {
        Check -Label "$($PSOCheck.Name) — MinPasswordLength = $($PSOCheck.MinLen)" `
              -Result ($PSO.MinPasswordLength -eq $PSOCheck.MinLen)
        Check -Label "$($PSOCheck.Name) — Precedence = $($PSOCheck.Precedence)" `
              -Result ($PSO.Precedence -eq $PSOCheck.Precedence)
        Check -Label "$($PSOCheck.Name) — ComplexityEnabled" `
              -Result ($PSO.ComplexityEnabled -eq $true)
        Check -Label "$($PSOCheck.Name) — ReversibleEncryption disabled" `
              -Result ($PSO.ReversibleEncryptionEnabled -eq $false)
    }
}

# ── Domain Password Policy ────────────────────────────────────────────────────
Write-Host "`n[ Default Domain Password Policy ]" -ForegroundColor Magenta
$DomPol = Get-ADDefaultDomainPasswordPolicy
Check -Label "Min password length >= 14" -Result ($DomPol.MinPasswordLength -ge 14)
Check -Label "Complexity enabled"         -Result ($DomPol.ComplexityEnabled)
Check -Label "Password history >= 12"     -Result ($DomPol.PasswordHistoryCount -ge 12)
Check -Label "Reversible encryption off"  -Result (-not $DomPol.ReversibleEncryptionEnabled)

# ── Audit Policy (requires DC elevation) ──────────────────────────────────────
Write-Host "`n[ Audit Policy (requires DC / elevation) ]" -ForegroundColor Magenta
try {
    $AuditOutput = auditpol /get /subcategory:"User Account Management" 2>&1
    $UserAcctMgmt = $AuditOutput | Select-String "User Account Management"
    if ($UserAcctMgmt) {
        $IsEnabled = $UserAcctMgmt.ToString() -match "Success and Failure|Success"
        Check -Label "Audit: User Account Management" -Result $IsEnabled
    } else {
        Write-Host "  [SKIP] Could not parse auditpol output (may require DC context)" -ForegroundColor Gray
        $Skips++
    }
} catch {
    Write-Host "  [SKIP] auditpol not accessible: $($_.Exception.Message)" -ForegroundColor Gray
    $Skips++
}

# ── Summary ────────────────────────────────────────────────────────────────────
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  VERIFICATION SUMMARY" -ForegroundColor Cyan
Write-Host "  PASS  : $Pass" -ForegroundColor Green
Write-Host "  FAIL  : $Fail" -ForegroundColor $(if ($Fail -gt 0) { "Red" } else { "Green" })
Write-Host "  SKIP  : $Skips" -ForegroundColor Gray
Write-Host "==================================================`n" -ForegroundColor Cyan

# Save log
$LogPath = Join-Path $LogDir "verify-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$Log | Set-Content -Path $LogPath
Write-Host "[+] Verification log saved: $LogPath`n"

if ($Fail -gt 0) { exit 1 } else { exit 0 }
