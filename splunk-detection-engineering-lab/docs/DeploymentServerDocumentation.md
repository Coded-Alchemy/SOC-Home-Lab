# Splunk Deployment Server App Distribution (Linux + Windows + Sysmon)

## Overview

This document describes the configuration of a Splunk Deployment Server used to centrally distribute apps and 
configurations to Universal Forwarders in a SOC lab environment.

The deployment server pushes configuration apps to both Linux and Windows systems using server classes.

---

## Environment

|Component|Role|
|---|---|
|Splunk Server|Deployment Server|
|Linux Hosts|Universal Forwarder collecting Linux logs|
|Windows Hosts|Universal Forwarder collecting Windows event logs|
|Sysmon|Advanced Windows telemetry collection|

---

## Deployment Server Directory Structure

Deployment apps are stored in:

```
/opt/splunk/etc/deployment-apps/
```

Structure:

```
deployment-apps/
│
├── TA_base_forwarder
│   └── default/
│       └── outputs.conf
│
├── TA_linux_logs
│   └── default/
│       └── inputs.conf
│
├── TA_windows_logs
│   └── default/
│       └── inputs.conf
│
├── TA_sysmon_logs
│   └── default/
│       └── inputs.conf
```

Each app contains configuration files used by the Universal Forwarder.

---

## Base Forwarder Configuration

File:

```
TA_base_forwarder/default/outputs.conf
```

Purpose: Send all logs to the indexer.

```
[tcpout]
defaultGroup = indexers

[tcpout:indexers]
server = <INDEXER_IP>:9997
autoLB = true
```

---

## Linux Log Collection

File:

```
TA_linux_logs/default/inputs.conf
```

Example configuration:

```
[monitor:///var/log/syslog]
index = linux
sourcetype = syslog

[monitor:///var/log/auth.log]
index = linux
sourcetype = linux_secure
```

---

## Windows Event Log Collection

File:

```
TA_windows_logs/default/inputs.conf
```

Example:

```
[WinEventLog://Security]
index = windows

[WinEventLog://System]
index = windows

[WinEventLog://Application]
index = windows
```

---

## Sysmon Log Collection

Sysmon logs provide enhanced telemetry for security monitoring.

Configuration file:

```
TA_sysmon_logs/default/inputs.conf
```

Example:

```
[WinEventLog://Microsoft-Windows-Sysmon/Operational]
index = windows
disabled = false
```

---

## Deployment Server Configuration

File location:

```
/opt/splunk/etc/system/local/serverclass.conf
```

Configuration:

```
###################################################
# Base Forwarder App (All Systems)
###################################################

[serverClass:all_forwarders]
whitelist.0 = *

[serverClass:all_forwarders:app:TA_base_forwarder]

###################################################
# Linux Systems
###################################################

[serverClass:linux_servers]
whitelist.0 = linux*
whitelist.1 = ubuntu*

[serverClass:linux_servers:app:TA_linux_logs]

###################################################
# Windows Systems
###################################################

[serverClass:windows_servers]
whitelist.0 = win*
whitelist.1 = windows*

[serverClass:windows_servers:app:TA_windows_logs]

###################################################
# Windows Systems with Sysmon
###################################################

[serverClass:windows_sysmon]

whitelist.0 = win*
whitelist.1 = windows*

[serverClass:windows_sysmon:app:TA_sysmon_logs]
```

---

## Deployment Server Commands

Reload deployment configuration:

```
/opt/splunk/bin/splunk reload deploy-server
```

List connected deployment clients:

```
/opt/splunk/bin/splunk list deploy-clients
```

---

## Forwarder Commands

Verify deployment server connection:

```
/opt/splunkforwarder/bin/splunk list deploy-poll
```

Force forwarder to check for new apps:

```
/opt/splunkforwarder/bin/splunk reload deploy-client
```

Restart forwarder:

```
/opt/splunkforwarder/bin/splunk restart
```

---

## Troubleshooting

Common issues that prevent app deployment:

1. Hostname does not match server class whitelist.
    
2. Deployment server not reloaded after configuration changes.
    
3. Forwarder not connected to deployment server.
    
4. App missing configuration files (empty apps will not deploy).
    
5. Incorrect permissions on deployment-apps directory.
    

---

## Verification

On Linux forwarders:

```
ls /opt/splunkforwarder/etc/apps
```

On Windows forwarders:

```
C:\Program Files\SplunkUniversalForwarder\etc\apps
```

Expected apps:

```
TA_base_forwarder
TA_linux_logs
TA_windows_logs
TA_sysmon_logs
```

---

## Outcome

The deployment server successfully distributes configuration apps to Linux and Windows forwarders, enabling centralized 
log collection and security telemetry ingestion for the SOC lab environment.