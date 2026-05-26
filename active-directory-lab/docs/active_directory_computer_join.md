# Adding a Computer to Active Directory

## Overview

This guide documents the process of joining a Windows endpoint to an Active Directory domain in a home lab environment.

The environment uses:

- Active Directory Domain Services (AD DS)
- Sysmon for endpoint telemetry
- Splunk Universal Forwarder for centralized log collection
- Windows Server as the Domain Controller

Joining systems to Active Directory enables:

- Centralized authentication
- Group Policy management
- Endpoint administration
- Security monitoring
- Log aggregation and detection engineering workflows

---

# Lab Environment

| Component | Value |
|---|---|
| Domain Name | `lab.local` |
| Domain Controller | Windows Server |
| Client Systems | Windows 10 / Windows 11 |
| Logging Platform | Splunk |
| Endpoint Telemetry | Sysmon |
| Log Forwarding | Splunk Universal Forwarder |

---

# Architecture Overview

```text
+------------------------------------------------+
|                Domain Controller               |
|------------------------------------------------|
| Active Directory                               |
| DNS                                            |
| Kerberos Authentication                        |
+------------------------+-----------------------+
                         |
                         |
                         v
+------------------------------------------------+
|                Windows Endpoint                |
|------------------------------------------------|
| Joined to lab.local                            |
| Sysmon Installed                               |
| Splunk Universal Forwarder Installed           |
| Sends Security Logs to Splunk                  |
+------------------------------------------------+
                         |
                         |
                         v
+------------------------------------------------+
|                    Splunk SIEM                 |
|------------------------------------------------|
| Centralized Log Collection                     |
| Endpoint Monitoring                            |
| Detection Engineering                          |
| Threat Hunting                                 |
+------------------------------------------------+
```

---

# Prerequisites

Before joining the computer to Active Directory, verify the following:

## 1. Network Connectivity

Ensure the endpoint can communicate with the Domain Controller.

Example:

```powershell
ping dc01
ping lab.local
```

Expected output:

```text
Reply from 192.168.1.10
```

---

## 2. DNS Configuration

The endpoint must use the Domain Controller as its DNS server.

Example:

| Setting | Example Value |
|---|---|
| Preferred DNS Server | `192.168.1.10` |

Verify DNS settings:

```powershell
ipconfig /all
```

> Using public DNS servers such as `8.8.8.8` may prevent domain discovery.

---

## 3. Verify Time Synchronization

Kerberos authentication requires accurate time synchronization.

Check time status:

```powershell
w32tm /query /status
```

---

## 4. Confirm Sysmon Installation

Verify Sysmon is installed:

```powershell
sysmon64 -s
```

Verify Sysmon service:

```powershell
Get-Service Sysmon64
```

Expected output:

```text
Status   Name       DisplayName
------   ----       -----------
Running  Sysmon64   Sysmon64
```

---

## 5. Verify Splunk Universal Forwarder

Confirm the forwarder service is running:

```powershell
Get-Service SplunkForwarder
```

Expected output:

```text
Status   Name               DisplayName
------   ----               -----------
Running  SplunkForwarder    SplunkForwarder
```

Verify connectivity to Splunk:

```powershell
Test-NetConnection <splunk-ip> -Port 9997
```

---

# Step 1 — Open System Properties

On the Windows endpoint:

```text
Settings → System → About → Rename this PC (Advanced)
```

Or launch directly:

```powershell
sysdm.cpl
```

---

# Step 2 — Join the Domain

Inside System Properties:

1. Open the **Computer Name** tab
2. Click **Change**
3. Select **Domain**
4. Enter the domain name:

```text
lab.local
```

---

# Step 3 — Authenticate

Enter domain credentials with permissions to join systems to the domain.

Example:

```text
Username: Administrator
Password: ********
```

---

# Step 4 — Restart the System

After successful authentication:

```text
Welcome to the lab.local domain
```

Restart the endpoint.

---

# Step 5 — Verify Domain Login

At the login screen:

```text
LAB\username
```

Or:

```text
username@lab.local
```

---

# Verify Domain Membership

On the endpoint:

```powershell
systeminfo | findstr /B /C:"Domain"
```

Expected output:

```text
Domain: lab.local
```

Alternative verification:

```powershell
(Get-WmiObject Win32_ComputerSystem).Domain
```

---

# Verify Computer Object in Active Directory

On the Domain Controller:

```text
Active Directory Users and Computers
```

Navigate to:

```text
Computers
```

The endpoint should now appear in Active Directory.

---

# Verify DNS Registration

Force DNS registration:

```powershell
ipconfig /registerdns
```

Verify hostname resolution:

```powershell
nslookup CLIENT01
```

---

# Verify Splunk Log Ingestion

After the endpoint joins the domain, confirm logs are reaching Splunk.

Example SPL query:

```spl
index=windows host=CLIENT01
```

Verify Sysmon telemetry:

```spl
index=sysmon host=CLIENT01
```

Example Sysmon process creation events:

```spl
index=sysmon EventCode=1 host=CLIENT01
```

---

# Verify Group Policy Application

Force Group Policy updates:

```powershell
gpupdate /force
```

View applied policies:

```powershell
gpresult /r
```

---

# Common Issues

# DNS Misconfiguration

## Symptoms

- “The domain could not be contacted”
- Domain join failure
- Authentication problems

## Resolution

Configure the endpoint to use the Domain Controller as its DNS server.

---

# Time Drift

## Symptoms

- Kerberos authentication errors
- Login failures

## Resolution

Synchronize system clocks between the endpoint and Domain Controller.

---

# Firewall Restrictions

Ensure the following services are permitted:

- DNS
- LDAP
- Kerberos
- SMB

---

# Incorrect Network Profile

Verify the network profile is set to:

```text
Private
```

Check profile configuration:

```powershell
Get-NetConnectionProfile
```

---

# Security Monitoring Workflow

After domain enrollment:

1. Sysmon generates endpoint telemetry
2. Windows Event Logs are collected
3. Splunk Universal Forwarder sends logs to Splunk
4. Splunk indexes the events
5. Dashboards and detections monitor activity

This creates a centralized SOC-style monitoring pipeline within the lab environment.

---

# Useful PowerShell Commands

## View Current User

```powershell
whoami
```

## Check Hostname

```powershell
hostname
```

## View Active Network Configuration

```powershell
ipconfig /all
```

## Restart the Splunk Forwarder

```powershell
Restart-Service SplunkForwarder
```

## Verify Sysmon Events

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational"
```

---

# Expected Outcome

After completing this process:

- The endpoint authenticates against Active Directory
- Domain users can log into the system
- Group Policies can be applied centrally
- Sysmon telemetry is collected
- Logs are forwarded into Splunk
- Security monitoring and detection engineering workflows become centralized

---

# Future Improvements

Potential enhancements for the lab:

- Deploy Group Policies
- Create Organizational Units (OUs)
- Configure Windows Event Forwarding (WEF)
- Build Splunk detection dashboards
- Create Sysmon detections
- Integrate Sigma rules
- Add Active Directory hardening
- Deploy Splunk SOAR automation

