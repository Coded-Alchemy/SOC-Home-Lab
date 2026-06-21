# Deploying Group Policies in an Active Directory Lab

## Overview

This guide documents how to deploy and manage Group Policy Objects (GPOs) in a Windows Active Directory lab environment using:

- Windows Server Domain Controller
- Windows 10/11 endpoints
- Domain: `lab.local`
- Splunk Universal Forwarder installed
- Sysmon deployed for telemetry collection

This documentation is designed for home lab environments focused on:

- Security engineering
- SOC operations
- Endpoint hardening
- Windows administration
- Detection engineering
- Enterprise policy management

---

# Lab Architecture

## Environment Components

| System | Role |
|---|---|
| Windows Server | Domain Controller |
| Windows 10 | Domain-joined endpoint |
| Windows 11 | Domain-joined endpoint |
| Active Directory | Centralized authentication |
| DNS | Name resolution |
| Sysmon | Endpoint telemetry |
| Splunk UF | Log forwarding |
| Group Policy | Centralized configuration management |

---

# What Group Policy Does

Group Policy allows administrators to centrally configure:

- Security settings
- Password policies
- Firewall rules
- Software deployment
- Logging configuration
- Windows Defender settings
- PowerShell restrictions
- User restrictions
- Login scripts
- Scheduled tasks

In enterprise environments, GPOs are critical for:

- Standardization
- Compliance
- Security hardening
- Detection visibility
- Endpoint control

---

# Prerequisites

Before deploying GPOs:

## Active Directory Requirements

Ensure:

- Domain Controller is operational
- DNS is functioning correctly
- Clients are joined to `lab.local`
- Time synchronization works properly

Verify with:

```powershell
whoami
hostname
echo %logonserver%
```

Expected:

```powershell
LAB\username
\\DC01
```

---

# Installing Group Policy Management

On the Domain Controller:

## Open Server Manager

Navigate:

```text
Server Manager -> Manage → Add Roles and Features
```

Ensure the following is installed:

```text
Group Policy Management
```

Usually installed automatically with AD DS.

---

# Opening Group Policy Management

Launch:

```powershell
gpmc.msc
```

Or:

```text
Server Manager → Tools → Group Policy Management
```

---

# Understanding GPO Structure

## Core Components

| Component | Purpose |
|---|---|
| Forest | Top-level AD structure |
| Domain | Administrative boundary |
| Organizational Unit (OU) | Logical grouping |
| GPO | Configuration policy |
| Security Filtering | Limits policy scope |
| WMI Filters | Advanced targeting |

---

# Recommended OU Structure

Create a clean OU hierarchy.

## Example

```text
lab.local
│
├── Workstations
│   ├── Windows10
│   └── Windows11
│
├── Servers
│
├── Users
│
└── Security
```

---

# Creating Organizational Units

## In Active Directory Users and Computers

Launch:

```powershell
dsa.msc
```

### Create OUs

Right-click domain:

```text
New → Organizational Unit
```

Create:

- Workstations
- Servers
- Users
- Security

---

# Moving Computers Into OUs

Move machines from:

```text
Computers
```

Into:

```text
Workstations
```

### Why This Matters

GPOs apply based on:

- OU placement
- Security filtering
- Inheritance

If systems remain in the default `Computers` container, policies often fail to apply properly.

---

# Creating Your First GPO

## Open Group Policy Management

Navigate:

```text
Forest → Domains → lab.local
```

Right-click:

```text
Group Policy Objects
```

Select:

```text
New
```

Example name:

```text
Workstation Baseline Policy
```

---

# Linking a GPO

After creation:

Right-click the target OU:

```text
Link an Existing GPO
```

Choose:

```text
Workstation Baseline Policy
```

---

# Editing a GPO

Right-click the policy:

```text
Edit
```

You now access:

```text
Computer Configuration
User Configuration
```

---

# Recommended Lab Policies

# 1. Password Policy

## Path

```text
Computer Configuration
→ Policies
→ Windows Settings
→ Security Settings
→ Account Policies
→ Password Policy
```

## Recommended Settings

| Setting | Value |
|---|---|
| Minimum Password Length | 12 |
| Complexity Requirements | Enabled |
| Maximum Password Age | 90 days |
| Password History | 24 passwords |

---

# 2. Account Lockout Policy

## Path

```text
Security Settings
→ Account Policies
→ Account Lockout Policy
```

## Recommended

| Setting | Value |
|---|---|
| Lockout Threshold | 5 attempts |
| Lockout Duration | 15 mins |
| Reset Counter | 15 mins |

---

# 3. Windows Defender Configuration

## Path

```text
Computer Configuration
→ Administrative Templates
→ Windows Components
→ Microsoft Defender Antivirus
```

## Recommended Settings

Enable:

- Real-time protection
- Cloud-delivered protection
- Behavior monitoring
- Network protection

---

# 4. PowerShell Logging

Critical for SOC visibility.

## Path

```text
Computer Configuration
→ Policies
→ Administrative Templates
→ Windows Components
→ Windows PowerShell
```

Enable:

| Setting | Value |
|---|---|
| Turn on PowerShell Script Block Logging | Enabled |
| Turn on Module Logging | Enabled |
| Turn on PowerShell Transcription | Enabled |

---

# 5. Windows Firewall Policy

## Path

```text
Computer Configuration
→ Policies
→ Windows Settings
→ Security Settings
→ Windows Defender Firewall
```

Recommended:

- Firewall enabled for all profiles
- Log dropped packets
- Log successful connections

---

# 6. Sysmon Deployment GPO

You can deploy Sysmon centrally.

## Option 1 — Startup Script

### Create Shared Folder

Example:

```text
\\DC01\Deploy
```

Place:

- Sysmon64.exe
- sysmonconfig.xml

---

## Create Startup Script

Example:

```powershell
@echo off

\\DC01\Deploy\Sysmon64.exe -accepteula -i \\DC01\Deploy\sysmonconfig.xml
```

Save as:

```text
install_sysmon.bat
```

---

## Configure Startup Script

Path:

```text
Computer Configuration
→ Policies
→ Windows Settings
→ Scripts
→ Startup
```

Add script.

---

# 7. Splunk Universal Forwarder Deployment

## Deploy via Startup Script

Example installer command:

```powershell
msiexec.exe /i splunkforwarder.msi AGREETOLICENSE=Yes RECEIVING_INDEXER=splunk.lab.local:9997 DEPLOYMENT_SERVER=splunk.lab.local:8089 /quiet
```

---

# 8. Enable Advanced Audit Policies

Critical for detection engineering.

## Path

```text
Computer Configuration
→ Policies
→ Windows Settings
→ Security Settings
→ Advanced Audit Policy Configuration
```

Enable:

| Policy | Recommendation |
|---|---|
| Logon Events | Success/Failure |
| Process Creation | Success |
| Account Management | Success/Failure |
| Object Access | Success |
| Policy Change | Success |
| Privilege Use | Success/Failure |

---

# Force Group Policy Updates

## On Client Machines

Run:

```powershell
gpupdate /force
```

Reboot if required.

---

# Verifying GPO Application

## Method 1 — gpresult

Run:

```powershell
gpresult /r
```

Detailed HTML report:

```powershell
gpresult /h report.html
```

---

# Method 2 — Resultant Set of Policy

Launch:

```powershell
rsop.msc
```

Shows effective policies.

---

# Method 3 — Event Viewer

Check:

```text
Applications and Services Logs
→ Microsoft
→ Windows
→ GroupPolicy
→ Operational
```

---

# Common GPO Troubleshooting

# Issue: Policy Not Applying

## Causes

- Incorrect OU placement
- DNS misconfiguration
- Replication issues
- Security filtering
- Firewall issues
- SYSVOL problems

---

# Verify DNS

Client should ONLY use domain controller DNS.

Check:

```powershell
ipconfig /all
```

Expected:

```text
DNS Server = DC IP
```

NOT:

- Google DNS
- Cloudflare DNS
- Router IP

---

# Verify Domain Connectivity

Run:

```powershell
nltest /dsgetdc:lab.local
```

---

# Verify SYSVOL Access

Open:

```text
\\lab.local\SYSVOL
```

If inaccessible:

- DNS likely broken
- SMB blocked
- Netlogon issue

---

# Verify Time Sync

Kerberos breaks if time drift exceeds 5 minutes.

Check:

```powershell
w32tm /query /status
```

---

# Verify GPO Processing

Run:

```powershell
gpupdate /force
```

Then:

```powershell
eventvwr.msc
```

Check:

```text
Applications and Services Logs
→ Microsoft
→ Windows
→ GroupPolicy
```

---

# Security Filtering

By default:

```text
Authenticated Users
```

can apply GPOs.

You can restrict policies to:

- Security groups
- Servers
- Specific workstations

---

# WMI Filtering

Example:

Apply only to Windows 11:

```sql
SELECT * FROM Win32_OperatingSystem WHERE Version LIKE "10.0%" AND ProductType="1"
```

---

# Best Practices

## Recommended Enterprise Approach

### Separate Policies

Do NOT place everything in one GPO.

Use separate GPOs for:

- Firewall
- Logging
- Defender
- Browser security
- PowerShell
- Auditing

---

## Naming Convention

Use consistent naming:

```text
GPO - Workstation Baseline
GPO - PowerShell Logging
GPO - Sysmon Deployment
GPO - Splunk Forwarder
```

---

## Document Every Change

Track:

- Purpose
- Scope
- Linked OUs
- Security filtering
- Expected results

---

## Avoid Editing Default Domain Policy

Use dedicated GPOs whenever possible.

Only keep:

- Password policy
- Kerberos policy

inside:

```text
Default Domain Policy
```

---

# Useful Administrative Commands

## Force Policy Update

```powershell
gpupdate /force
```

## List Applied Policies

```powershell
gpresult /r
```

## Generate HTML Report

```powershell
gpresult /h gpo-report.html
```

## Open Group Policy Management

```powershell
gpmc.msc
```

## Open Resultant Set of Policy

```powershell
rsop.msc
```

## Open Active Directory Users and Computers

```powershell
dsa.msc
```

---

# SOC-Focused GPO Recommendations

For cybersecurity labs, prioritize:

- PowerShell logging
- Sysmon deployment
- Windows event forwarding
- Defender telemetry
- Firewall logging
- Process creation auditing
- Command-line logging

These dramatically improve:

- Splunk visibility
- Detection engineering
- Threat hunting
- Adversary emulation
- MITRE ATT&CK mapping

---

# Final Validation Checklist

| Validation | Status |
|---|---|
| Domain controller operational | □ |
| DNS configured correctly | □ |
| Client joined to domain | □ |
| OUs created | □ |
| GPO linked correctly | □ |
| gpupdate successful | □ |
| gpresult shows applied GPO | □ |
| Sysmon logs visible in Splunk | □ |
| PowerShell logs collected | □ |
| Firewall logging enabled | □ |

---

# Conclusion

Group Policy is one of the most important technologies in Windows enterprise environments. Proper GPO deployment allows centralized control over:

- Security
- Telemetry
- Endpoint configuration
- Detection engineering
- Compliance

In a SOC-focused home lab, mastering GPOs gives you hands-on experience with the same operational workflows used by:

- Security engineers
- System administrators
- Detection engineers
- Enterprise SOC teams
- Blue teams
- Threat hunters

