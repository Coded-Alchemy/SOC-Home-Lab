# Active Directory Lab

## Overview

This project simulates a real-world enterprise Active Directory (AD) environment with centralized identity management, 
endpoint monitoring, and security detection capabilities. The lab is designed to demonstrate practical skills in:

- Active Directory administration
- Security monitoring and logging
- Detection engineering
- Adversary emulation

The environment mirrors a small enterprise network where identity infrastructure, endpoints, and security tooling are 
integrated to detect and respond to threats.

---

## Architecture

### High-Level Design

```
                         [ MITRE Caldera Attacker ]
                                   |
                             ( WAN / NAT )
                                   |
                            [ pfSense Firewall ]
                                   |
        -----------------------------------------------------
        |                        |                          |
 [ Domain Controller ]     [ Windows 10 Client ]     [ Splunk Server ]
     (AD DS / DNS)            (Endpoint)               (SIEM)
```

---

### Architecture Description

- **pfSense Firewall**: Controls traffic between WAN and internal lab network
- **Domain Controller**: Hosts Active Directory Domain Services (AD DS), DNS, and authentication services
- **Windows Endpoint**: Domain-joined workstation used to simulate user activity
- **Splunk Server**: Centralized log aggregation and detection platform
- **MITRE Caldera**: Used for adversary emulation and attack simulation

---

## Technologies Used

- Active Directory Domain Services (AD DS)
- Windows Server 2019/2022
- Windows 10/11
- Splunk (SIEM)
- Sysmon (endpoint telemetry)
- pfSense (firewall)
- MITRE Caldera (adversary emulation)

---

## Active Directory Configuration

### Domain Setup

- Domain Name: `lab.local`
- Single forest, single domain architecture
- Domain Controller configured with DNS

---

### Organizational Unit (OU) Structure

```
lab.local
│
├── Users
├── Computers
├── Servers
└── Service Accounts
```

---

### Users & Groups

- Standard user accounts created for simulation
- Domain Admins group configured
- Service accounts for internal services

---

## Group Policy Configuration

Group Policy Objects (GPOs) were implemented to enforce security controls and enable logging.

### Security Policies

- Password complexity requirements enabled
- Account lockout policy configured

### Auditing & Logging

- Logon auditing enabled
- PowerShell logging enabled
- Command-line auditing enabled

---

## Logging & Monitoring Pipeline

### Log Flow

```
Windows Endpoint → Sysmon → Splunk Forwarder → Splunk Indexer
```

### Data Collected

- Process creation events
- Authentication logs
- PowerShell execution logs
- Network connections

---

## Adversary Emulation

Attack scenarios were executed from the MITRE Caldera C2 server to simulate real-world threats.

### Techniques Simulated

- Credential Dumping
- Pass-the-Hash
- Privilege Escalation
- Lateral Movement

### Framework Mapping

Mapped to MITRE ATT&CK techniques:

- T1003 – Credential Dumping
- T1021 – Remote Services

---

## Detection Engineering

Detection logic was developed based on observed attacker behavior.

### Example Detections

- Suspicious PowerShell execution
- LSASS access attempts
- Multiple failed login attempts
- Privileged account abuse

---

## Screenshots

> Add screenshots here to demonstrate:

- Active Directory Users & Computers
- Group Policy configurations
- Splunk dashboards
- Attack logs and detections

---

## Key Takeaways

- Built a functional enterprise-style identity infrastructure
- Implemented centralized logging and monitoring
- Simulated real-world attack techniques
- Developed detection logic aligned with attacker behavior

---

## Future Improvements

- Integrate automated detection deployment (Detection-as-Code)
- Expand environment with additional endpoints
- Add EDR tooling
- Simulate advanced attack chains

---

## Notes

This lab is part of a broader security engineering portfolio focused on detection pipelines, 
SIEM engineering, and adversary emulation.