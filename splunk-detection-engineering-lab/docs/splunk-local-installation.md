# Splunk Enterprise — Local SIEM Installation on Oracle Linux 10

> A step-by-step guide documenting the local installation and configuration of Splunk Enterprise as a Security Information and Event Management (SIEM) solution on Oracle Linux 10.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Environment Specs](#environment-specs)
- [Installation](#installation)
- [Initial Configuration](#initial-configuration)
- [Configuring Splunk as a SIEM](#configuring-splunk-as-a-siem)
- [Universal Forwarder Setup](#universal-forwarder-setup)
- [Use Cases & Searches](#use-cases--searches)
- [Screenshots](#screenshots)
- [Lessons Learned](#lessons-learned)
- [References](#references)

---

## Overview

This project documents the local deployment of **Splunk Enterprise** on **Oracle Linux 10** for use as a home lab SIEM. The goal is to simulate a real-world security monitoring environment — ingesting system logs, detecting threats, and building dashboards to visualize security events.

**Key capabilities demonstrated:**
- Centralized log collection from Linux hosts
- Real-time security event monitoring
- Custom SPL (Search Processing Language) queries for threat detection
- Alerting on suspicious activity
- Dashboard creation for SOC-style visibility

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| OS | Oracle Linux 10 (x86_64) |
| RAM | 8 GB minimum (16 GB recommended) |
| Disk | 20 GB+ free space |
| CPU | 2+ cores |
| Network | Static IP or hostname configured |
| Account | Free Splunk developer account at [splunk.com](https://www.splunk.com) |

Ensure the following packages are installed before proceeding:

```bash
sudo dnf install -y wget curl net-tools
```

---

## Environment Specs

```
Host OS:      Oracle Linux 10
Splunk Ver:   Splunk Enterprise 9.x
Architecture: x86_64
Hostname:     splunk-lab
IP Address:   192.168.x.x  (update with your static IP)
Web UI Port:  8000
```

---

## Installation

### 1. Download Splunk Enterprise

Download the `.rpm` package directly from Splunk's website. Replace the URL with the latest version from your [Splunk account downloads page](https://www.splunk.com/en_us/download/splunk-enterprise.html).

```bash
wget -O splunk-enterprise.rpm 'https://download.splunk.com/products/splunk/releases/<VERSION>/linux/splunk-<VERSION>-linux-2.6-x86_64.rpm'
```

> **Tip:** Log in to splunk.com and copy the direct download link from the Linux RPM option.

### 2. Install the RPM Package

```bash
sudo rpm -ivh splunk-enterprise.rpm
```

Splunk installs to `/opt/splunk` by default.

### 3. Start Splunk & Accept License

```bash
sudo /opt/splunk/bin/splunk start --accept-license
```

You will be prompted to create an **admin username and password** on first launch.

### 4. Enable Splunk to Start on Boot

```bash
sudo /opt/splunk/bin/splunk enable boot-start
```

### 5. Open Firewall Port for Web UI

```bash
sudo firewall-cmd --permanent --add-port=8000/tcp
sudo firewall-cmd --reload
```

### 6. Verify Splunk is Running

```bash
sudo /opt/splunk/bin/splunk status
```

---

## Initial Configuration

### Access the Web Interface

Open a browser and navigate to:

```
http://<your-ip>:8000
```

Log in with the admin credentials you created during installation.

<!-- SCREENSHOT PLACEHOLDER -->
> 📸 **[Screenshot: Splunk Login Page]**

---

### Set the Time Zone

1. Navigate to **Settings → Server Settings → General Settings**
2. Set your local time zone
3. Click **Save**

### Configure Receiving (Listening for Data)

To allow Splunk to receive forwarded data:

1. Go to **Settings → Forwarding and Receiving**
2. Click **Configure Receiving → New Receiving Port**
3. Enter port `9997` and save

```bash
# Alternatively, configure via CLI
sudo /opt/splunk/bin/splunk enable listen 9997 -auth admin:<password>
```

```bash
# Open the receiver port in the firewall
sudo firewall-cmd --permanent --add-port=9997/tcp
sudo firewall-cmd --reload
```

<!-- SCREENSHOT PLACEHOLDER -->
> 📸 **[Screenshot: Receiving Port Configuration]**

---

## Configuring Splunk as a SIEM

### Add Local Log Inputs

Monitor critical Linux security logs by adding data inputs.

1. Navigate to **Settings → Data Inputs → Files & Directories**
2. Click **New** and add the following paths:

| Log Path | Purpose |
|----------|---------|
| `/var/log/secure` | SSH logins, sudo usage, auth events |
| `/var/log/messages` | General system messages |
| `/var/log/audit/audit.log` | Linux auditd events |
| `/var/log/dnf.log` | Package installation activity |
| `/var/log/wtmp` (via script) | Login history |

**Example CLI method:**

```bash
sudo /opt/splunk/bin/splunk add monitor /var/log/secure -index main -sourcetype linux_secure
sudo /opt/splunk/bin/splunk add monitor /var/log/messages -index main -sourcetype syslog
sudo /opt/splunk/bin/splunk add monitor /var/log/audit/audit.log -index main -sourcetype linux_audit
```

<!-- SCREENSHOT PLACEHOLDER -->
> 📸 **[Screenshot: Data Inputs — Files & Directories]**

---

### Create a Dedicated Security Index

```bash
sudo /opt/splunk/bin/splunk add index security_events
```

Or via UI: **Settings → Indexes → New Index** → Name: `security_events`

---

### Install Splunk Security Essentials App (Optional)

1. Go to **Apps → Find More Apps**
2. Search for **Splunk Security Essentials**
3. Install and restart Splunk

This app provides pre-built security detections and use case frameworks.

<!-- SCREENSHOT PLACEHOLDER -->
> 📸 **[Screenshot: Splunk Security Essentials Dashboard]**

---

## Universal Forwarder Setup

To ingest logs from additional machines, install the **Splunk Universal Forwarder** on each host.

### On the Forwarder Host (Linux)

```bash
# Download Universal Forwarder RPM
wget -O splunkforwarder.rpm 'https://download.splunk.com/products/universalforwarder/releases/<VERSION>/linux/splunkforwarder-<VERSION>-linux-2.6-x86_64.rpm'

sudo rpm -ivh splunkforwarder.rpm
sudo /opt/splunkforwarder/bin/splunk start --accept-license

# Point forwarder to your Splunk indexer
sudo /opt/splunkforwarder/bin/splunk add forward-server <SPLUNK_IP>:9997 -auth admin:<password>

# Add logs to forward
sudo /opt/splunkforwarder/bin/splunk add monitor /var/log/secure
sudo /opt/splunkforwarder/bin/splunk add monitor /var/log/messages
```

<!-- SCREENSHOT PLACEHOLDER -->
> 📸 **[Screenshot: Forwarder Confirmed in Splunk — Settings → Forwarder Management]**

---

## Use Cases & Searches

### 1. Detect Failed SSH Login Attempts

```spl
index=main sourcetype=linux_secure "Failed password"
| stats count by src_ip, user
| sort -count
| where count > 5
```

> Identifies brute-force SSH attempts by counting failures per source IP.

<!-- SCREENSHOT PLACEHOLDER -->
> 📸 **[Screenshot: Failed SSH Logins Search Results]**

---

### 2. Successful Logins After Multiple Failures (Credential Stuffing)

```spl
index=main sourcetype=linux_secure
| eval status=if(match(_raw,"Failed password"),"failure","success")
| stats count(eval(status="failure")) as failures, count(eval(status="success")) as successes by src_ip, user
| where failures > 5 AND successes > 0
```

> Flags accounts that had repeated failures followed by a success — a common sign of a compromised credential.

---

### 3. Sudo Privilege Escalation Events

```spl
index=main sourcetype=linux_secure "sudo"
| rex field=_raw "sudo:\s+(?<user>\w+)\s.*COMMAND=(?<command>.+)"
| table _time, host, user, command
| sort -_time
```

> Tracks which users ran sudo commands and what they executed.

---

### 4. New User Account Created

```spl
index=main sourcetype=linux_secure "new user"
| rex field=_raw "new user: name=(?<username>\w+)"
| table _time, host, username
```

> Alerts on user account creation — useful for detecting persistence mechanisms.

---

### 5. Unauthorized Package Installation

```spl
index=main sourcetype=syslog "dnf" OR "rpm" "installed"
| table _time, host, _raw
| sort -_time
```

> Monitors for software installations that could indicate malicious activity.

---

### 6. Top Talkers — Most Active Source IPs

```spl
index=main sourcetype=linux_secure
| stats count by src_ip
| sort -count
| head 10
```

---

### Setting Up an Alert (Failed Logins Example)

1. Run the failed SSH search above
2. Click **Save As → Alert**
3. Configure:
   - **Title:** `Brute Force SSH Detected`
   - **Alert Type:** Scheduled (every 15 minutes)
   - **Trigger Condition:** Number of results > 10
   - **Action:** Send email / log to index

<!-- SCREENSHOT PLACEHOLDER -->
> 📸 **[Screenshot: Alert Configuration Panel]**

---

### Building a Security Dashboard

1. Go to **Dashboards → Create New Dashboard**
2. Name it: `Security Overview`
3. Add panels using the searches above:
   - Failed Logins Over Time (line chart)
   - Top Source IPs (bar chart)
   - Recent Sudo Events (table)
   - New Users Created (single value)

<!-- SCREENSHOT PLACEHOLDER -->
> 📸 **[Screenshot: Security Overview Dashboard]**

---

## Screenshots

| # | Description |
|---|-------------|
| 1 | Splunk Web Login Page |
| 2 | Receiving Port Configuration |
| 3 | Data Inputs — Files & Directories |
| 4 | Security Essentials App Dashboard |
| 5 | Forwarder Management Page |
| 6 | Failed SSH Logins Search |
| 7 | Alert Configuration Panel |
| 8 | Security Overview Dashboard |

> 📝 *Screenshots to be added after lab environment is fully configured.*

---

## Lessons Learned

- **SELinux** on Oracle Linux may block Splunk from reading certain log files. Use `audit2allow` or temporarily set SELinux to permissive mode for testing:
  ```bash
  sudo setenforce 0  # Permissive (testing only)
  ```
- The `/var/log/secure` file requires elevated permissions — run Splunk as root or adjust file ACLs.
- Splunk's free trial license limits daily ingestion to **500 MB/day**, which is sufficient for a home lab.
- SPL (Search Processing Language) is powerful but has a learning curve — the [Splunk Search Tutorial](https://docs.splunk.com/Documentation/Splunk/latest/SearchTutorial/WelcometotheSearchTutorial) is a great starting point.

---

## References

- [Splunk Enterprise Documentation](https://docs.splunk.com/Documentation/Splunk)
- [Splunk Security Essentials](https://splunkbase.splunk.com/app/3435)
- [SPL Search Reference](https://docs.splunk.com/Documentation/Splunk/latest/SearchReference/WhatsInThisManual)
- [Oracle Linux 10 Documentation](https://docs.oracle.com/en/operating-systems/oracle-linux/10/)
- [Splunk Universal Forwarder](https://docs.splunk.com/Documentation/Forwarder/latest/Forwarder/Abouttheuniversalforwarder)

---

*Built as part of a personal cybersecurity home lab portfolio. All configurations were performed in an isolated local environment.*
