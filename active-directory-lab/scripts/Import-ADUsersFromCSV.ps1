<#
.SYNOPSIS
    Bulk-provisions Active Directory users from a CSV file.

.DESCRIPTION
    Reads a structured CSV and creates AD accounts for each row. Supports dry-run
    mode, duplicate detection, per-type OU routing, account expiry, and structured
    logging. Generates a timestamped provisioning report on completion.

.PARAMETER CsvPath
    Path to the input CSV file. Required columns:
    FirstName, LastName, Department, Title, Manager, Type, OUPath

.PARAMETER DefaultPassword
    If provided, all accounts use this initial password. If omitted, the script
    prompts per account. Use DefaultPassword only in isolated lab environments.

.PARAMETER WhatIf
    Dry-run mode — prints what would be created without making any changes.

.PARAMETER LogDir
    Directory for output logs. Defaults to current directory.

.EXAMPLE
    # Dry-run first
    .\Import-ADUsersFromCSV.ps1 -CsvPath .\users.csv -WhatIf

    # Execute with a lab default password
    .\Import-ADUsersFromCSV.ps1 -CsvPath .\users.csv -DefaultPassword "LabInit@2024"

.NOTES
    Requires: ActiveDirectory PowerShell module, appropriate AD delegation.
    CSV must use UTF-8 encoding with BOM to handle special characters in names.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $CsvPath,

    [string] $DefaultPassword = $null,
    [string] $DomainUPNSuffix = "corp.lab",
    [string] $LogDir          = ".",
    [switch] $WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory -ErrorAction Stop

# ── Setup ──────────────────────────────────────────────────────────────────────
$Timestamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile    = Join-Path $LogDir "provisioning-log-$Timestamp.csv"
$ErrorLog   = Join-Path $LogDir "provisioning-errors-$Timestamp.log"
$Results    = [System.Collections.Generic.List[PSObject]]::new()

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  AD Bulk User Provisioning" -ForegroundColor Cyan
Write-Host "  CSV: $CsvPath" -ForegroundColor Cyan
Write-Host "  WhatIf: $WhatIf" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

$Users = Import-Csv -Path $CsvPath -Encoding UTF8
Write-Host "[*] Loaded $($Users.Count) rows from CSV.`n"

# ── Required CSV columns ───────────────────────────────────────────────────────
$Required = @("FirstName","LastName","Department","Title","Manager","Type","OUPath")
$Headers  = $Users[0].PSObject.Properties.Name
$Missing  = $Required | Where-Object { $_ -notin $Headers }
if ($Missing) {
    Write-Error "CSV is missing required columns: $($Missing -join ', ')"
    exit 1
}

# ── Prefix map ─────────────────────────────────────────────────────────────────
$PrefixMap = @{
    Employee   = ""
    Contractor = "c-"
    Admin0     = "a0-"
    Admin1     = "a1-"
    Admin2     = "a2-"
    Service    = "svc-"
}

$RowNum = 0

foreach ($Row in $Users) {

    $RowNum++
    $Status = "Created"
    $ErrMsg = ""

    try {
        # Validate Type
        if (-not $PrefixMap.ContainsKey($Row.Type)) {
            throw "Unknown Type '$($Row.Type)'. Valid: Employee, Contractor, Admin0, Admin1, Admin2, Service"
        }

        $Prefix      = $PrefixMap[$Row.Type]
        $BaseName    = "$($Row.FirstName.ToLower()).$($Row.LastName.ToLower())"
        # Sanitize names: remove spaces and apostrophes for SAM
        $BaseName    = $BaseName -replace "[' ]", ""
        $SamAccount  = "$Prefix$BaseName"
        $UPN         = "$SamAccount@$DomainUPNSuffix"
        $DisplayName = "$($Row.FirstName) $($Row.LastName)"
        $IsContractor = $Row.Type -eq "Contractor"
        $IsService    = $Row.Type -eq "Service"
        $Expiry      = if ($IsContractor) { (Get-Date).AddDays(90) } else { $null }

        # Duplicate check
        $Exists = Get-ADUser -Filter { SamAccountName -eq $SamAccount } -ErrorAction SilentlyContinue
        if ($Exists) {
            Write-Warning "  [ROW $RowNum] SKIP — $SamAccount already exists."
            $Status = "Skipped (exists)"
            $Results.Add([PSCustomObject]@{
                Row         = $RowNum
                SamAccount  = $SamAccount
                Type        = $Row.Type
                Status      = $Status
                Error       = ""
            })
            continue
        }

        # Resolve manager
        $ManagerDN = $null
        if ($Row.Manager -and $Row.Manager.Trim() -ne "") {
            $ManagerObj = Get-ADUser -Filter { SamAccountName -eq $Row.Manager } -ErrorAction SilentlyContinue
            if ($ManagerObj) { $ManagerDN = $ManagerObj.DistinguishedName }
            else { Write-Warning "  [ROW $RowNum] Manager '$($Row.Manager)' not found — skipping manager field." }
        }

        # Password
        if ($DefaultPassword) {
            $SecurePass = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
        } else {
            $SecurePass = Read-Host "  Password for '$SamAccount'" -AsSecureString
        }

        # Account params
        $Params = @{
            SamAccountName        = $SamAccount
            UserPrincipalName     = $UPN
            Name                  = $DisplayName
            GivenName             = $Row.FirstName
            Surname               = $Row.LastName
            DisplayName           = $DisplayName
            Department            = $Row.Department
            Title                 = $Row.Title
            Path                  = $Row.OUPath
            AccountPassword       = $SecurePass
            ChangePasswordAtLogon = (-not $IsService)
            Enabled               = $true
            PasswordNeverExpires  = $IsService
            CannotChangePassword  = $IsService
            Description           = "$($Row.Type) account - provisioned $(Get-Date -Format 'yyyy-MM-dd') via bulk import"
        }
        if ($ManagerDN) { $Params.Manager               = $ManagerDN }
        if ($Expiry)    { $Params.AccountExpirationDate  = $Expiry }

        if ($WhatIf) {
            Write-Host "  [WHATIF] Would create: $SamAccount | $($Row.Type) | OU: $($Row.OUPath)" -ForegroundColor Yellow
            $Status = "WhatIf"
        } else {
            New-ADUser @Params
            Write-Host "  [+] Created: $SamAccount ($($Row.Type))" -ForegroundColor Green
        }

    } catch {
        $Status = "FAILED"
        $ErrMsg = $_.Exception.Message
        Write-Warning "  [ROW $RowNum] FAILED ($SamAccount): $ErrMsg"
        Add-Content -Path $ErrorLog -Value "ROW $RowNum | $SamAccount | $ErrMsg"
    }

    $Results.Add([PSCustomObject]@{
        Row        = $RowNum
        SamAccount = $SamAccount
        Type       = $Row.Type
        OU         = $Row.OUPath
        Status     = $Status
        Error      = $ErrMsg
    })
}

# ── Summary ─────────────────────────────────────────────────────────────────
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  Provisioning Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
$Results | Group-Object Status | ForEach-Object {
    $Color = switch ($_.Name) {
        "Created"         { "Green"  }
        "WhatIf"          { "Yellow" }
        "Skipped (exists)"{ "Gray"   }
        "FAILED"          { "Red"    }
        Default           { "White"  }
    }
    Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor $Color
}

$Results | Export-Csv -Path $LogFile -NoTypeInformation -Encoding UTF8
Write-Host "`n[+] Full log written to: $LogFile" -ForegroundColor Cyan
if (Test-Path $ErrorLog) {
    Write-Host "[!] Error details at: $ErrorLog" -ForegroundColor Yellow
}
