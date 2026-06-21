# Active Directory User Management — Lab Guide
**Classification:** Internal Lab Documentation  
**Version:** 1.0  
**Scope:** Active Directory User Provisioning, OU Design, Group Policy, Security Hardening  
**Environment:** Windows Server 2019/2022 + Windows 10/11 Domain Members

---

## Table of Contents

1. [Lab Overview & Prerequisites](#1-lab-overview--prerequisites)
2. [Domain & OU Structure Design](#2-domain--ou-structure-design)
3. [User Account Provisioning](#3-user-account-provisioning)
4. [Security Groups & RBAC](#4-security-groups--rbac)
5. [Password Policy & Fine-Grained PSOs](#5-password-policy--fine-grained-psos)
6. [User Account Hardening](#6-user-account-hardening)
7. [Group Policy for User Environment](#7-group-policy-for-user-environment)
8. [Bulk Provisioning with PowerShell](#8-bulk-provisioning-with-powershell)
9. [Account Lifecycle Management](#9-account-lifecycle-management)
10. [Audit & Monitoring](#10-audit--monitoring)
11. [Verification Checklist](#11-verification-checklist)
12. [Reference Tables](#12-reference-tables)

---

## 1. Lab Overview & Prerequisites

### Purpose

This lab establishes a professional-grade Active Directory user management environment, covering account provisioning, Organizational Unit (OU) hierarchy, Role-Based Access Control (RBAC) via security groups, fine-grained password policies, Group Policy Object (GPO) application, and account lifecycle procedures.

All steps follow Microsoft best practices and are aligned to the NIST SP 800-53 AC (Access Control) control family where applicable.

### Lab Environment Assumptions

| Component | Specification |
|---|---|
| Domain Controller | Windows Server 2019 or 2022 |
| Domain Name | `corp.lab` (adjust to your lab) |
| NetBIOS Name | `CORP` |
| Domain Functional Level | Windows Server 2016 or higher |
| Forest Functional Level | Windows Server 2016 or higher |
| Admin Workstation | Domain-joined Windows 10/11 |

### Prerequisites

Before beginning:

- A functioning Active Directory Domain Services (AD DS) domain with at least one Domain Controller
- Domain Administrator credentials
- Remote Server Administration Tools (RSAT) installed on your admin workstation, or access to the DC console
- PowerShell 5.1+ (built into Windows Server 2019/2022)
- Active Directory PowerShell module loaded (`Import-Module ActiveDirectory`)

### Enable RSAT on Admin Workstation (Windows 10/11)

```powershell
# Install AD DS Tools via RSAT (Windows 10/11)
Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"

# Verify installation
Get-WindowsCapability -Online -Name "Rsat.ActiveDirectory*"
```

---

## 2. Domain & OU Structure Design

### Why OU Design Matters

Organizational Units serve three primary functions in AD:

1. **Delegation** — grant specific admins control over a subset of objects without elevating to Domain Admin
2. **GPO Linkage** — apply Group Policy to scoped sets of users and computers
3. **Object Organization** — logical separation of users, computers, and service accounts for manageability and security

### Recommended OU Hierarchy

The following structure separates privileged accounts, service accounts, and standard users — a foundational security control.

```
corp.lab
├── _CORP                          (top-level umbrella OU)
│   ├── Users
│   │   ├── Employees              (standard user accounts)
│   │   ├── Contractors            (contractor accounts — shorter password policies)
│   │   └── Executives             (executive accounts — stricter policies)
│   ├── Computers
│   │   ├── Workstations
│   │   ├── Servers
│   │   └── Laptops
│   ├── Groups
│   │   ├── Security               (security groups used for ACLs/RBAC)
│   │   └── Distribution           (email distribution lists)
│   ├── Service Accounts           (non-interactive service accounts, MSAs)
│   └── Admin Accounts             (privileged user accounts — separate from daily-use)
│       ├── Tier0                  (Domain/Enterprise Admins — DC access only)
│       ├── Tier1                  (Server Admins)
│       └── Tier2                  (Workstation Admins / Helpdesk)
└── _STAGING                       (pre-production / newly joined objects)
```

> **Security Note:** Placing admin accounts in a dedicated OU allows targeted GPO enforcement (e.g., no internet access, no email client, forced smart card login) without impacting standard users.

### Create the OU Structure via PowerShell

Run the following on a Domain Controller or from your RSAT workstation:

```powershell
# --- OU Creation Script ---
# Adjust $Domain to match your environment

$Domain = "DC=corp,DC=lab"
$Base   = "OU=_CORP,$Domain"

# Top-level
New-ADOrganizationalUnit -Name "_CORP"     -Path $Domain    -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "_STAGING"  -Path $Domain    -ProtectedFromAccidentalDeletion $true

# Users sub-OUs
New-ADOrganizationalUnit -Name "Users"         -Path $Base  -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Employees"     -Path "OU=Users,$Base"     -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Contractors"   -Path "OU=Users,$Base"     -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Executives"    -Path "OU=Users,$Base"     -ProtectedFromAccidentalDeletion $true

# Computers
New-ADOrganizationalUnit -Name "Computers"     -Path $Base  -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Workstations"  -Path "OU=Computers,$Base" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Servers"       -Path "OU=Computers,$Base" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Laptops"       -Path "OU=Computers,$Base" -ProtectedFromAccidentalDeletion $true

# Groups
New-ADOrganizationalUnit -Name "Groups"        -Path $Base  -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Security"      -Path "OU=Groups,$Base"    -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Distribution"  -Path "OU=Groups,$Base"    -ProtectedFromAccidentalDeletion $true

# Service Accounts
New-ADOrganizationalUnit -Name "Service Accounts" -Path $Base -ProtectedFromAccidentalDeletion $true

# Admin Tier Model
New-ADOrganizationalUnit -Name "Admin Accounts" -Path $Base  -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Tier0"          -Path "OU=Admin Accounts,$Base" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Tier1"          -Path "OU=Admin Accounts,$Base" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Tier2"          -Path "OU=Admin Accounts,$Base" -ProtectedFromAccidentalDeletion $true

Write-Host "[+] OU structure created successfully." -ForegroundColor Green
```

### Verify the OU Tree

```powershell
# Display full OU tree
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName | Sort-Object DistinguishedName
```

---

## 3. User Account Provisioning

### Naming Convention

Consistent naming is critical for automation, SIEM correlation, and audit trails. Use the following standard:

| Account Type | Username Format | Example |
|---|---|---|
| Standard Employee | `firstname.lastname` | `john.smith` |
| Admin (Tier 0) | `a0-firstname.lastname` | `a0-john.smith` |
| Admin (Tier 1) | `a1-firstname.lastname` | `a1-john.smith` |
| Admin (Tier 2) | `a2-firstname.lastname` | `a2-john.smith` |
| Service Account | `svc-appname` | `svc-sqlreport` |
| Contractor | `c-firstname.lastname` | `c-jane.doe` |

> **Rationale:** Prefixed admin accounts are immediately identifiable in logs (Splunk/SIEM), making detection of privilege escalation and lateral movement much easier. A Tier 0 account appearing on a workstation is an instant alert condition.

### Provision a Single Standard User

```powershell
# --- New-LabUser.ps1 ---
# Provisions a single standard employee account

$FirstName  = "John"
$LastName   = "Smith"
$Department = "IT Operations"
$Title      = "Systems Administrator"
$Manager    = "jane.doe"           # SAMAccountName of manager
$OUPath     = "OU=Employees,OU=Users,OU=_CORP,DC=corp,DC=lab"

# Derive standard attributes
$SamAccount = "$($FirstName.ToLower()).$($LastName.ToLower())"
$UPN        = "$SamAccount@corp.lab"
$DisplayName= "$FirstName $LastName"

# Secure password prompt — never hardcode passwords
$SecurePassword = Read-Host "Set initial password for $SamAccount" -AsSecureString

# Create the account
New-ADUser `
    -SamAccountName     $SamAccount `
    -UserPrincipalName  $UPN `
    -Name               $DisplayName `
    -GivenName          $FirstName `
    -Surname            $LastName `
    -DisplayName        $DisplayName `
    -Department         $Department `
    -Title              $Title `
    -Manager            (Get-ADUser $Manager) `
    -Path               $OUPath `
    -AccountPassword    $SecurePassword `
    -ChangePasswordAtLogon $true `
    -Enabled            $true `
    -PasswordNeverExpires $false `
    -CannotChangePassword $false `
    -Description        "Employee account - provisioned $(Get-Date -Format 'yyyy-MM-dd')"

Write-Host "[+] User $SamAccount created in $OUPath" -ForegroundColor Green
```

### Provision a Privileged Admin Account (Tiered)

```powershell
# --- New-AdminAccount.ps1 ---
# Provisions a Tier 1 server admin account paired to an existing standard user

$BaseUser   = "john.smith"         # Existing standard user SAMAccountName
$Tier       = "1"                  # 0, 1, or 2
$OUPath     = "OU=Tier1,OU=Admin Accounts,OU=_CORP,DC=corp,DC=lab"

$AdminSam   = "a$Tier-$BaseUser"
$AdminUPN   = "$AdminSam@corp.lab"

# Look up base user for display name
$BaseADUser = Get-ADUser -Identity $BaseUser -Properties DisplayName
$DisplayName = "[$($AdminSam.ToUpper())] $($BaseADUser.DisplayName)"

$SecurePassword = Read-Host "Set initial password for $AdminSam" -AsSecureString

New-ADUser `
    -SamAccountName     $AdminSam `
    -UserPrincipalName  $AdminUPN `
    -Name               $DisplayName `
    -DisplayName        $DisplayName `
    -Path               $OUPath `
    -AccountPassword    $SecurePassword `
    -ChangePasswordAtLogon $true `
    -Enabled            $true `
    -PasswordNeverExpires $false `
    -Description        "Tier$Tier Admin account for $BaseUser - provisioned $(Get-Date -Format 'yyyy-MM-dd')" `
    -SmartcardLogonRequired $false    # Set to $true if smart card enforcement is in place

Write-Host "[+] Admin account $AdminSam created." -ForegroundColor Green
```

### Provision a Service Account

Service accounts must be non-interactive (no logon workstation, no MFA bypass) and use Managed Service Accounts where possible. For lab scenarios using standard accounts:

```powershell
# --- New-ServiceAccount.ps1 ---

$ServiceName = "sqlreport"
$Description = "SQL Reporting Services - read-only reporting queries"
$OUPath      = "OU=Service Accounts,OU=_CORP,DC=corp,DC=lab"

$SamAccount  = "svc-$ServiceName"
$UPN         = "$SamAccount@corp.lab"

$SecurePassword = Read-Host "Set password for $SamAccount" -AsSecureString

New-ADUser `
    -SamAccountName         $SamAccount `
    -UserPrincipalName      $UPN `
    -Name                   $SamAccount `
    -DisplayName            "SVC - $ServiceName" `
    -Description            $Description `
    -Path                   $OUPath `
    -AccountPassword        $SecurePassword `
    -Enabled                $true `
    -PasswordNeverExpires   $true `      # Common for service accounts — compensate with rotation policy
    -CannotChangePassword   $true `
    -ChangePasswordAtLogon  $false

# Restrict logon hours to deny interactive logon if feasible
# Additional: set "Log On To" restriction to specific servers only
Set-ADUser -Identity $SamAccount -LogonWorkstations "SRV-SQL01"

Write-Host "[+] Service account $SamAccount created." -ForegroundColor Green
```

> **Security Note:** For production, prefer **Group Managed Service Accounts (gMSA)** over standard service accounts. gMSAs rotate passwords automatically and eliminate credential exposure. Lab setup for gMSA is covered in the [Reference Tables](#12-reference-tables) section.

---

## 4. Security Groups & RBAC

### Group Types & Scope

| Scope | Use Case |
|---|---|
| **Domain Local** | Assign permissions to resources within the domain (e.g., share ACLs) |
| **Global** | Organize users within a domain; nested into Domain Local or Universal groups |
| **Universal** | Multi-domain forests; used for forest-wide membership |

**Best Practice — AGDLP Model:**
> **A**ccounts → **G**lobal groups → **D**omain **L**ocal groups → **P**ermissions

Users are added to Global groups (by role/department). Global groups are nested into Domain Local groups. Domain Local groups are assigned permissions on resources.

### Create Standard Security Groups

```powershell
# --- New-SecurityGroups.ps1 ---

$GroupOU = "OU=Security,OU=Groups,OU=_CORP,DC=corp,DC=lab"

$Groups = @(
    # --- Role / Department Global Groups ---
    @{ Name = "GRP-IT-Staff";          Scope = "Global";      Desc = "All IT department staff" },
    @{ Name = "GRP-Finance-Staff";     Scope = "Global";      Desc = "All Finance department staff" },
    @{ Name = "GRP-HR-Staff";          Scope = "Global";      Desc = "All HR department staff" },
    @{ Name = "GRP-Executives";        Scope = "Global";      Desc = "Executive accounts" },
    @{ Name = "GRP-Contractors";       Scope = "Global";      Desc = "All contractor accounts" },

    # --- Resource Access Domain Local Groups ---
    @{ Name = "DL-FileShare-IT-RW";    Scope = "DomainLocal"; Desc = "Read/Write on IT file share" },
    @{ Name = "DL-FileShare-HR-RO";    Scope = "DomainLocal"; Desc = "Read-Only on HR file share" },
    @{ Name = "DL-FileShare-HR-RW";    Scope = "DomainLocal"; Desc = "Read/Write on HR file share" },
    @{ Name = "DL-VPN-Users";          Scope = "DomainLocal"; Desc = "Permitted VPN users" },
    @{ Name = "DL-RDP-Workstations";   Scope = "DomainLocal"; Desc = "RDP access to workstations" },

    # --- Privileged Access Groups ---
    @{ Name = "GRP-AdminTier0";        Scope = "Global";      Desc = "Tier 0 admins — DC access" },
    @{ Name = "GRP-AdminTier1";        Scope = "Global";      Desc = "Tier 1 admins — Server access" },
    @{ Name = "GRP-AdminTier2";        Scope = "Global";      Desc = "Tier 2 admins — Workstation/Helpdesk" }
)

foreach ($g in $Groups) {
    New-ADGroup `
        -Name          $g.Name `
        -SamAccountName $g.Name `
        -GroupScope    $g.Scope `
        -GroupCategory "Security" `
        -Path          $GroupOU `
        -Description   $g.Desc
    Write-Host "[+] Created group: $($g.Name)" -ForegroundColor Cyan
}

Write-Host "`n[+] All security groups created." -ForegroundColor Green
```

### Assign Users to Groups

```powershell
# Add a user to a role group
Add-ADGroupMember -Identity "GRP-IT-Staff" -Members "john.smith"

# Nest a Global group into a Domain Local group (AGDLP)
Add-ADGroupMember -Identity "DL-FileShare-IT-RW" -Members "GRP-IT-Staff"

# Add admin account to Tier1 admin group
Add-ADGroupMember -Identity "GRP-AdminTier1" -Members "a1-john.smith"

# Verify membership
Get-ADGroupMember -Identity "GRP-IT-Staff" | Select-Object Name, SamAccountName, ObjectClass
```

---

## 5. Password Policy & Fine-Grained PSOs

### Domain Default Password Policy

The Default Domain Policy applies to all accounts unless overridden by a Fine-Grained Password Policy (PSO). Configure it to meet modern standards:

**Set via Group Policy:**
`Default Domain Policy → Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies → Password Policy`

| Setting | Recommended Value | Rationale |
|---|---|---|
| Minimum password length | 14 characters | NIST SP 800-63B guidance |
| Password complexity | Enabled | Mixed character classes |
| Maximum password age | 90 days (or 0 for MFA environments) | NIST recommends no expiry if MFA present |
| Minimum password age | 1 day | Prevent rapid cycling |
| Enforce password history | 24 passwords | Prevent reuse |
| Store passwords reversibly | Disabled | Never enable |

```powershell
# Verify current domain password policy
Get-ADDefaultDomainPasswordPolicy
```

### Fine-Grained Password Policies (PSOs)

PSOs override the domain default for specific users or groups. Requires **Domain Functional Level 2008 or higher**.

**Strategy:**

| PSO Name | Applies To | Min Length | Max Age | Complexity | Lockout |
|---|---|---|---|---|---|
| `PSO-Privileged-Admins` | GRP-AdminTier0, GRP-AdminTier1 | 20 chars | 60 days | Enabled | 3 attempts / 30 min |
| `PSO-Standard-Users` | GRP-IT-Staff, GRP-Finance-Staff | 14 chars | 90 days | Enabled | 5 attempts / 15 min |
| `PSO-Contractors` | GRP-Contractors | 14 chars | 30 days | Enabled | 3 attempts / 15 min |
| `PSO-Service-Accounts` | svc-* accounts | 25 chars | 0 (never) | Enabled | N/A |

```powershell
# --- Create-PSOs.ps1 ---

# PSO for Privileged Admins
New-ADFineGrainedPasswordPolicy `
    -Name                       "PSO-Privileged-Admins" `
    -DisplayName                "Privileged Admin Accounts Password Policy" `
    -Precedence                 10 `
    -MinPasswordLength          20 `
    -PasswordHistoryCount       24 `
    -MaxPasswordAge             "60.00:00:00" `
    -MinPasswordAge             "1.00:00:00" `
    -ComplexityEnabled          $true `
    -ReversibleEncryptionEnabled $false `
    -LockoutThreshold           3 `
    -LockoutObservationWindow   "00:30:00" `
    -LockoutDuration            "00:30:00"

# Apply PSO to Admin groups
Add-ADFineGrainedPasswordPolicySubject `
    -Identity "PSO-Privileged-Admins" `
    -Subjects "GRP-AdminTier0", "GRP-AdminTier1"

# PSO for Standard Users
New-ADFineGrainedPasswordPolicy `
    -Name                       "PSO-Standard-Users" `
    -DisplayName                "Standard User Password Policy" `
    -Precedence                 20 `
    -MinPasswordLength          14 `
    -PasswordHistoryCount       24 `
    -MaxPasswordAge             "90.00:00:00" `
    -MinPasswordAge             "1.00:00:00" `
    -ComplexityEnabled          $true `
    -ReversibleEncryptionEnabled $false `
    -LockoutThreshold           5 `
    -LockoutObservationWindow   "00:15:00" `
    -LockoutDuration            "00:15:00"

Add-ADFineGrainedPasswordPolicySubject `
    -Identity "PSO-Standard-Users" `
    -Subjects "GRP-IT-Staff", "GRP-Finance-Staff", "GRP-HR-Staff"

# PSO for Contractors
New-ADFineGrainedPasswordPolicy `
    -Name                       "PSO-Contractors" `
    -DisplayName                "Contractor Password Policy" `
    -Precedence                 30 `
    -MinPasswordLength          14 `
    -PasswordHistoryCount       12 `
    -MaxPasswordAge             "30.00:00:00" `
    -MinPasswordAge             "1.00:00:00" `
    -ComplexityEnabled          $true `
    -ReversibleEncryptionEnabled $false `
    -LockoutThreshold           3 `
    -LockoutObservationWindow   "00:15:00" `
    -LockoutDuration            "00:15:00"

Add-ADFineGrainedPasswordPolicySubject `
    -Identity "PSO-Contractors" `
    -Subjects "GRP-Contractors"

Write-Host "[+] Fine-Grained Password Policies created and applied." -ForegroundColor Green
```

### Verify PSO Application

```powershell
# Check which PSO applies to a user
Get-ADUserResultantPasswordPolicy -Identity "john.smith"

# List all PSOs and their subjects
Get-ADFineGrainedPasswordPolicy -Filter * | ForEach-Object {
    $pso = $_
    $subjects = Get-ADFineGrainedPasswordPolicySubject -Identity $pso.Name
    [PSCustomObject]@{
        PSO       = $pso.Name
        Precedence= $pso.Precedence
        MinLength = $pso.MinPasswordLength
        MaxAge    = $pso.MaxPasswordAge
        Subjects  = ($subjects.Name -join ", ")
    }
} | Format-Table -AutoSize
```

---

## 6. User Account Hardening

### Logon Restrictions

Apply the following hardening to all accounts based on their type.

#### Restrict Admin Account Logon Hours

Admin accounts should only be usable during business hours unless explicitly required:

```powershell
# Set logon hours: Mon-Fri 07:00-19:00 only
# Hours are represented as a 168-bit array (24 bits per day, 7 days)
# Easiest via GUI: ADUC → User Properties → Account → Logon Hours

# PowerShell approach (set all hours, then restrict):
$User = "a1-john.smith"
$Hours = New-Object byte[] 21   # 21 bytes = 168 bits

# Set business hours Mon-Fri (this is complex byte manipulation — recommend GUI for initial lab)
# Reference: each byte covers 8 hours in UTC — adjust for your timezone offset

Set-ADUser -Identity $User -Replace @{logonHours = $Hours}
```

#### Account Expiry for Contractors

```powershell
# Set account expiry 90 days from today for contractor accounts
$Expiry = (Get-Date).AddDays(90)
Set-ADUser -Identity "c-jane.doe" -AccountExpirationDate $Expiry

# Verify
Get-ADUser -Identity "c-jane.doe" -Properties AccountExpirationDate |
    Select-Object SamAccountName, AccountExpirationDate
```

#### Require Smart Card Logon (Tier 0 Accounts)

```powershell
# Enforce smart card requirement on Tier 0 admin accounts
Get-ADUser -Filter { SamAccountName -like "a0-*" } | ForEach-Object {
    Set-ADUser -Identity $_ -SmartcardLogonRequired $true
    Write-Host "[+] SmartCardRequired set on $($_.SamAccountName)"
}
```

#### Disable Kerberos Pre-Authentication (Detection Lab Note)

> **Lab Note:** In a purple team / detection lab, you may intentionally leave some accounts with pre-auth disabled (`DONT_REQUIRE_PREAUTH`) to simulate AS-REP Roasting targets. This should NEVER be done in production.

```powershell
# FOR LAB / DETECTION PURPOSES ONLY — creates AS-REP Roasting target
$VulnUser = "c-jane.doe"
Set-ADAccountControl -Identity $VulnUser -DoesNotRequirePreAuth $true
# Event ID 4768 will appear without pre-auth data (etype 0x17/0x18 vs RC4)
```

### Tiered Administration — Logon Restriction Enforcement

The critical security control for the tiered admin model is preventing admins from using high-privilege accounts on low-trust systems. Enforce this via GPO (covered in Section 7), but also via `Deny log on locally` and `Deny log on through Remote Desktop Services` User Rights Assignments.

| Tier | Can Log Into | Cannot Log Into |
|---|---|---|
| Tier 0 (`a0-`) | Domain Controllers only | Servers, Workstations |
| Tier 1 (`a1-`) | Member Servers | DCs, Workstations |
| Tier 2 (`a2-`) | Workstations | DCs, Servers |

---

## 7. Group Policy for User Environment

### Baseline User GPOs

Link the following GPOs to the `OU=Users` subtree. Use separate GPOs per function for granular management.

#### GPO 1 — User Security Baseline

```
GPO Name: CORP-User-Security-Baseline
Linked To: OU=_CORP,DC=corp,DC=lab (filtered to Users OU)
```

Key settings:

```
Computer Configuration → Policies → Windows Settings → Security Settings → 
  Local Policies → User Rights Assignment:
    - Deny log on locally:                 (leave empty — configured per-tier)
    - Allow log on locally:                 (Authenticated Users by default)

User Configuration → Policies → Administrative Templates:
  Windows Components → Windows PowerShell:
    - Turn on Script Execution: Enabled → "Allow only signed scripts" (adjust for lab)
  
  Control Panel:
    - Prohibit access to Control Panel and PC settings: Not Configured (enable for kiosk scenarios)

  System:
    - Prevent access to registry editing tools: Enabled (for standard users)
    - Prevent access to the command prompt: Enabled (for standard users — disable for IT)
```

#### GPO 2 — Admin Tier Lockdown (Tier 0)

```
GPO Name: CORP-AdminTier0-Lockdown
Linked To: OU=Tier0,OU=Admin Accounts,OU=_CORP,DC=corp,DC=lab
```

```
User Configuration → Policies → Administrative Templates:
  Windows Components → Internet Explorer:
    - Prevent Internet Explorer from running: Enabled
  
  Windows Components → Microsoft Edge:
    - Allow Microsoft Edge to start: Disabled
  
  Start Menu and Taskbar:
    - Remove and prevent access to the Shut Down, Restart, Sleep: Not Configured
```

```
Computer Configuration (applied to DCs) → Windows Settings → Security Settings →
  Local Policies → User Rights Assignment:
    - Deny log on locally:                 Add GRP-AdminTier1, GRP-AdminTier2
    - Deny log on through RDS:             Add GRP-AdminTier1, GRP-AdminTier2
    - Deny access to this computer from network: Add GRP-AdminTier1, GRP-AdminTier2
```

#### GPO 3 — Logon Banner

```
GPO Name: CORP-LogonBanner
Linked To: OU=_CORP,DC=corp,DC=lab
```

```powershell
# Apply interactively — or set via GPO:
# Computer Configuration → Windows Settings → Security Settings →
#   Local Policies → Security Options:
#     - Interactive logon: Message title for users attempting to log on
#     - Interactive logon: Message text for users attempting to log on

$BannerTitle = "AUTHORIZED ACCESS ONLY"
$BannerText  = "This system is for authorized users only. All activity is monitored and logged. Unauthorized access is prohibited and may be subject to criminal prosecution."

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name "legalnoticecaption" -Value $BannerTitle

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name "legalnoticetext" -Value $BannerText
```

### Force GPO Update

```powershell
# Force immediate GPO update on all domain computers (requires WinRM)
Invoke-GPUpdate -Computer "WORKSTATION01" -Force -RandomDelayInMinutes 0

# Or broadcast update to all computers in an OU
Get-ADComputer -SearchBase "OU=Workstations,OU=Computers,OU=_CORP,DC=corp,DC=lab" -Filter * |
    ForEach-Object { Invoke-GPUpdate -Computer $_.Name -Force -RandomDelayInMinutes 0 }

# Verify GPO application
gpresult /r /scope user
```

---

## 8. Bulk Provisioning with PowerShell

### CSV-Based User Import

For lab scenarios requiring multiple users, use a CSV-driven provisioning script. This is the professional approach for real onboarding pipelines.

#### Sample CSV: `users.csv`

```csv
FirstName,LastName,Department,Title,Manager,Type,OUPath
Alice,Walker,IT Operations,Network Engineer,john.smith,Employee,OU=Employees,OU=Users,OU=_CORP,DC=corp,DC=lab
Bob,Chen,Finance,Financial Analyst,jane.doe,Employee,OU=Employees,OU=Users,OU=_CORP,DC=corp,DC=lab
Carol,Martinez,HR,HR Business Partner,jane.doe,Employee,OU=Employees,OU=Users,OU=_CORP,DC=corp,DC=lab
Dave,O'Brien,External,Contractor,john.smith,Contractor,OU=Contractors,OU=Users,OU=_CORP,DC=corp,DC=lab
```

#### Bulk Import Script

```powershell
# --- Import-ADUsersFromCSV.ps1 ---

param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [string]$DefaultPassword = $null,   # Leave null to prompt per user

    [switch]$WhatIf                     # Dry-run mode
)

Import-Module ActiveDirectory

$Users = Import-Csv -Path $CsvPath
$Results = @()

foreach ($User in $Users) {

    $Prefix     = if ($User.Type -eq "Contractor") { "c-" } else { "" }
    $SamAccount = "$Prefix$($User.FirstName.ToLower()).$($User.LastName.ToLower())"
    $UPN        = "$SamAccount@corp.lab"
    $DisplayName= "$($User.FirstName) $($User.LastName)"
    $Expiry     = if ($User.Type -eq "Contractor") { (Get-Date).AddDays(90) } else { $null }

    # Check for existing account
    $Exists = Get-ADUser -Filter { SamAccountName -eq $SamAccount } -ErrorAction SilentlyContinue
    if ($Exists) {
        Write-Warning "User $SamAccount already exists — skipping."
        $Results += [PSCustomObject]@{ User=$SamAccount; Status="Skipped (exists)"; Error="" }
        continue
    }

    # Resolve manager
    $ManagerObj = $null
    if ($User.Manager) {
        $ManagerObj = Get-ADUser -Filter { SamAccountName -eq $User.Manager } -ErrorAction SilentlyContinue
        if (-not $ManagerObj) { Write-Warning "Manager '$($User.Manager)' not found — skipping manager field." }
    }

    # Set password
    if ($DefaultPassword) {
        $SecurePass = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
    } else {
        $SecurePass = Read-Host "Password for $SamAccount" -AsSecureString
    }

    $Params = @{
        SamAccountName      = $SamAccount
        UserPrincipalName   = $UPN
        Name                = $DisplayName
        GivenName           = $User.FirstName
        Surname             = $User.LastName
        DisplayName         = $DisplayName
        Department          = $User.Department
        Title               = $User.Title
        Path                = $User.OUPath
        AccountPassword     = $SecurePass
        ChangePasswordAtLogon = $true
        Enabled             = $true
        PasswordNeverExpires = $false
        Description         = "$($User.Type) account - provisioned $(Get-Date -Format 'yyyy-MM-dd')"
    }

    if ($ManagerObj)  { $Params.Manager               = $ManagerObj }
    if ($Expiry)      { $Params.AccountExpirationDate  = $Expiry }

    try {
        if ($WhatIf) {
            Write-Host "[WHATIF] Would create: $SamAccount in $($User.OUPath)" -ForegroundColor Yellow
        } else {
            New-ADUser @Params
            Write-Host "[+] Created: $SamAccount" -ForegroundColor Green
        }
        $Results += [PSCustomObject]@{ User=$SamAccount; Status="Created"; Error="" }
    } catch {
        Write-Warning "Failed to create $SamAccount : $_"
        $Results += [PSCustomObject]@{ User=$SamAccount; Status="Failed"; Error=$_.Exception.Message }
    }
}

# Output summary
Write-Host "`n--- Provisioning Summary ---" -ForegroundColor Cyan
$Results | Format-Table -AutoSize

# Export results log
$LogPath = ".\provisioning-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$Results | Export-Csv -Path $LogPath -NoTypeInformation
Write-Host "[+] Results logged to $LogPath" -ForegroundColor Green
```

### Usage

```powershell
# Dry-run (no changes made)
.\Import-ADUsersFromCSV.ps1 -CsvPath .\users.csv -WhatIf

# Execute with a default initial password
.\Import-ADUsersFromCSV.ps1 -CsvPath .\users.csv -DefaultPassword "LabPass!2024"
```

---

## 9. Account Lifecycle Management

### Onboarding Workflow

```
1. Manager submits onboarding request (ticket/form)
2. HR validates: employee ID, start date, department
3. IT creates AD account (this lab's script)
4. IT adds to appropriate security groups
5. IT sends welcome email with temporary password (expires at first logon)
6. Helpdesk verifies account works on day 1
7. Manager grants resource access (shares, applications)
```

### Offboarding Workflow

```powershell
# --- Offboard-ADUser.ps1 ---
# Professional offboarding: disable, move, strip groups, document

param(
    [Parameter(Mandatory)]
    [string]$SamAccountName,

    [string]$OffboardingOU = "OU=_STAGING,DC=corp,DC=lab",
    [string]$TicketRef      = "TICKET-0000"
)

Import-Module ActiveDirectory

$User = Get-ADUser -Identity $SamAccountName -Properties MemberOf, Description, Manager
if (-not $User) { Write-Error "User $SamAccountName not found."; exit 1 }

Write-Host "[*] Beginning offboarding for $SamAccountName ($TicketRef)" -ForegroundColor Yellow

# 1. Disable the account
Disable-ADAccount -Identity $SamAccountName
Write-Host "[+] Account disabled."

# 2. Set description with offboard date and ticket
$NewDesc = "OFFBOARDED $(Get-Date -Format 'yyyy-MM-dd') | Ref: $TicketRef | Was: $($User.Description)"
Set-ADUser -Identity $SamAccountName -Description $NewDesc
Write-Host "[+] Description updated."

# 3. Strip all group memberships (except Domain Users — cannot be removed)
$Groups = $User.MemberOf
foreach ($Group in $Groups) {
    Remove-ADGroupMember -Identity $Group -Members $SamAccountName -Confirm:$false
    Write-Host "[+] Removed from: $((Get-ADGroup $Group).Name)"
}

# 4. Clear manager reference
Set-ADUser -Identity $SamAccountName -Clear Manager
Write-Host "[+] Manager reference cleared."

# 5. Move account to _STAGING OU (do NOT delete immediately — preserve for audit)
Move-ADObject -Identity $User.DistinguishedName -TargetPath $OffboardingOU
Write-Host "[+] Account moved to $OffboardingOU."

# 6. Set account expiry to now (belt-and-suspenders)
Set-ADUser -Identity $SamAccountName -AccountExpirationDate (Get-Date)
Write-Host "[+] Account expiry set to now."

Write-Host "`n[COMPLETE] Offboarding complete for $SamAccountName" -ForegroundColor Green
Write-Host "Account retained in $OffboardingOU for 90-day audit hold." -ForegroundColor Cyan
```

### Dormant Account Detection

```powershell
# --- Find-DormantAccounts.ps1 ---
# Find accounts that haven't logged in for 60+ days

$DaysInactive = 60
$Cutoff = (Get-Date).AddDays(-$DaysInactive)

Get-ADUser -Filter {
    Enabled -eq $true -and
    LastLogonDate -lt $Cutoff -and
    LastLogonDate -ne $null
} -Properties LastLogonDate, Description, Department, Manager |
Select-Object SamAccountName, DisplayName, Department, LastLogonDate, Description |
Sort-Object LastLogonDate |
Format-Table -AutoSize

# Export for review
Get-ADUser -Filter {
    Enabled -eq $true -and
    LastLogonDate -lt $Cutoff
} -Properties LastLogonDate, Department, Manager |
Export-Csv -Path ".\dormant-accounts-$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
```

### Account Expiry Review

```powershell
# Find accounts expiring in the next 14 days
$Soon = (Get-Date).AddDays(14)

Get-ADUser -Filter {
    AccountExpirationDate -lt $Soon -and
    AccountExpirationDate -ne $null -and
    Enabled -eq $true
} -Properties AccountExpirationDate, Department |
Select-Object SamAccountName, DisplayName, Department, AccountExpirationDate |
Sort-Object AccountExpirationDate
```

---

## 10. Audit & Monitoring

### Advanced Audit Policy Configuration

Configure via GPO or `auditpol.exe` to generate the Security event IDs critical for user monitoring.

```
GPO: Default Domain Controllers Policy (or a dedicated Audit GPO)
Computer Configuration → Policies → Windows Settings → Security Settings →
  Advanced Audit Policy Configuration → Audit Policies:
```

| Category | Subcategory | Setting |
|---|---|---|
| Account Logon | Credential Validation | Success, Failure |
| Account Logon | Kerberos Authentication Service | Success, Failure |
| Account Management | User Account Management | Success, Failure |
| Account Management | Security Group Management | Success, Failure |
| Account Management | Computer Account Management | Success |
| DS Access | Directory Service Changes | Success |
| DS Access | Directory Service Access | Failure |
| Logon/Logoff | Logon | Success, Failure |
| Logon/Logoff | Special Logon | Success |
| Policy Change | Audit Policy Change | Success |
| Privilege Use | Sensitive Privilege Use | Success, Failure |

```powershell
# Apply via auditpol (run on DC)
auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable
auditpol /set /subcategory:"Security Group Management" /success:enable /failure:enable
auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable
auditpol /set /subcategory:"Kerberos Authentication Service" /success:enable /failure:enable
auditpol /set /subcategory:"Directory Service Changes" /success:enable /failure:enable
auditpol /set /subcategory:"Logon" /success:enable /failure:enable
auditpol /set /subcategory:"Special Logon" /success:enable

# Verify
auditpol /get /category:*
```

### Key Event IDs for User Management

| Event ID | Description | Detection Value |
|---|---|---|
| 4720 | User account created | Unauthorized provisioning |
| 4722 | User account enabled | Re-enabling dormant accounts |
| 4723 | Password change attempt | Self-service changes |
| 4724 | Password reset attempt | Admin resets (helpdesk) |
| 4725 | User account disabled | Offboarding, lockouts |
| 4726 | User account deleted | Account deletion |
| 4728 | Member added to global group | Privilege escalation path |
| 4732 | Member added to local group | Local privilege escalation |
| 4756 | Member added to universal group | Forest-wide privilege |
| 4740 | Account locked out | Brute force, spray |
| 4767 | Account unlocked | Helpdesk activity |
| 4768 | Kerberos TGT request | Authentication baseline |
| 4769 | Kerberos service ticket request | Service access (Kerberoasting when RC4) |
| 4771 | Kerberos pre-auth failure | Spray / enumeration |
| 4776 | NTLM auth attempt | NTLM use (should be rare) |
| 4662 | Object operation (DS) | DCSync attack detection |

### Splunk SPL — User Account Changes Dashboard Panel

```spl
index=wineventlog sourcetype=XmlWinEventLog:Security
EventCode IN (4720, 4722, 4723, 4724, 4725, 4726, 4728, 4732, 4756, 4740, 4767)
| eval EventType = case(
    EventCode="4720", "Account Created",
    EventCode="4722", "Account Enabled",
    EventCode="4723", "Password Changed (Self)",
    EventCode="4724", "Password Reset (Admin)",
    EventCode="4725", "Account Disabled",
    EventCode="4726", "Account Deleted",
    EventCode="4728", "Added to Global Group",
    EventCode="4732", "Added to Local Group",
    EventCode="4756", "Added to Universal Group",
    EventCode="4740", "Account Locked Out",
    EventCode="4767", "Account Unlocked",
    true(), "Unknown"
)
| eval Actor = coalesce(SubjectUserName, "N/A")
| eval Target = coalesce(TargetUserName, "N/A")
| table _time, EventCode, EventType, Actor, Target, ComputerName
| sort -_time
```

### Splunk SPL — Detect Account Provisioning Outside Business Hours

```spl
index=wineventlog sourcetype=XmlWinEventLog:Security EventCode=4720
| eval hour = strftime(_time, "%H")
| eval day_of_week = strftime(_time, "%u")
| where hour < 7 OR hour > 19 OR day_of_week IN ("6","7")
| eval Actor = SubjectUserName
| eval NewAccount = TargetUserName
| table _time, Actor, NewAccount, ComputerName
| sort -_time
```

---

## 11. Verification Checklist

Use this checklist to confirm the lab is correctly configured after completing all steps.

### OU Structure

```powershell
# Run this verification block
$ExpectedOUs = @(
    "OU=_CORP,DC=corp,DC=lab",
    "OU=Users,OU=_CORP,DC=corp,DC=lab",
    "OU=Employees,OU=Users,OU=_CORP,DC=corp,DC=lab",
    "OU=Contractors,OU=Users,OU=_CORP,DC=corp,DC=lab",
    "OU=Executives,OU=Users,OU=_CORP,DC=corp,DC=lab",
    "OU=Service Accounts,OU=_CORP,DC=corp,DC=lab",
    "OU=Admin Accounts,OU=_CORP,DC=corp,DC=lab",
    "OU=Tier0,OU=Admin Accounts,OU=_CORP,DC=corp,DC=lab",
    "OU=Tier1,OU=Admin Accounts,OU=_CORP,DC=corp,DC=lab",
    "OU=Tier2,OU=Admin Accounts,OU=_CORP,DC=corp,DC=lab"
)

foreach ($OU in $ExpectedOUs) {
    $Exists = Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $OU } -ErrorAction SilentlyContinue
    if ($Exists) {
        Write-Host "[PASS] $OU" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $OU MISSING" -ForegroundColor Red
    }
}
```

### Security Groups

```powershell
$ExpectedGroups = @(
    "GRP-IT-Staff","GRP-Finance-Staff","GRP-HR-Staff","GRP-Executives",
    "GRP-Contractors","DL-FileShare-IT-RW","DL-FileShare-HR-RO","DL-VPN-Users",
    "GRP-AdminTier0","GRP-AdminTier1","GRP-AdminTier2"
)

foreach ($Group in $ExpectedGroups) {
    $Exists = Get-ADGroup -Filter { SamAccountName -eq $Group } -ErrorAction SilentlyContinue
    if ($Exists) {
        Write-Host "[PASS] $Group" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Group MISSING" -ForegroundColor Red
    }
}
```

### PSO Verification

```powershell
$PSOs = @("PSO-Privileged-Admins","PSO-Standard-Users","PSO-Contractors")

foreach ($PSO in $PSOs) {
    $Exists = Get-ADFineGrainedPasswordPolicy -Filter { Name -eq $PSO } -ErrorAction SilentlyContinue
    if ($Exists) {
        $Subjects = (Get-ADFineGrainedPasswordPolicySubject -Identity $PSO).Name -join ", "
        Write-Host "[PASS] $PSO — Subjects: $Subjects" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $PSO MISSING" -ForegroundColor Red
    }
}
```

### Audit Policy

```powershell
# Quick check — User Account Management should show Success and Failure
auditpol /get /subcategory:"User Account Management"
auditpol /get /subcategory:"Security Group Management"
auditpol /get /subcategory:"Credential Validation"
```

---

## 12. Reference Tables

### gMSA Quick Setup (Production Best Practice for Service Accounts)

```powershell
# 1. Create KDS Root Key (one-time per forest — wait 10 hours in production, use -EffectiveImmediately in lab)
Add-KdsRootKey -EffectiveImmediately

# 2. Create the gMSA
New-ADServiceAccount `
    -Name                   "gmsa-sqlreport" `
    -DNSHostName            "gmsa-sqlreport.corp.lab" `
    -PrincipalsAllowedToRetrieveManagedPassword "SRV-SQL01$"  # Computer accounts allowed to use it

# 3. Install on target server
Install-ADServiceAccount -Identity "gmsa-sqlreport"

# 4. Verify
Test-ADServiceAccount -Identity "gmsa-sqlreport"
```

### Attribute Quick Reference

| Attribute | LDAP Name | PowerShell Property |
|---|---|---|
| Username | `sAMAccountName` | `SamAccountName` |
| UPN | `userPrincipalName` | `UserPrincipalName` |
| Display Name | `displayName` | `DisplayName` |
| Department | `department` | `Department` |
| Job Title | `title` | `Title` |
| Manager | `manager` | `Manager` |
| Email | `mail` | `EmailAddress` |
| Account Expires | `accountExpires` | `AccountExpirationDate` |
| Last Logon | `lastLogonTimestamp` | `LastLogonDate` |
| Password Last Set | `pwdLastSet` | `PasswordLastSet` |
| Locked Out | `lockoutTime` | `LockedOut` |

### UserAccountControl Flags

| Flag | Decimal | Meaning |
|---|---|---|
| `NORMAL_ACCOUNT` | 512 | Standard enabled account |
| `ACCOUNTDISABLE` | 2 | Account is disabled |
| `PASSWD_NOTREQD` | 32 | No password required (avoid) |
| `DONT_EXPIRE_PASSWORD` | 65536 | Password never expires |
| `SMARTCARD_REQUIRED` | 262144 | Smart card required to log on |
| `DONT_REQ_PREAUTH` | 4194304 | Kerberos pre-auth not required (AS-REP Roasting target) |

```powershell
# Check UserAccountControl flags
Get-ADUser -Identity "john.smith" -Properties UserAccountControl |
    Select-Object SamAccountName, UserAccountControl
```

### Common AD PowerShell One-Liners

```powershell
# List all users in an OU
Get-ADUser -SearchBase "OU=Employees,OU=Users,OU=_CORP,DC=corp,DC=lab" -Filter * |
    Select-Object Name, SamAccountName, Enabled | Sort-Object Name

# Find all disabled accounts
Get-ADUser -Filter { Enabled -eq $false } -Properties LastLogonDate |
    Select-Object SamAccountName, LastLogonDate | Sort-Object LastLogonDate

# Find accounts with passwords that never expire
Get-ADUser -Filter { PasswordNeverExpires -eq $true -and Enabled -eq $true } |
    Select-Object SamAccountName, DistinguishedName

# Find accounts not in any custom group (only Domain Users)
Get-ADUser -Filter * -Properties MemberOf |
    Where-Object { $_.MemberOf.Count -eq 0 } |
    Select-Object SamAccountName, DistinguishedName

# Unlock all locked accounts
Search-ADAccount -LockedOut | Unlock-ADAccount -PassThru |
    Select-Object SamAccountName, LockedOut

# Export all users with key attributes to CSV
Get-ADUser -Filter * -SearchBase "OU=_CORP,DC=corp,DC=lab" `
    -Properties DisplayName, Department, Title, LastLogonDate, PasswordLastSet, Enabled |
    Select-Object SamAccountName, DisplayName, Department, Title, LastLogonDate, PasswordLastSet, Enabled |
    Export-Csv -Path ".\ad-user-export-$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
```

---

*Document generated for `corp.lab` home security lab. Review and adapt all security settings before applying to any production environment.*
