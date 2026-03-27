<div align="center">

# Linux Splunk Universal Forwarder Deployment

### Enterprise Log Ingestion Pipeline | Home SOC Lab

</div>

---

# Overview

This project documents the deployment and configuration of the Splunk Universal Forwarder on Linux hosts within a 
simulated enterprise SOC environment.

Goal: build a **reliable, scalable log ingestion pipeline** streaming Linux telemetry into a centralized SIEM for 
detection engineering and threat hunting.

---

# Enterprise Architecture

## High-Level Diagram

```mermaid
flowchart LR
    A[Linux Host\nUniversal Forwarder] -->|Syslog + Audit Logs| B[Splunk Indexer]
    B --> C[Splunk Search Head]
    C --> D[Security Analyst]
```

---

## Detailed Security Architecture

```mermaid
flowchart TB

    subgraph Linux_Endpoint
        UF[Universal Forwarder]
        SYSLOG[/var/log/*]
        AUTH[/var/log/auth.log]
        AUDIT[auditd Logs]
    end

    subgraph Network
        FW[Firewall\nPort 9997]
    end

    subgraph Splunk
        IDX[Indexer\nStorage & Parsing]
        SH[Search Head\nDashboards & Detections]
    end

    SYSLOG --> UF
    AUTH --> UF
    AUDIT --> UF
    UF --> FW
    FW --> IDX
    IDX --> SH
```

---

# Prerequisites

* Linux host (Ubuntu, Debian, RHEL, Fedora, etc.)
* Splunk Indexer reachable
* Port **9997** open on indexer
* Root/sudo privileges
* auditd (recommended)

---

# Installation

## 1. Download

```bash
wget https://download.splunk.com/products/universalforwarder/releases/<VERSION>/linux/splunkforwarder-<VERSION>-Linux-x86_64.tgz
```

---

## 2. Install

```bash
tar -xvf splunkforwarder-*.tgz -C /opt
```

---

## 3. Enable Boot Start

```bash
sudo /opt/splunkforwarder/bin/splunk enable boot-start
```

---

## 4. Start Forwarder

```bash
sudo /opt/splunkforwarder/bin/splunk start --accept-license
```

---

# Configuration

## outputs.conf

```ini
[tcpout]
defaultGroup = indexer_group

[tcpout:indexer_group]
server = <INDEXER_IP>:9997
```

---

## inputs.conf

### System Logs

```ini
[monitor:///var/log/syslog]
index = linux

[monitor:///var/log/auth.log]
index = linux
```

### Auditd Logs (Recommended)

```ini
[monitor:///var/log/audit/audit.log]
index = linux_audit
```

---

## Apply Config & Restart

```bash
sudo /opt/splunkforwarder/bin/splunk restart
```

---

# Verification

## On Forwarder

```bash
/opt/splunkforwarder/bin/splunk list forward-server
```

Expected:

```
Active forwards:
    <INDEXER_IP>:9997
```

---

## On Splunk

```spl
index=linux
```

```spl
index=linux_audit
```

---

# Troubleshooting

## No Logs Appearing

* File path incorrect
* Permissions on /var/log
* Forwarder not running

---

## Forwarder Not Connecting

```bash
splunk list forward-server
```

* outputs.conf misconfigured
* Firewall blocking 9997

---

## Permission Issues

* Use sudo/root
* Ensure forwarder can read log files

---

# Security Considerations

* Use SSL (tcpout:ssl)
* Restrict indexer ports
* Run forwarder as least-privileged user where possible

---

# Skills Demonstrated

* Linux Log Ingestion
* SIEM Engineering
* Log Pipeline Design
* auditd Monitoring
* Troubleshooting & Debugging
* Detection Engineering Foundations

---

# Key Takeaway

This project demonstrates the ability to deploy and operate a **production-style Linux logging pipeline**, feeding 
high-value telemetry into a SIEM for real-world security operations.

---

<div align="center">

### 🛡️ Built for Detection Engineering & SOC Excellence

</div>


-------
As of Splunk 9.1, the universal forwarder installs a new least privileged user called splunkfwd. This means that the 
user name for Splunk Enterprise, "Splunk", and your universal forwarder user name, "splunkfwd", will be different. Its 
recommend that you implement the splunkfwd user, however, if your system requires that your Splunk Enterprise and 
universal forwarder names be identical, see Manage a Linux least-privileged user in this manual.

1. Login as ROOT to the machine on which you want to install the universal forwarder.

2. Create the Splunk user and group.
	`useradd -m splunkfwd`
	`groupadd splunk`

3. Install the Splunk software, as described in the installation instructions for your platform in Installation 
4. instructions. Create the $SPLUNK_HOME directory wherever desired.
	`export SPLUNK_HOME="/opt/splunkforwarder"`
	`mkdir $SPLUNK_HOME`

4. Make sure the splunkforwarder package is present in $SPLUNK_HOME
	wget -O splunkforwarder-10.2.1-c892b66d163d-linux-amd64.tgz "https://download.splunk.com/products/universalforwarder/releases/10.2.1/linux/splunkforwarder-10.2.1-c892b66d163d-linux-amd64.tgz"
	`tar xvzf splunkforwarder_package_name.tgz`

5. Run the chown command to change the ownership of the splunk directory and everything under it to the user that will 
6. run the software.
	`chown -R splunkfwd:splunkfwd $SPLUNK_HOME`

6. Switch to ROOT or SUDO and run
	`sudo $SPLUNK_HOME/bin/splunk start --accept-license`
	`sudo ./splunk enable boot-start`

For post-installation configuration and credential creation, see  [Configure the universal forwarder](https://help.splunk.com/en/splunk-enterprise/forward-and-process-data/universal-forwarder-manual/9.4/configure-the-universal-forwarder/enable-a-receiver-for-splunk-enterprise#id_8dd83488_23ef_4bc4_94ee_d4ca8aa9cfeb--en__Enable_a_receiver_for_Splunk_Enterprise).

User name = splunkfwd

## Connect to indexer
`./splunk add forward-server 192.168.10.100:9997`

## Connect to deployment server
`./splunk set deploy-poll 192.168.10.106:8089`




