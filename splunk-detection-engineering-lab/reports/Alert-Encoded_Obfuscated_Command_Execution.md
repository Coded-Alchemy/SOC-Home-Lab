# SOC Analysis Report

---

## Ticket / Case Information

| Field            | Details        |
|------------------|----------------|
| **Ticket ID**    | N/A            |
| **Analyst Name** | Taji Abdullah  | 
| **Date / Time**  | 06/03/2026     |
| **Severity**     | ☐ High         |
| **Alert Source** | SIEM           |
| **Status**       | ☐ Escalated    |

---

## Reason for the Alert

**Alert Name / Rule:** 
> Encoded/Obfuscated Command Execution

**Why the Rule Fired (logic/signature):**
```commandline
index="windows" 
| rex field=CommandLine "(?<CommandLineMatch>.*[\\+\\^\\%].*)"
| eval CommandLineCondition=if(isnotnull(CommandLineMatch), "true", "false")
| search CommandLine IN ("*-enc*", "*-encodedcommand*", "*FromBase64String*", "*::FromBase64*") OR (CommandLine IN ("*char*", "*join*", "*replace*", "*split*") CommandLineCondition="true")
```

**What Specifically Triggered This Instance:**
> This alert fired due to Base64 commands ran in Powershell on ComputerName=win-DC01.lab.local.

---

## Supporting Evidence

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
| Field            | Details         |
|------------------|-----------------|
| **Hostname**     | win-DC01        |
| **IP Address**   | 192.168.30.101  |
| **Asset Type**   | Server          |
| **OS**           | Windows         |
| **Owner / Dept** | Lab.local       |


### Timeline of Events

| Timestamp (UTC)               | Event Description             | Source Log                            |
|-------------------------------|-------------------------------|---------------------------------------|
| 06/03/2026 04:10:14.241 PM    | Obfuscated Command Execution  | Microsoft-Windows-Sysmon/Operational  |

### Log Evidence
```
06/03/2026 04:10:14.241 PM
LogName=Microsoft-Windows-Sysmon/Operational
EventCode=1
EventType=4
ComputerName=win-DC01.lab.local
User=NOT_TRANSLATED
Sid=S-1-5-18
SidType=0
SourceName=Microsoft-Windows-Sysmon
Type=Information
RecordNumber=168606
Keywords=None
TaskCategory=Sysmon service state changed
OpCode=Info
Message=Process Create:
RuleName: -
UtcTime: 2026-06-03 20:10:14.162
ProcessGuid: {260db9a0-8a26-6a20-ab71-000000003c00}
ProcessId: 3584
Image: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
FileVersion: 10.0.26100.5074 (WinBuild.160101.0800)
Description: Windows PowerShell
Product: Microsoft® Windows® Operating System
Company: Microsoft Corporation
OriginalFileName: PowerShell.EXE
CommandLine: "C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe" -Enc JABOAGEAbQBlAFMAcABhAGMAZQAgAD0AIABHAGUAdAAtAFcAbQBpAE8AYgBqAGUAYwB0ACAALQBOAGEAbQBlAHMAcABhAGMAZQAgACIAcgBvAG8AdAAiACAALQBDAGwAYQBzAHMAIAAiAF8AXwBOAGEAbQBlAHMAcABhAGMAZQAiACAAfAAgAFMAZQBsAGUAYwB0ACAATgBhAG0AZQAgAHwAIABPAHUAdAAtAFMAdAByAGkAbgBnACAALQBTAHQAcgBlAGEAbQAgAHwAIABTAGUAbABlAGMAdAAtAFMAdAByAGkAbgBnACAAIgBTAGUAYwB1AHIAaQB0AHkAQwBlAG4AdABlAHIAIgA7ACQAUwBlAGMAdQByAGkAdAB5AEMAZQBuAHQAZQByACAAPQAgACQATgBhAG0AZQBTAHAAYQBjAGUAIAB8ACAAUwBlAGwAZQBjAHQALQBPAGIAagBlAGMAdAAgAC0ARgBpAHIAcwB0ACAAMQA7AEcAZQB0AC0AVwBtAGkATwBiAGoAZQBjAHQAIAAtAE4AYQBtAGUAcwBwAGEAYwBlACAAIgByAG8AbwB0AFwAJABTAGUAYwB1AHIAaQB0AHkAQwBlAG4AdABlAHIAIgAgAC0AQwBsAGEAcwBzACAAQQBuAHQAaQBWAGkAcgB1AHMAUAByAG8AZAB1AGMAdAAgAHwAIABTAGUAbABlAGMAdAAgAEQAaQBzAHAAbABhAHkATgBhAG0AZQAsACAASQBuAHMAdABhAG4AYwBlAEcAdQBpAGQALAAgAFAAYQB0AGgAVABvAFMAaQBnAG4AZQBkAFAAcgBvAGQAdQBjAHQARQB4AGUALAAgAFAAYQB0AGgAVABvAFMAaQBnAG4AZQBkAFIAZQBwAG8AcgB0AGkAbgBnAEUAeABlACwAIABQAHIAbwBkAHUAYwB0AFMAdABhAHQAZQAsACAAVABpAG0AZQBzAHQAYQBtAHAAIAB8ACAARgBvAHIAbQBhAHQALQBMAGkAcwB0ADsA
CurrentDirectory: C:\Users\Public\
User: NT AUTHORITY\SYSTEM
LogonGuid: {260db9a0-7249-6a1c-e703-000000000000}
LogonId: 0x3E7
TerminalSessionId: 0
IntegrityLevel: System
Hashes: MD5=A97E6573B97B44C96122BFA543A82EA1,SHA256=0FF6F2C94BC7E2833A5F7E16DE1622E5DBA70396F31C7D5F56381870317E8C46,IMPHASH=AFACF6DC9041114B198160AAB4D0AE77
ParentProcessGuid: {260db9a0-8a25-6a20-aa71-000000003c00}
ParentProcessId: 7632
ParentImage: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
ParentCommandLine: powershell.exe -ExecutionPolicy Bypass -C "powershell -Enc JABOAGEAbQBlAFMAcABhAGMAZQAgAD0AIABHAGUAdAAtAFcAbQBpAE8AYgBqAGUAYwB0ACAALQBOAGEAbQBlAHMAcABhAGMAZQAgACIAcgBvAG8AdAAiACAALQBDAGwAYQBzAHMAIAAiAF8AXwBOAGEAbQBlAHMAcABhAGMAZQAiACAAfAAgAFMAZQBsAGUAYwB0ACAATgBhAG0AZQAgAHwAIABPAHUAdAAtAFMAdAByAGkAbgBnACAALQBTAHQAcgBlAGEAbQAgAHwAIABTAGUAbABlAGMAdAAtAFMAdAByAGkAbgBnACAAIgBTAGUAYwB1AHIAaQB0AHkAQwBlAG4AdABlAHIAIgA7ACQAUwBlAGMAdQByAGkAdAB5AEMAZQBuAHQAZQByACAAPQAgACQATgBhAG0AZQBTAHAAYQBjAGUAIAB8ACAAUwBlAGwAZQBjAHQALQBPAGIAagBlAGMAdAAgAC0ARgBpAHIAcwB0ACAAMQA7AEcAZQB0AC0AVwBtAGkATwBiAGoAZQBjAHQAIAAtAE4AYQBtAGUAcwBwAGEAYwBlACAAIgByAG8AbwB0AFwAJABTAGUAYwB1AHIAaQB0AHkAQwBlAG4AdABlAHIAIgAgAC0AQwBsAGEAcwBzACAAQQBuAHQAaQBWAGkAcgB1AHMAUAByAG8AZAB1AGMAdAAgAHwAIABTAGUAbABlAGMAdAAgAEQAaQBzAHAAbABhAHkATgBhAG0AZQAsACAASQBuAHMAdABhAG4AYwBlAEcAdQBpAGQALAAgAFAAYQB0AGgAVABvAFMAaQBnAG4AZQBkAFAAcgBvAGQAdQBjAHQARQB4AGUALAAgAFAAYQB0AGgAVABvAFMAaQBnAG4AZQBkAFIAZQBwAG8AcgB0AGkAbgBnAEUAeABlACwAIABQAHIAbwBkAHUAYwB0AFMAdABhAHQAZQAsACAAVABpAG0AZQBzAHQAYQBtAHAAIAB8ACAARgBvAHIAbQBhAHQALQBMAGkAcwB0ADsA"
ParentUser: NT AUTHORITY\SYSTEM
Collapse
host = win-DC01source = WinEventLog:Microsoft-Windows-Sysmon/Operationalsourcetype = WinEventLog
```



**Notes:**
> The encoded command from the log was 
> ran through CyberChef, the result is below:
```commandline
$NameSpace = Get-WmiObject -Namespace "root" -Class "__Namespace" | Select Name | Out-String -Stream 
| Select-String "SecurityCenter";$SecurityCenter = $NameSpace 
| Select-Object -First 1;Get-WmiObject -Namespace "root\$SecurityCenter" -Class AntiVirusProduct 
| Select DisplayName, InstanceGuid, PathToSignedProductExe, PathToSignedReportingExe, ProductState, Timestamp | Format-List;
```

---

## Analysis

### MITRE ATT&CK Mapping 
| Tactic    | Technique                    | ID         |
|-----------|------------------------------|------------|
| Discovery | Security Software Discovery  | T1518.001  |

### Analyst Notes / Connections Made
> This PowerShell command is performing security product discovery on a Windows system. Specifically, it is enumerating 
> installed antivirus products through Windows Management Instrumentation (WMI).
> 
> The goal is to determine: Which antivirus products are installed, Whether they are active, Their executable locations 
> Their registration status in Windows Security Center
> 
> Used for Identifying defensive tools before executing payloads.

---

## Conclusion

**Summary:**
> This alarm triggered due to obfuscated command ran in Powershell. Evidence showed Discovery tactics being used. 
> Analysis of the unencoded command determined security software  discovery activity being ran by the System account. 
> This is will be escalated for further investigation as there could be possible malicious activity taking place.

**Disposition:**
☐ True Positive — Malicious

**Action Taken:**

Escalation for further investigation.

---

## Next Steps

**Pending Actions:**

| # | Action Item                                                    | Owner | Due Date | Status |
|---|----------------------------------------------------------------|-------|----------|--------|
| 1 | Investigate for malicious activity happining after this event. |       |          |        |
| 2 |                                                                |       |          |        |

**Escalation Required?** ☐ Yes — escalated to IR Team 


---

