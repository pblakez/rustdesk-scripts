# Requires PowerShell 7.0+
# This script must be run with Administrator privileges.
# src: act1-print-rustdesk-config.ps1
# this script is designed to run in action1 enviroment
# act1: print-rustdesk-config
# parameters: none

# Returns $true when the current session is running with Administrator rights.
function Test-IsAdmin {
    $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Polls the Rustdesk service, retrying Start-Service if stopped. Returns $true
# once it reaches Running, $false after MaxAttempts * DelaySeconds.
function Wait-RustDeskServiceRunning {
    param(
        [string]$ServiceName = 'Rustdesk',
        [int]$MaxAttempts = 12,
        [int]$DelaySeconds = 5
    )
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        Write-Host "RustDesk service is not registered."
        return $false
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

# Reads a RustDesk option via IPC. Returns '(not set)' when the option is empty.
function Get-RustDeskOption {
    param(
        [Parameter(Mandatory)][string]$ExePath,
        [Parameter(Mandatory)][string]$Key
    )
    # --option with 2 args reads via IPC and prints to stdout (src/core_main.rs).
    # Empty / unset options print an empty line.
    $out = (& $ExePath --option $Key | Out-String).Trim()
    if ([string]::IsNullOrEmpty($out)) { return '(not set)' }
    return $out
}

if (-not (Test-IsAdmin)) {
    Write-Host "ERROR: Administrator privileges required."
    exit 1
}

$rustdeskInstallPath = "$env:ProgramFiles\RustDesk"
$rustdeskExe = Join-Path $rustdeskInstallPath 'rustdesk.exe'
if (-not (Test-Path $rustdeskExe)) {
    Write-Host "RustDesk is not installed."
    exit 1
}

try {
    Set-Location -Path $rustdeskInstallPath

    # --get-id and --option both go over IPC, so the service must be running.
    if (-not (Wait-RustDeskServiceRunning)) {
        exit 1
    }

    $version      = (& $rustdeskExe --version | Out-String).Trim()
    $clientId     = (& $rustdeskExe --get-id | Out-String).Trim()
    $idServer     = Get-RustDeskOption -ExePath $rustdeskExe -Key 'custom-rendezvous-server'
    $relayServer  = Get-RustDeskOption -ExePath $rustdeskExe -Key 'relay-server'
    $apiServer    = Get-RustDeskOption -ExePath $rustdeskExe -Key 'api-server'
    $publicKey    = Get-RustDeskOption -ExePath $rustdeskExe -Key 'key'

    Write-Host ("Version: {0}" -f $(if ([string]::IsNullOrEmpty($version)) { '(unknown)' } else { $version }))
    Write-Host ("ID: {0}" -f $(if ([string]::IsNullOrEmpty($clientId)) { '(not set)' } else { $clientId }))
    Write-Host ("ID Server: {0}" -f $idServer)
    Write-Host ("Relay Server: {0}" -f $relayServer)
    Write-Host ("API Server: {0}" -f $apiServer)
    Write-Host ("Key: {0}" -f $publicKey)
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
}
