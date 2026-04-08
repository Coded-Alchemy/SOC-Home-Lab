# How to Index Alerts

---

### 1) Define alerts schema

Standardize fields, keep naming consistent or nothing will correlate later.
```json
{
  "detection_name": "Encoded PowerShell Execution",
  "rule_id": "sigma_001",
  "mitre_technique": "T1059.001",
  "severity": "high",
  "host": "win10-lab",
  "user": "labuser",
  "command_line": "powershell -enc ...",
  "_time": "event time"
}
```

### 2) Create Index Alerts

Create new index "alerts"

---

## Method 1) Saved Searches → Alerts → Write to Index

**Example Detection**
```commandline
index=sysmon EventCode=1
CommandLine="*-enc*"
```

**Convert it to a Detection Event**
```commandline
index=sysmon EventCode=1
CommandLine="*-enc*"
| eval detection_name="Encoded PowerShell Execution"
| eval mitre_technique="T1059.001"
| eval severity="high"
| eval host=Computer
| table _time detection_name mitre_technique severity host CommandLine
```

**Write it to index=alerts**
```commandline
index=sysmon EventCode=1
CommandLine="*-enc*"
| eval detection_name="Encoded PowerShell Execution"
| eval mitre_technique="T1059.001"
| eval severity="high"
| eval host=Computer
| collect index=alerts
```

**Automate it**

- Save as Scheduled Search
- Run every 5 minutes

Now you have a continuous detection pipeline.

---

## Method 2) Sigma Pipeline -> alerts index

This home lab project already has a DaC(Detections as Code) pipeline, the next step is to upgrade it.

Append this to the SPL output
```commandline
| eval detection_name="<rule_title>"
| eval mitre_technique="<technique>"
| eval severity="<level>"
| collect index=alerts
```