# Network Design

## VLAN 10 - SOC Network (192.168.10.0/24)

**Purpose**: Security monitoring, SIEM, threat intelligence, and defensive operations.

| VM             | IP Address     | Role               | Services                                          |
| -------------- | -------------- | ------------------ | ------------------------------------------------- |
| Oracle Linux   | 192.168.10.100 | SIEM, Automation   | Splunk Enterprise, Caldera, Splunk SOAR (planned) |
| Kali Purple    | 192.168.10.101 | Defensive Security | IDS, Threat hunting tools                         |
| Security Onion | 192.168.10.103 |                    | Suricata, Zeek, Elastic Stack, Kibana             |
**Key Functions**:
- Centralized log collection and analysis
- Network security monitoring (NSM)
- Adversary emulation and testing
- Security orchestration and automation
---
## VLAN 20 - Attack Network (192.168.20.0/24)

Purpose: Offensive security operations and penetration testing.

| VM         | IP Address     | Role                | Services                             |
| ---------- | -------------- | ------------------- | ------------------------------------ |
| Kali Linux | 192.168.20.101 | Penetration Testing | Metasploit, Nmap, Burp Suite, SQLmap |
**Key Functions**:
- Network reconnaissance and scanning
- Vulnerability assessment
- Exploitation and post-exploitation
- Web application testing
---
## VLAN 30 - Target Network (192.168.30.0/24)

**Purpose**: Vulnerable systems for testing and attack simulations.

| VM               | IP Address     | OS             | Vulnerabilities                                |
| ---------------- | -------------- | -------------- | ---------------------------------------------- |
| Windows 10       | 192.168.30.101 | Windows 10 Pro | Configurable vulnerable services               |
| Metasploitable 2 | 192.168.30.103 | Ubuntu Linux   | Intentionally vulnerable (FTP, SSH, SMB, etc.) |
**Key Functions**:
- Realistic target environment
- Vulnerability exploitation practice
- Alert generation for SIEM
- Endpoint detection and response testing
---
## VLAN 40 - Malware Analysis Network (192.168.40.0/24)

**Purpose**: Isolated Network for Malware Analysis.

| VM     | IP Address     | OS               | 
|--------|----------------|------------------|
| REMnux | 192.168.40.100 | Ubuntu 20.04 LTS | 

**Key Functions**:
- Isolated network to safely analyze malware samples