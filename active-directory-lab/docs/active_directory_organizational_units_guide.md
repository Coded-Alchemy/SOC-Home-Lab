# Creating Organizational Units (OUs) in an Active Directory Lab

## Overview

This document explains how to create and organize Organizational Units (OUs) in an Active Directory lab environment. Proper OU design improves administration, Group Policy management, endpoint organization, and detection engineering workflows.

This guide assumes the following:

- Domain: `lab.local`
- Operating System: Windows Server with Active Directory Domain Services installed
- Administrative access to the Domain Controller
- Windows 10 and Windows 11 endpoints joined to the domain

---

# What Are Organizational Units?

Organizational Units (OUs) are containers within Active Directory used to:

- Organize users, computers, and groups
- Apply Group Policy Objects (GPOs)
- Delegate administrative control
- Simulate enterprise environments
- Separate systems by function or department

OUs are critical in enterprise Active Directory environments because they allow administrators to apply security policies and configurations in a structured way.

---

# Recommended OU Structure for a Home SOC Lab

A structured OU hierarchy makes the environment easier to manage and more realistic for blue team operations.

Example structure:

```text
lab.local
│
├── Servers
│   ├── Domain Controllers
│   ├── Splunk
│   ├── Security Tools
│
├── Workstations
│   ├── Windows10
│   ├── Windows11
│
├── Users
│   ├── Administrators
│   ├── Employees
│   ├── Service Accounts
│
├── Groups
│
├── Lab
│   ├── MalwareAnalysis
│   ├── AdversaryEmulation
│   ├── Testing
```

This structure supports:

- GPO testing
- Security monitoring
- Detection engineering
- Adversary emulation
- Endpoint segmentation

---

# Accessing Active Directory Users and Computers

## Step 1 — Log Into the Domain Controller

Log into the Domain Controller using a domain administrator account.

Example:

```text
lab\Administrator
```

---

## Step 2 — Open Active Directory Users and Computers

Open the management console:

### Method 1

1. Open the Start Menu
2. Search for:

```text
Active Directory Users and Computers
```

3. Launch the application

### Method 2

Use the Run dialog:

```powershell
 dsa.msc
```

---

# Creating Organizational Units

## Step 1 — Expand the Domain

Inside Active Directory Users and Computers:

1. Expand:

```text
lab.local
```

2. Right-click the domain name
3. Select:

```text
New → Organizational Unit
```

---

## Step 2 — Create the OU

Enter the OU name.

Example:

```text
Workstations
```

Optional:

- Leave “Protect container from accidental deletion” enabled

Click:

```text
OK
```

---

## Step 3 — Create Additional OUs

Repeat the process to create additional OUs.

Recommended OUs:

| OU Name | Purpose |
|---|---|
| Servers | Server systems |
| Workstations | User endpoints |
| Users | User accounts |
| Groups | Security groups |
| Security Tools | Splunk, Sysmon, Velociraptor, etc. |
| Testing | Detection and malware testing |
| Adversary Emulation | MITRE Caldera systems |

---

# Creating Nested OUs

Nested OUs help simulate enterprise organizational structures.

Example:

```text
Workstations
├── Windows10
├── Windows11
```

## Steps

1. Right-click the parent OU
2. Select:

```text
New → Organizational Unit
```

3. Enter the child OU name
4. Click:

```text
OK
```

---

# Moving Computers Into OUs

After joining systems to the domain, computers typically appear in the default:

```text
Computers
```

container.

Move them into appropriate OUs.

## Steps

1. Open:

```text
Computers
```

2. Right-click the target computer
3. Select:

```text
Move
```

4. Select the target OU

Example:

```text
Workstations/Windows11
```

5. Click:

```text
OK
```

---

# Moving Users Into OUs

User accounts can also be organized into dedicated OUs.

## Example Structure

```text
Users
├── Administrators
├── Employees
├── Service Accounts
```

## Steps

1. Locate the user account
2. Right-click the user
3. Select:

```text
Move
```

4. Select the target OU
5. Click:

```text
OK
```

---

# Verifying OU Configuration

Verify:

- OUs appear correctly in Active Directory Users and Computers
- Computers are placed in the correct OU
- Users are organized properly
- Nested OU hierarchy is correct

You can also verify OU placement with PowerShell.

Example:

```powershell
Get-ADOrganizationalUnit -Filter *
```

Example:

```powershell
Get-ADComputer -Filter * | Select Name, DistinguishedName
```

---

# Creating OUs with PowerShell

PowerShell is useful for automation and infrastructure-as-code workflows.

## Create a Single OU

```powershell
New-ADOrganizationalUnit \
-Name "Workstations" \
-Path "DC=lab,DC=local"
```

---

## Create Nested OUs

```powershell
New-ADOrganizationalUnit \
-Name "Windows11" \
-Path "OU=Workstations,DC=lab,DC=local"
```

---

## Create Multiple OUs Automatically

```powershell
$OUs = @(
    "Servers",
    "Workstations",
    "Users",
    "Groups",
    "Testing",
    "Security Tools"
)

foreach ($OU in $OUs) {
    New-ADOrganizationalUnit \
    -Name $OU \
    -Path "DC=lab,DC=local"
}
```

---

# Applying Group Policy to OUs

One major advantage of OUs is targeted Group Policy deployment.

Examples:

| OU | Example Policy |
|---|---|
| Workstations | Sysmon deployment |
| Servers | Logging policies |
| Security Tools | Splunk configurations |
| Testing | Relaxed security settings |
| Domain Controllers | Enhanced auditing |

## Opening Group Policy Management

Run:

```powershell
 gpmc.msc
```

---

## Linking a GPO to an OU

1. Open Group Policy Management
2. Locate the target OU
3. Right-click the OU
4. Select:

```text
Link an Existing GPO
```

5. Select the desired GPO
6. Click:

```text
OK
```

---

# Best Practices

## Use Logical Naming

Good:

```text
Windows11
SecurityTools
ServiceAccounts
```

Avoid:

```text
OU1
Stuff
Misc
```

---

## Separate Servers and Workstations

This allows:

- Different GPOs
- Different auditing policies
- Better detection tuning

---

## Create Dedicated Testing OUs

Useful for:

- Malware testing
- MITRE ATT&CK simulations
- Detection engineering
- Unsafe configurations

---

## Protect Critical OUs

Enable:

```text
Protect object from accidental deletion
```

especially for:

- Domain Controllers
- Administrative Users
- Security Tools

---

## Keep the Structure Simple

Overly complex OU structures become difficult to maintain.

Build only what supports:

- Administration
- Security testing
- GPO targeting
- Lab realism

---

# Troubleshooting

## OU Creation Option Missing

Possible causes:

- Insufficient privileges
- ADUC not running as administrator
- Connected to the wrong domain

---

## Cannot Move Computer Object

Possible causes:

- Insufficient permissions
- Replication delays
- Incorrect OU path

---

## PowerShell AD Commands Not Working

Verify the Active Directory module is installed:

```powershell
Get-Module ActiveDirectory -ListAvailable
```

Import the module:

```powershell
Import-Module ActiveDirectory
```

---

## GPO Not Applying

Verify:

- System is inside the correct OU
- GPO is linked properly
- Security filtering allows the system
- Replication completed

Force a Group Policy update:

```powershell
gpupdate /force
```

---

# Example Enterprise-Style OU Layout

```text
lab.local
│
├── Tier0
│   ├── Domain Controllers
│   ├── Admin Accounts
│
├── Servers
│   ├── Infrastructure
│   ├── Splunk
│   ├── SecurityTools
│
├── Endpoints
│   ├── Windows10
│   ├── Windows11
│   ├── Linux
│
├── Users
│   ├── Employees
│   ├── IT
│   ├── Executives
│
├── RedTeam
│
├── BlueTeam
│
├── MalwareAnalysis
│
├── DetectionEngineering
```

This structure closely resembles real enterprise environments and supports:

- SOC workflows
- Threat hunting
- Adversary emulation
- SIEM monitoring
- GPO segmentation
- Security engineering

---

# Conclusion

Organizational Units are a foundational part of Active Directory administration and enterprise security operations.

A well-designed OU structure allows you to:

- Organize systems logically
- Apply targeted Group Policies
- Simulate enterprise infrastructure
- Improve detection engineering workflows
- Separate production-like systems from testing environments

For a home SOC lab, proper OU planning makes the environment significantly easier to manage and more realistic for blue team training and adversary emulation.

