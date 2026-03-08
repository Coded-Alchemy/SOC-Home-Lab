# Splunk Detection Engineering Lab

A hands-on security operations lab built to simulate a real enterprise logging and detection environment using Splunk.

This project demonstrates how to deploy and manage log collection across Linux and Windows systems, collect advanced 
telemetry using Sysmon, and build security detections based on attacker techniques.

---

# Lab Architecture

The lab environment consists of:

* Splunk Enterprise (Indexer + Deployment Server)
* Linux servers with Universal Forwarder
* Windows endpoints with Universal Forwarder
* Sysmon for enhanced Windows telemetry

Logs are centrally collected and analyzed in Splunk to support detection engineering workflows.

---

# Features

* Centralized log collection
* Splunk Deployment Server management
* Linux log ingestion
* Windows event log monitoring
* Sysmon process and network telemetry
* Detection queries for attacker behavior
* Attack simulation testing

---

# Technologies Used

* Splunk Enterprise
* Splunk Universal Forwarder
* Sysmon
* Linux log monitoring
* Windows Event Logs
* MITRE ATT&CK detection mapping

---

# Deployment Server Configuration

Apps are deployed using Splunk server classes.

Example serverclass configuration:

```
[serverClass:all_forwarders]
whitelist.0 = *

[serverClass:all_forwarders:app:TA_base_forwarder]

[serverClass:linux_servers]
whitelist.0 = linux*

[serverClass:linux_servers:app:TA_linux_logs]

[serverClass:windows_servers]
whitelist.0 = win*

[serverClass:windows_servers:app:TA_windows_logs]

[serverClass:windows_sysmon]
whitelist.0 = win*

[serverClass:windows_sysmon:app:TA_sysmon_logs]
```

---

# Example Logs Collected

Linux

* /var/log/syslog
* /var/log/auth.log

Windows

* Security Event Log
* System Event Log
* Application Event Log

Sysmon

* Process creation
* Network connections
* Persistence activity

---

# Detection Examples

Example detection query for suspicious PowerShell:

```
index=windows EventCode=4688
| search powershell
| stats count by CommandLine, host
```

---

# Attack Simulation

Attack activity is simulated using Caldera to generate realistic adversary behavior.

This allows validation of detection rules against known attack techniques.

---

# Project Goals

* Build a realistic SOC monitoring environment
* Practice detection engineering
* Understand log pipelines and telemetry sources
* Develop practical Splunk administration skills

---

# Future Improvements

* Detection dashboards
* Automated alerts
* Threat hunting queries
* Integration with MITRE ATT&CK framework

---

# Author

Security engineering lab project demonstrating practical SOC and detection engineering skills.
