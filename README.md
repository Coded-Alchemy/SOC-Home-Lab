# SOC-Home-Lab    

This home lab simulates a complete Security Operations Center (SOC) environment for hands-on cybersecurity training.     
The lab provides practical experience in threat detection, incident response, penetration testing, adversary emulation,     
and security monitoring using industry-standard tools.  

---

## Primary Objectives:  

- Simulate real-world attack and defense scenarios  
- Practice SOC analyst workflows and procedures  
- Develop threat detection and incident response skills  
- Gain hands-on experience with SIEM, IDS/IPS, and security tools  
- Build adversary emulation and red team capabilities  
- Implement Detection-as-Code (DaC) practices with CI/CD pipeline  
 
---

## Features  

- pfSense Firewall isolation to create a safe secluded environment  
- Detections as Code Pipeline  
- Vmware virtualization  
- Network Segmentation  

---

## Architecture  

<div align="center">
  <img src="/pfsense-firewall-lab/docs/Home_Lab_Network.drawio.png" alt="Network Architecture" style="width: 50%;">
</div>

### Infrastructure Overview

- Hypervisor: VMware Workstation/ESXi
- Network Firewall: pfSense
- Network Segmentation: 4 isolated VLANs
- Total VMs: 8 (with expansion planned)
- Detection Pipeline: GitHub Actions + Terraform + Sigma
- Self-Hosted Runner: Oracle Linux (CI/CD automation)

### Tools & Technologies

#### Security Information and Event Management (SIEM)
- **Splunk Enterprise** - Log aggregation, correlation, and analysis
- **Security Onion (Elastic Stack)** - Network-centric SIEM
#### Network Security Monitoring
- **Suricata** - Network IDS/IPS
- **Zeek** - Network traffic analyzer
- **Wireshark** - Full packet capture
#### Threat Intelligence & Emulation
- **MITRE Caldera** - Automated adversary emulation
- **MITRE ATT&CK Framework** - Adversary tactics and techniques
#### Detection Engineering & CI/CD
- **Sigma** - Universal detection rule format
- **GitHub Actions** - CI/CD automation platform
- **Terraform** - Infrastructure as Code
- **Self-Hosted Runner** - Local CI/CD execution environment
#### Endpoint Security
- **Sysmon** - Windows system monitoring
- **Splunk Universal Forwarder** - Log collection agent
#### Network Infrastructure
- **pfSense** - Firewall and router
- **VMware** - Virtualization platform
#### Penetration Testing
- **Kali Linux** - Comprehensive penetration testing platform
- **Metasploit Framework** - Exploitation framework
- **Burp Suite** - Web application security testing

---

## Documentation  

- [VMware Virtualization Lab](./virtualization-lab/)  
- [pfSense Firewall Lab](./pfsense-firewall-lab/)  
- [Splunk Detection Engineering Lab](./splunk-detection-engineering-lab/)  
- [Detections as Code Lab](https://github.com/Coded-Alchemy/Detections_as_Code)
- [Adversary Emulation Lab](./adversary-emulation-lab/)
- [Troubleshooting](./docs/Troubleshooting.md)

---

## Use Cases  

1. **Threat Detection & Response**
	- Real-time alert generation and analysis
	- SIEM rule creation and tuning
	- Incident investigation workflows
	- Threat hunting exercises
2. **Adversary Emulation**
	- Automated MITRE ATT&CK technique execution
	- Red team operation simulation
	- Detection engineering and validation
	- Purple team exercises
3. **Network Security Monitoring**
	- Full packet capture and analysis
	- Network traffic baseline establishment
	- Anomaly detection
	- Protocol analysis
4. **Detection-as-Code (DaC) Pipeline**
	- Automated detection deployment using Sigma rules
	- Version-controlled security detections in Git
	- CI/CD pipeline with GitHub Actions
	- Infrastructure as Code with Terraform
	- Automated testing and validation
	- Self-hosted runner for secure execution
5. **Malware Analysis**
	- Static and dynamic malware analysis
	- Behavioral analysis in isolated environment
	- Reverse engineering
	- Indicator of compromise (IOC) extraction
6. **Penetration Testing**
	- Network reconnaissance and scanning
	- Vulnerability assessment and exploitation
	- Web application testing
	- Password cracking and credential attacks
	- Post-exploitation and privilege escalation
---

## Skills Demonstrated  

- SIEM Administration - Splunk deployment and configuration  
- Network Security Monitoring - IDS/IPS implementation  
- Penetration Testing - Full attack lifecycle execution  
- Network Segmentation - VLAN design and firewall rules  
- Log Analysis - Threat detection and investigation  
- Adversary Emulation - MITRE ATT&CK framework  
- Virtualization - VMware infrastructure management  
- Endpoint Security - Sysmon and EDR concepts  
- Linux Administration - Oracle Linux and Kali systems  
- Windows Security - Hardening and monitoring  
- Detection Engineering - Sigma rule development  
- DevSecOps - CI/CD pipeline implementation  
- Infrastructure as Code - Terraform for security automation  
- Version Control - Git workflows and collaboration  
- Automation & Scripting - Python, Bash, GitHub Actions  

---

## Future Enhancements  
- Active Directory Lab
- SOAR Lab
- Malware Analysis Lab