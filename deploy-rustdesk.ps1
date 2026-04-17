# Requires PowerShell 7.0+
# This script must be run with Administrator privileges.
# src: deploy-rustdesk.ps1
# this script is designed to run in action1 enviroment
# act1: attain-deploy-rustdesk
# parameters: id-server, relay-server, api-server, key, password
# note relay-server and api-server are optional parameters. Set them to a blank string ("") to not use Relay and API server.

#region User Configuration
# ==============================================================================
# EDIT THESE VARIABLES WITH YOUR SERVER DETAILS AND PASSWORD
# ==============================================================================
$rustdeskIdServer = ${id-server} #"your_id_server.example.com"
$rustdeskRelayServer = ${relay-server} # "your_relay_server.example.com" can be blank
$rustdeskApiServer = ${api-server} # Required for RustDesk Pro can be blank otherwise
$rustdeskKey = ${key} #"your_public_key"
$rustdeskPermanentPassword = ${password} #"YourS3cureP@ssw0rd!"

# Leave empty to auto-detect the latest version from GitHub.
# Set to a specific version (e.g., "1.4.1") to pin.
$rustdeskVersionOverride = ""
#endregion User Configuration

#region Helper Functions

function Test-IsAdmin {
    $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-RustDeskOption {
    param(
        [Parameter(Mandatory)][string]$ExePath,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )
    if ([string]::IsNullOrEmpty($Value)) {
        Start-Process -FilePath $ExePath -ArgumentList '--option', $Key, '""' -Wait -NoNewWindow
    } else {
        & $ExePath --option $Key $Value
    }
}

function Wait-RustDeskServiceRunning {
    param(
        [string]$InstallPath = "$env:ProgramFiles\RustDesk",
        [string]$ServiceName = 'Rustdesk',
        [int]$MaxAttempts = 12,
        [int]$DelaySeconds = 5,
        [switch]$InstallIfMissing
    )
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        if ($InstallIfMissing) {
            Write-Host "RustDesk service not registered. Installing service..."
            $exe = Join-Path $InstallPath 'rustdesk.exe'
            if (-not (Test-Path $exe)) {
                Write-Host "ERROR: rustdesk.exe not found at '$exe'."
                return $false
            }
            Start-Process -FilePath $exe -ArgumentList '--install-service' -Wait -NoNewWindow
            Start-Sleep -Seconds 5
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($null -eq $service) {
                Write-Host "ERROR: Failed to register RustDesk service."
                return $false
            }
        } else {
            Write-Host "RustDesk service is not registered."
            return $false
        }
    }
    for ($i = 0; $i -lt $MaxAttempts; $i++) {
        $service.Refresh()
        if ($service.Status -eq 'Running') { return $true }
        try { Start-Service -Name $ServiceName -ErrorAction Stop } catch { }
        Start-Sleep -Seconds $DelaySeconds
    }
    Write-Host ("RustDesk service did not start within {0} seconds." -f ($MaxAttempts * $DelaySeconds))
    return $false
}

function Get-LatestRustDeskRelease {
    param(
        [ValidateSet('exe', 'msi')]
        [string]$InstallerType = 'exe'
    )
    $suffix = "x86_64.$InstallerType"
    try {
        $response = Invoke-RestMethod -Uri 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest' -TimeoutSec 30
    } catch {
        Write-Host "ERROR: Failed to fetch latest RustDesk release from GitHub: $($_.Exception.Message)"
        return $null
    }
    $version = ($response.tag_name -replace '^v', '').Trim()
    $asset = $response.assets | Where-Object { $_.name -like "*$suffix" } | Select-Object -First 1
    if (-not $asset) {
        Write-Host "ERROR: No $suffix asset found in release $version."
        return $null
    }
    return @{
        Version     = $version
        DownloadUrl = $asset.browser_download_url
    }
}

function Invoke-DownloadWithRetry {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$OutFile,
        [int]$MaxAttempts = 3,
        [int]$RetryDelaySeconds = 5,
        [int]$TimeoutSec = 300
    )
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -TimeoutSec $TimeoutSec
            return
        } catch {
            if ($attempt -eq $MaxAttempts) { throw }
            Write-Host "Download attempt $attempt failed: $_"
            Write-Host "Retrying in $RetryDelaySeconds seconds..."
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
}

#endregion Helper Functions

#region Main Script
# ==============================================================================
# Script logic to download, install, and configure RustDesk
# ==============================================================================

if (-not (Test-IsAdmin)) {
    Write-Host "ERROR: Administrator privileges required."
    exit 1
}

$rustdeskInstallPath = "$env:ProgramFiles\RustDesk"
$installerPath = "$env:TEMP\rustdesk-installer.exe"

# ---------------------------------------------------------------------------
# A1: Resolve target version — GitHub API or pinned override
# ---------------------------------------------------------------------------
if ($rustdeskVersionOverride) {
    $targetVersion = $rustdeskVersionOverride
    $installerUrl = "https://github.com/rustdesk/rustdesk/releases/download/$targetVersion/rustdesk-$targetVersion-x86_64.exe"
    Write-Host "Using pinned version: $targetVersion"
} else {
    Write-Host "Fetching latest RustDesk release from GitHub..."
    $release = Get-LatestRustDeskRelease -InstallerType 'exe'
    if (-not $release) {
        Write-Host "ERROR: Could not determine latest version. Set \$rustdeskVersionOverride to pin a version."
        exit 1
    }
    $targetVersion = $release.Version
    $installerUrl = $release.DownloadUrl
    Write-Host "Latest version: $targetVersion"
}

# ---------------------------------------------------------------------------
# A2: Skip install if already at or above the target version
# ---------------------------------------------------------------------------
$installedVersion = $null
try {
    $installedVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk\" -ErrorAction SilentlyContinue).Version
} catch { }

$skipInstall = $false
if ($installedVersion) {
    try {
        if ([version]$installedVersion -ge [version]$targetVersion) {
            Write-Host "RustDesk $installedVersion is already installed. Skipping download and installation."
            $skipInstall = $true
        } else {
            Write-Host "RustDesk $installedVersion installed, upgrading to $targetVersion..."
        }
    } catch {
        Write-Host "Could not compare versions ($installedVersion vs $targetVersion). Proceeding with install."
    }
} else {
    Write-Host "RustDesk not currently installed."
}

# ---------------------------------------------------------------------------
# Download and install (skipped if already current)
# ---------------------------------------------------------------------------
if (-not $skipInstall) {
    try {
        Write-Host "Downloading RustDesk installer from $installerUrl..."
        Invoke-DownloadWithRetry -Uri $installerUrl -OutFile $installerPath
    } catch {
        Write-Host "ERROR: Failed to download the RustDesk installer: $($_.Exception.Message)"
        exit 1
    }

    try {
        Write-Host "Starting silent installation..."
        Start-Process -FilePath $installerPath -ArgumentList "--silent-install" -Wait -NoNewWindow
        Write-Host "Installation completed."
    } catch {
        Write-Host "ERROR: RustDesk installation failed: $($_.Exception.Message)"
        exit 1
    }

    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Configure (always runs — Action1 may be pushing new server details)
# ---------------------------------------------------------------------------
try {
    Set-Location -Path $rustdeskInstallPath

    if (-not (Wait-RustDeskServiceRunning -InstallPath $rustdeskInstallPath -InstallIfMissing)) {
        exit 1
    }

    Write-Host "Applying server options..."
    $rustdeskExe = Join-Path $rustdeskInstallPath 'rustdesk.exe'
    Set-RustDeskOption -ExePath $rustdeskExe -Key 'custom-rendezvous-server' -Value $rustdeskIdServer
    Set-RustDeskOption -ExePath $rustdeskExe -Key 'relay-server' -Value $rustdeskRelayServer
    Set-RustDeskOption -ExePath $rustdeskExe -Key 'api-server' -Value $rustdeskApiServer
    Set-RustDeskOption -ExePath $rustdeskExe -Key 'key' -Value $rustdeskKey

    & ".\rustdesk.exe" --password $rustdeskPermanentPassword

    $clientId = (& ".\rustdesk.exe" --get-id | Out-String).Trim()
    if ($clientId) {
        Write-Host "ID: $clientId"
    } else {
        Write-Host "WARNING: Failed to retrieve the RustDesk client ID."
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
}

#endregion Main Script
