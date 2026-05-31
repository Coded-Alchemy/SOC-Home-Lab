# SOC Analysis Report Template

# SOC Analysis Report
*Based on Tyler Wall's Five-Step SOC Analyst Method*

---

## Ticket / Case Information

| Field            | Details                                      |
|------------------|----------------------------------------------|
| **Ticket ID**    |                                              |
| **Analyst Name** |                                              |
| **Date / Time**  |                                              |
| **Severity**     | ☐ Low  ☐ Medium  ☐ High  ☐ Critical          |
| **Alert Source** | (SIEM, EDR, IDS/IPS, Firewall, etc.)         |
| **Status**       | ☐ Open  ☐ In Progress  ☐ Escalated  ☐ Closed |

---

## Step 1 — Reason for the Alert
> *~5% of total investigation time*
>
> Explain why this alert fired. Understand the rule or signature that triggered it before proceeding. Research vendor documentation or internal runbooks if the rule is unfamiliar. Do not move to the next step until the trigger logic is clearly understood.

**Alert Name / Rule:**

**Why the Rule Fired (logic/signature):**

**What Specifically Triggered This Instance:**

**Example format:**
> *"This alarm fired due to [specific behavior] detected on [asset/user/system]."*

---

## Step 2 — Supporting Evidence
> *~40% of total investigation time*
>
> Build a complete timeline (default: 24 hours before and after the alert). Collect and document all relevant evidence. Do **not** analyze yet — focus only on gathering and recording. Add more evidence here if the analysis in Step 3 pivots your investigation.

### Identity
| Field                 | Details     |
|-----------------------|-------------|
| **Username**          |             |
| **Email**             |             |
| **Job Title**         |             |
| **VIP / Privileged?** | ☐ Yes  ☐ No |
| **Last Login**        |             |
| **Other Notes**       |             |

### Asset / Device
| Field            | Details                                     |
|------------------|---------------------------------------------|
| **Hostname**     |                                             |
| **IP Address**   |                                             |
| **Asset Type**   | (Workstation / Server / Dev / Prod / Other) |
| **OS**           |                                             |
| **Owner / Dept** |                                             |

### File / Artifact (if applicable)
| Field           | Details |
|-----------------|---------|
| **Filename**    |         |
| **File Hash**   |         |
| **File Size**   |         |
| **Signer**      |         |
| **Path**        |         |

### Timeline of Events

| Timestamp (UTC) | Event Description | Source Log |
|-----------------|-------------------|------------|
|                 |                   |            |
|                 |                   |            |
|                 |                   |            |
|                 |                   |            |

### Log Evidence
> *Paste relevant log snippets below (SIEM, EDR, firewall, IDS/IPS, proxy, email, etc.)*
> **Reminder:** Defang all URLs and IPs — replace `.` with `[.]` (e.g., `www[.]example[.]com`)

```
[Paste logs here]
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