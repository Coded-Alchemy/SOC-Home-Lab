# VMware Virtualization Infrastructure 


<div align="center">

**Virtualization Architecture for a Security Engineering Home Lab**

Compute • Networking • VM Design • Infrastructure Segmentation

</div>
---
## Overview

This project documents the **VMware virtualization infrastructure** that powers my cybersecurity home lab.

The environment simulates a **small enterprise virtualization stack** used to host security tooling, endpoint systems, and attack simulation environments. The goal is to provide a **stable and scalable virtual infrastructure** for:

- Security monitoring environments
- Detection engineering labs
- Attack simulation exercises
- SOC workflow testing
- Network security experimentation

The VMware platform serves as the **foundation layer for all lab infrastructure**.

---
## Virtualization Platform  
  
Hypervisor: VMware Workstation / ESXi  
Host OS: Fedora Linux  
CPU: 16 vCPUs  
RAM: 64GB  
Storage: 1.5TB SSD  

---
## Virtualization Architecture
<div align="center">
  <img src="docs/virtualization_arch.svg" alt="Virtualization Architecture Diagram" style="width: 100%;">
</div>

---
## Virtual Machine Inventory 
  
| VM Name         | OS                       | Purpose                              | RAM  | Network |
| --------------- | ------------------------ | ------------------------------------ | ---- | ------- |
| pfSense         | FreeBSD                  | Firewall & routing                   | 2GB  | WAN/LAN |
| Splunk          | Oracle Linux Server 10.1 | SIEM & log analysis                  | 16GB | LAN     |
| WIN10           | Windows 10               | Target machine / Endpoint telemetry  | 2GB  | LAN     |
| Kali            | Kali Linux               | Attack simulation                    | 4GB  | LAN     |
| Deployment      | Ubuntu Server 24.04 LTS  | Splunk Deployment Server             | 8GB  | LAN     |
| Security Onion  | Oracle Linux 9           | Threat Hunting                       | 8GB  | LAN     |
| Metasploitable2 | Ubuntu Linux             | Target Machine / Penetration Testing | 8GB  | LAN     |
| REMnux          | Ubuntu 20.04 LTS         | Malware analysis                     | 8GB  | LAN     |
| Kali Purple     | Kali Linux               | Purple Teaming                       | 6GB  | Lan     |

---
## Network Segmentation

The lab is divided into multiple virtual networks.


| Network | Purpose                                                        |
| ------- | -------------------------------------------------------------- |
| WAN     | External network                                               |
| LAN     | Internal monitoring network / Splunk                           |
| ATTACK  | Kali attacker network / Red Team exercises                     |
| Target  | Target machine network / adversary emulation                   |
| Malware | REMnux malware analysis network / isolated malware environment |

---
## Resource Allocation Strategy

The virtualization environment is designed to balance **performance and host stability**.

| Resource   | Strategy                                   |
| ---------- | ------------------------------------------ |
| CPU        | Shared across VMs using VMware scheduler   |
| Memory     | Allocated per VM with headroom for host OS |
| Storage    | SSD-backed virtual disks                   |
| Networking | Segmented virtual switches                 |

This configuration allows multiple **security workloads to run simultaneously** without exhausting host resources.

---
## VM Lifecycle Management

Virtual machines are managed using standard VMware workflows.

Operations include:

- VM snapshotting before attack simulations
- rapid environment rollback
- cloning systems for testing
- controlled resource allocation

Snapshots allow the lab to **quickly reset environments after adversary testing**.

---
## Use Cases Enabled by the Virtualization Platform

The VMware infrastructure supports multiple security engineering scenarios.

### Detection Engineering

Deploy systems that generate realistic telemetry for detection development.

### Attack Simulation

Execute controlled offensive techniques against lab endpoints.

### SOC Workflow Testing

Simulate alerts, log ingestion, and response workflows.

### Infrastructure Experimentation

Rapidly deploy and destroy lab environments for testing.