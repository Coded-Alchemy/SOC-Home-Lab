# Active Directory Home Lab

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

[Add diagram]

---

### Architecture Description

- **pfSense Firewall**: Controls traffic between WAN and internal lab network
- **Domain Controller**: Hosts Active Directory Domain Services (AD DS), DNS, and authentication services
- **Windows Endpoint**: Domain-joined workstation used to simulate user activity
- **Splunk Server**: Centralized log aggregation and detection platform
- **Kali Linux**: Used for adversary emulation and attack simulation

---

## Technologies Used

- Active Directory Domain Services (AD DS)
- Windows Server 2025
- Windows 10/11
- Splunk (SIEM)
- Sysmon (endpoint telemetry)
- pfSense (firewall)
- Caldera (adversary emulation)