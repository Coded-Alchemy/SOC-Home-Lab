# Splunk Detection Rules - MITRE ATT&CK Mapped

## Table of Contents
1. [Initial Access](#initial-access)
2. [Execution](#execution)
3. [Persistence](#persistence)
4. [Privilege Escalation](#privilege-escalation)
5. [Defense Evasion](#defense-evasion)
6. [Credential Access](#credential-access)
7. [Discovery](#discovery)
8. [Lateral Movement](#lateral-movement)
9. [Collection](#collection)
10. [Exfiltration](#exfiltration)

---

## Initial Access

### T1566.001 - Phishing: Spearphishing Attachment

**Detection Name:** Suspicious Email Attachment Execution

**Description:** Detects execution of files from email attachment directories with suspicious extensions.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4688
(NewProcessName="*\\Outlook\\*" OR NewProcessName="*\\Temp\\*" OR NewProcessName="*\\Downloads\\*")
(NewProcessName="*.exe" OR NewProcessName="*.scr" OR NewProcessName="*.com" OR NewProcessName="*.bat" OR NewProcessName="*.cmd")
| stats count by ComputerName, User, NewProcessName, ParentProcessName
| where count > 0
```

**Severity:** High  
**Data Sources:** Windows Event Logs (Security), Endpoint Detection  
**False Positives:** Legitimate software installations from downloads folder

---

### T1190 - Exploit Public-Facing Application

**Detection Name:** Web Application Exploitation Attempts

**Description:** Detects common web exploitation patterns including SQL injection, command injection, and path traversal.

**SPL Query:**
```spl
index=web sourcetype=access_*
(uri="*union*select*" OR uri="*;*cmd*" OR uri="*|*whoami*" OR uri="*../*" OR uri="*%2e%2e*" OR uri="*exec(*" OR uri="*<script*")
status=200
| stats count by src_ip, uri, status, dest
| where count > 3
```

**Severity:** Critical  
**Data Sources:** Web logs, WAF logs, IDS/IPS  
**False Positives:** Legitimate application behavior, security scanners

---

## Execution

### T1059.001 - Command and Scripting Interpreter: PowerShell

**Detection Name:** Suspicious PowerShell Execution

**Description:** Detects PowerShell commands with obfuscation, encoding, or download capabilities.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Microsoft-Windows-PowerShell/Operational EventCode=4104
(ScriptBlockText="*-enc*" OR ScriptBlockText="*-encodedcommand*" OR 
 ScriptBlockText="*downloadstring*" OR ScriptBlockText="*downloadfile*" OR 
 ScriptBlockText="*invoke-expression*" OR ScriptBlockText="*iex*" OR 
 ScriptBlockText="*invoke-webrequest*" OR ScriptBlockText="*bitstransfer*" OR
 ScriptBlockText="*bypass*" OR ScriptBlockText="*hidden*")
| stats count by ComputerName, User, ScriptBlockText
| where count > 0
```

**Severity:** High  
**Data Sources:** PowerShell Operational Logs (EventCode 4104)  
**False Positives:** Legitimate administrative scripts, software deployment

---

### T1059.003 - Command and Scripting Interpreter: Windows Command Shell

**Detection Name:** Suspicious Command Shell Activity

**Description:** Detects suspicious cmd.exe usage including reconnaissance and lateral movement commands.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4688 NewProcessName="*cmd.exe"
(CommandLine="*net user*" OR CommandLine="*net group*" OR CommandLine="*net localgroup*" OR 
 CommandLine="*whoami*" OR CommandLine="*ipconfig*" OR CommandLine="*systeminfo*" OR 
 CommandLine="*tasklist*" OR CommandLine="*netstat*" OR CommandLine="*ping*" OR 
 CommandLine="*wmic*" OR CommandLine="*reg query*")
| stats count by ComputerName, User, CommandLine, ParentProcessName
| where count > 5
```

**Severity:** Medium  
**Data Sources:** Windows Security Event Logs  
**False Positives:** IT administration, troubleshooting activities

---

### T1203 - Exploitation for Client Execution

**Detection Name:** Office Application Spawning Suspicious Processes

**Description:** Detects Microsoft Office applications spawning unusual child processes.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4688
(ParentProcessName="*\\WINWORD.EXE" OR ParentProcessName="*\\EXCEL.EXE" OR 
 ParentProcessName="*\\POWERPNT.EXE" OR ParentProcessName="*\\OUTLOOK.EXE")
(NewProcessName="*\\cmd.exe" OR NewProcessName="*\\powershell.exe" OR 
 NewProcessName="*\\wscript.exe" OR NewProcessName="*\\cscript.exe" OR 
 NewProcessName="*\\mshta.exe" OR NewProcessName="*\\regsvr32.exe")
| stats count by ComputerName, User, NewProcessName, ParentProcessName
| where count > 0
```

**Severity:** Critical  
**Data Sources:** Windows Event Logs, EDR  
**False Positives:** Legitimate macros, add-ins

---

## Persistence

### T1053.005 - Scheduled Task/Job: Scheduled Task

**Detection Name:** Suspicious Scheduled Task Creation

**Description:** Detects creation of scheduled tasks with suspicious characteristics.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4698
(TaskContent="*powershell*" OR TaskContent="*cmd.exe*" OR TaskContent="*wscript*" OR 
 TaskContent="*cscript*" OR TaskContent="*mshta*" OR TaskContent="*rundll32*" OR
 TaskContent="*http*" OR TaskContent="*regsvr32*")
| rex field=TaskContent "(?<TaskCommand><Command>.*?</Command>)"
| stats count by ComputerName, User, TaskName, TaskCommand
| where count > 0
```

**Severity:** High  
**Data Sources:** Windows Security Event Logs  
**False Positives:** Legitimate software installations, system maintenance tasks

---

### T1547.001 - Boot or Logon Autostart Execution: Registry Run Keys

**Detection Name:** Registry Run Key Modification

**Description:** Detects modifications to common autostart registry keys.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4657
ObjectName="*\\Software\\Microsoft\\Windows\\CurrentVersion\\Run*"
| stats count by ComputerName, SubjectUserName, ObjectName, ObjectValueName, NewValue
| where count > 0
```

**Severity:** High  
**Data Sources:** Windows Security Event Logs (Audit Object Access)  
**False Positives:** Software installations, legitimate applications

---

### T1136.001 - Create Account: Local Account

**Detection Name:** Local Account Creation

**Description:** Detects creation of new local user accounts.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4720
| stats count by ComputerName, SubjectUserName, TargetUserName, TargetDomainName
| eval severity=if(like(TargetUserName, "%admin%") OR like(TargetUserName, "%test%"), "High", "Medium")
| where count > 0
```

**Severity:** Medium-High  
**Data Sources:** Windows Security Event Logs  
**False Positives:** Legitimate user provisioning

---

## Privilege Escalation

### T1068 - Exploitation for Privilege Escalation

**Detection Name:** Privilege Escalation via Token Manipulation

**Description:** Detects attempts to manipulate access tokens for privilege escalation.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4672
(PrivilegeList="*SeDebugPrivilege*" OR PrivilegeList="*SeTcbPrivilege*" OR 
 PrivilegeList="*SeCreateTokenPrivilege*" OR PrivilegeList="*SeImpersonatePrivilege*")
NOT SubjectUserName IN ("SYSTEM", "LOCAL SERVICE", "NETWORK SERVICE")
| stats count by ComputerName, SubjectUserName, PrivilegeList
| where count > 0
```

**Severity:** High  
**Data Sources:** Windows Security Event Logs  
**False Positives:** Legitimate administrative tools

---

### T1548.002 - Abuse Elevation Control Mechanism: Bypass UAC

**Detection Name:** UAC Bypass Attempt

**Description:** Detects known UAC bypass techniques.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4688
(NewProcessName="*\\fodhelper.exe" OR NewProcessName="*\\computerdefaults.exe" OR 
 NewProcessName="*\\sdclt.exe" OR NewProcessName="*\\eventvwr.exe")
(CommandLine="*ms-settings*" OR CommandLine="*control.exe*")
| stats count by ComputerName, User, NewProcessName, CommandLine, ParentProcessName
| where count > 0
```

**Severity:** High  
**Data Sources:** Windows Security Event Logs  
**False Positives:** Legitimate system operations

---

### T1078.003 - Valid Accounts: Local Accounts

**Detection Name:** Suspicious Local Admin Activity

**Description:** Detects unusual activity from local administrator accounts.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4672 
SubjectUserName!="Administrator"
(PrivilegeList="*SeDebugPrivilege*" OR PrivilegeList="*SeBackupPrivilege*" OR 
 PrivilegeList="*SeRestorePrivilege*")
| stats count by ComputerName, SubjectUserName, PrivilegeList
| where count > 10
```

**Severity:** Medium  
**Data Sources:** Windows Security Event Logs  
**False Positives:** System administrators, automated processes

---

## Defense Evasion

### T1562.001 - Impair Defenses: Disable or Modify Tools

**Detection Name:** Security Tool Tampering

**Description:** Detects attempts to disable or modify security tools.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4688
(CommandLine="*Set-MpPreference*" OR CommandLine="*DisableRealtimeMonitoring*" OR 
 CommandLine="*sc stop*" OR CommandLine="*sc delete*" OR CommandLine="*net stop*")
(CommandLine="*windefend*" OR CommandLine="*Windows Defender*" OR 
 CommandLine="*MsMpEng*" OR CommandLine="*SecurityHealthService*" OR
 CommandLine="*Sense*" OR CommandLine="*antivirus*")
| stats count by ComputerName, User, CommandLine, NewProcessName
| where count > 0
```

**Severity:** Critical  
**Data Sources:** Windows Event Logs, EDR  
**False Positives:** Legitimate administrative maintenance

---

### T1070.001 - Indicator Removal: Clear Windows Event Logs

**Detection Name:** Windows Event Log Cleared

**Description:** Detects clearing of Windows event logs.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security (EventCode=1102 OR EventCode=104)
| stats count by ComputerName, User, LogName
| eval severity="Critical"
| where count > 0
```

**Severity:** Critical  
**Data Sources:** Windows Security and System Event Logs  
**False Positives:** Scheduled maintenance, log rotation policies

---

### T1027 - Obfuscated Files or Information

**Detection Name:** Encoded/Obfuscated Command Execution

**Description:** Detects execution of encoded or obfuscated commands.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4688
(CommandLine="*-enc*" OR CommandLine="*-e *" OR CommandLine="*-en*" OR 
 CommandLine="*FromBase64String*" OR CommandLine="*::FromBase64*" OR
 CommandLine="*char*join*" OR CommandLine="*replace*")
| stats count by ComputerName, User, CommandLine, NewProcessName
| where count > 0
```

**Severity:** High  
**Data Sources:** Windows Security Event Logs  
**False Positives:** Legitimate encoded scripts

---

## Credential Access

### T1003.001 - OS Credential Dumping: LSASS Memory

**Detection Name:** LSASS Memory Access

**Description:** Detects attempts to access LSASS process memory for credential dumping.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4656
ObjectName="*\\lsass.exe"
(AccessMask="0x1010" OR AccessMask="0x1410" OR AccessMask="0x1438")
NOT ProcessName IN ("*\\System32\\taskmgr.exe", "*\\System32\\wmiprvse.exe", "*\\System32\\services.exe")
| stats count by ComputerName, SubjectUserName, ProcessName, ObjectName
| where count > 0
```

**Severity:** Critical  
**Data Sources:** Windows Security Event Logs (SACL auditing required)  
**False Positives:** Security software, legitimate administrative tools

---

### T1110.003 - Brute Force: Password Spraying

**Detection Name:** Password Spray Attack

**Description:** Detects password spray attacks across multiple accounts.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4625
| stats dc(TargetUserName) as unique_users, count by src_ip, ComputerName
| where unique_users > 10 AND count > 20
| eval attack_type="Password Spray"
```

**Severity:** High  
**Data Sources:** Windows Security Event Logs, Authentication logs  
**False Positives:** Misconfigured applications, legitimate account lockouts

---

### T1558.003 - Steal or Forge Kerberos Tickets: Kerberoasting

**Detection Name:** Kerberoasting Activity

**Description:** Detects potential Kerberoasting attacks through RC4 ticket requests.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4769
TicketEncryptionType=0x17
ServiceName!="*$"
| stats count by ComputerName, TargetUserName, ServiceName, IpAddress
| where count > 5
```

**Severity:** High  
**Data Sources:** Windows Security Event Logs  
**False Positives:** Legacy applications using RC4

---

## Discovery

### T1087.001 - Account Discovery: Local Account

**Detection Name:** Local Account Enumeration

**Description:** Detects enumeration of local accounts on systems.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4688
(CommandLine="*net user*" OR CommandLine="*net localgroup*" OR 
 CommandLine="*Get-LocalUser*" OR CommandLine="*Get-LocalGroupMember*" OR
 CommandLine="*wmic useraccount*")
| stats count by ComputerName, User, CommandLine, NewProcessName
| where count > 3
```

**Severity:** Medium  
**Data Sources:** Windows Security Event Logs  
**False Positives:** IT administration, inventory tools

---

### T1018 - Remote System Discovery

**Detection Name:** Network Reconnaissance

**Description:** Detects reconnaissance activities to discover remote systems.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4688
(CommandLine="*net view*" OR CommandLine="*ping*" OR CommandLine="*nslookup*" OR 
 CommandLine="*arp -a*" OR CommandLine="*nltest*" OR CommandLine="*dsquery*")
| stats count by ComputerName, User, CommandLine
| where count > 5
```

**Severity:** Medium  
**Data Sources:** Windows Security Event Logs  
**False Positives:** Network troubleshooting, system administration

---

### T1057 - Process Discovery

**Detection Name:** Process Enumeration

**Description:** Detects excessive process enumeration activity.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4688
(CommandLine="*tasklist*" OR CommandLine="*Get-Process*" OR 
 CommandLine="*wmic process*" OR CommandLine="*ps.exe*")
| stats count by ComputerName, User, CommandLine
| where count > 10
```

**Severity:** Low-Medium  
**Data Sources:** Windows Security Event Logs  
**False Positives:** System monitoring tools, administrative scripts

---

## Lateral Movement

### T1021.001 - Remote Services: Remote Desktop Protocol

**Detection Name:** Unusual RDP Connection

**Description:** Detects suspicious RDP connections.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security (EventCode=4624 OR EventCode=4625)
LogonType=10
| stats count, dc(ComputerName) as dest_count by IpAddress, TargetUserName
| where dest_count > 5 OR count > 20
```

**Severity:** Medium-High  
**Data Sources:** Windows Security Event Logs  
**False Positives:** IT administrators, jump servers

---

### T1021.002 - Remote Services: SMB/Windows Admin Shares

**Detection Name:** Lateral Movement via Admin Shares

**Description:** Detects access to administrative shares for lateral movement.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=5140
(ShareName="\\\\*\\C$" OR ShareName="\\\\*\\ADMIN$" OR ShareName="\\\\*\\IPC$")
| stats count by src_ip, ComputerName, SubjectUserName, ShareName, ObjectType
| where count > 5
```

**Severity:** High  
**Data Sources:** Windows Security Event Logs  
**False Positives:** System administration, backup software

---

### T1047 - Windows Management Instrumentation

**Detection Name:** Remote WMI Execution

**Description:** Detects remote command execution via WMI.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4688
(ParentProcessName="*\\wmiprvse.exe" OR NewProcessName="*\\wmic.exe")
(CommandLine="*/node:*" OR CommandLine="*process call create*")
| stats count by ComputerName, User, CommandLine, NewProcessName
| where count > 0
```

**Severity:** High  
**Data Sources:** Windows Security Event Logs  
**False Positives:** Remote management tools, SCCM

---

## Collection

### T1560.001 - Archive Collected Data: Archive via Utility

**Detection Name:** Data Archiving Activity

**Description:** Detects creation of archives that may contain sensitive data.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4688
(NewProcessName="*\\7z.exe" OR NewProcessName="*\\winrar.exe" OR 
 NewProcessName="*\\rar.exe" OR NewProcessName="*\\winzip.exe" OR
 CommandLine="*Compress-Archive*" OR CommandLine="*tar.exe*")
(CommandLine="*Documents*" OR CommandLine="*Desktop*" OR CommandLine="*Users*" OR
 CommandLine="*.txt" OR CommandLine="*.doc*" OR CommandLine="*.xls*" OR CommandLine="*.pdf")
| stats count by ComputerName, User, CommandLine, NewProcessName
| where count > 0
```

**Severity:** Medium  
**Data Sources:** Windows Security Event Logs  
**False Positives:** Legitimate file compression, backups

---

### T1113 - Screen Capture

**Detection Name:** Screen Capture Tools Execution

**Description:** Detects execution of screen capture utilities.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:Security EventCode=4688
(NewProcessName="*\\SnippingTool.exe" OR NewProcessName="*\\Snip*.exe" OR 
 CommandLine="*screenshot*" OR CommandLine="*screen capture*" OR 
 CommandLine="*System.Drawing.Bitmap*" OR CommandLine="*[Windows.Forms.Screen]*")
| stats count by ComputerName, User, CommandLine, NewProcessName
| where count > 5
```

**Severity:** Low-Medium  
**Data Sources:** Windows Security Event Logs  
**False Positives:** Legitimate screenshot tools, documentation

---

## Exfiltration

### T1041 - Exfiltration Over C2 Channel

**Detection Name:** Unusual Outbound Traffic Volume

**Description:** Detects large volumes of outbound traffic to unusual destinations.

**SPL Query:**
```spl
index=network sourcetype=firewall action=allowed
| stats sum(bytes_out) as total_bytes_out, dc(dest_ip) as unique_dests by src_ip
| where total_bytes_out > 1000000000 OR unique_dests > 100
| eval total_bytes_gb=round(total_bytes_out/1024/1024/1024, 2)
```

**Severity:** Medium-High  
**Data Sources:** Firewall logs, Network traffic  
**False Positives:** Cloud backups, legitimate file transfers

---

### T1048.003 - Exfiltration Over Alternative Protocol: Exfiltration Over Unencrypted Non-C2 Protocol

**Detection Name:** Data Exfiltration via DNS

**Description:** Detects potential DNS tunneling or exfiltration.

**SPL Query:**
```spl
index=network sourcetype=dns
| stats count, avg(len(query)) as avg_length by src_ip, query
| where count > 100 AND avg_length > 50
| eval suspicious_score=count * avg_length
| where suspicious_score > 10000
```

**Severity:** High  
**Data Sources:** DNS logs  
**False Positives:** CDN traffic, legitimate DNS queries

---

### T1567.002 - Exfiltration Over Web Service: Exfiltration to Cloud Storage

**Detection Name:** Large Upload to Cloud Services

**Description:** Detects large uploads to cloud storage services.

**SPL Query:**
```spl
index=proxy sourcetype=proxy
(url="*dropbox.com*" OR url="*drive.google.com*" OR url="*onedrive.live.com*" OR 
 url="*box.com*" OR url="*mediafire.com*" OR url="*mega.nz*")
http_method=POST
| stats sum(bytes) as total_bytes by src_ip, user, url
| where total_bytes > 100000000
| eval total_mb=round(total_bytes/1024/1024, 2)
```

**Severity:** Medium  
**Data Sources:** Proxy logs, Web logs  
**False Positives:** Legitimate cloud storage usage

---

## Correlation Rules

### Multi-Stage Attack Detection

**Detection Name:** Potential Multi-Stage Attack Chain

**Description:** Correlates multiple suspicious activities from the same source.

**SPL Query:**
```spl
index=windows sourcetype=WinEventLog:*
[search index=windows EventCode=4688 (CommandLine="*powershell*" OR CommandLine="*cmd.exe*")
| fields ComputerName, User]
| transaction ComputerName, User maxspan=1h
| where eventcount > 5
| stats count by ComputerName, User, _time
| sort -count
```

**Severity:** Critical  
**Data Sources:** Multiple Windows Event Logs  
**False Positives:** Intensive administrative sessions

---

## Implementation Notes

### Required Splunk Add-ons
- Splunk Add-on for Microsoft Windows
- Splunk Add-on for Microsoft IIS
- Splunk Common Information Model (CIM)

### Data Source Requirements
- Windows Security Event Logs (Audit Process Creation enabled)
- PowerShell Logging (Script Block Logging enabled)
- Sysmon (recommended for enhanced visibility)
- Network traffic logs (Firewall, Proxy, DNS)
- EDR telemetry

### Tuning Recommendations
1. Adjust thresholds based on your environment's baseline
2. Add organizational whitelist filters for known good processes
3. Implement alert throttling to reduce false positives
4. Create lookup tables for known malicious IPs and hashes
5. Regularly review and update detection logic

### Alert Response Workflow
1. Triage: Review alert details and context
2. Investigate: Examine related events and timeline
3. Contain: Isolate affected systems if confirmed malicious
4. Remediate: Remove malicious artifacts and restore systems
5. Document: Record findings and lessons learned

### Performance Optimization
- Use summary indexing for frequently run searches
- Implement data models for common queries
- Set appropriate time ranges for searches
- Use accelerated data models where applicable

---

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Maintained By:** Security Operations Team
