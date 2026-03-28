# Adversary Emulation Lab – MITRE Caldera

## Overview

This project demonstrates a full adversary emulation workflow using MITRE Caldera to simulate real-world attack 
techniques and validate detection capabilities within a SIEM-driven security environment.

The goal of this lab is to:

- Emulate attacker behavior mapped to MITRE ATT&CK
- Validate detection coverage in Splunk
- Identify visibility gaps across the environment
- Improve detection engineering capabilities

---
## Lab Architecture

This lab simulates a small-to-medium enterprise environment:

- Adversary Server: MITRE Caldera
- Target Systems: Windows endpoints (with Sysmon)
- SIEM Platform: Splunk
- Network Control: pfSense Firewall
- Virtualization: VMware

---
## Technologies Used

- MITRE Caldera (Adversary Emulation)
- Splunk (SIEM & Detection Engineering)
- Sysmon (Endpoint Telemetry)
- pfSense (Network Security)
- VMware (Infrastructure)

---
## Key Takeaways

- Adversary emulation is critical for validating real detection capabilities
- Detection engineering requires continuous tuning and validation
- Mapping to MITRE ATT&CK provides measurable security coverage
- Identifying blind spots is more valuable than confirming detections