# Requires PowerShell 7.0+
# This script must be run with Administrator privileges.
# src: print-rustdesk-config.ps1
# this script is designed to run in action1 enviroment
# act1: attain-print-rustdesk-config
# parameters: none

#region Helper Functions
# ==============================================================================
# Helper function to check for administrator privileges
# ==============================================================================
function Test-IsAdmin {
    $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Wait-RustDeskServiceRunning {
    param(
        [string]$ServiceName = 'Rustdesk',
        [int]$MaxAttempts = 12,
        [int]$DelaySeconds = 5
    )
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        Write-Error "RustDesk service not registered. Is RustDesk installed?"
        return $false
    }
    for ($i = 0; $i -lt $MaxAttempts; $i++) {
        $service.Refresh()
        if ($service.Status -eq 'Running') { return $true }
        try { Start-Service -Name $ServiceName -ErrorAction Stop } catch { }
        Start-Sleep -Seconds $DelaySeconds
    }
    Write-Error ("RustDesk service did not reach 'Running' state within {0} seconds." -f ($MaxAttempts * $DelaySeconds))
    return $false
}

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
#endregion Helper Functions

#region Main Script
# ==============================================================================
# Script logic to read and print the current RustDesk configuration
# ==============================================================================

if (-not (Test-IsAdmin)) {
    Write-Error "This script must be run with Administrator privileges. Please right-click and 'Run as Administrator'."
    exit
}

try {
    # rustdesk.exe must be invoked from its installation directory so that
    # is_installed() passes inside the binary.
    $rustdeskInstallPath = "$env:ProgramFiles\RustDesk"
    $rustdeskExe = Join-Path $rustdeskInstallPath 'rustdesk.exe'
    if (-not (Test-Path $rustdeskExe)) {
        Write-Error "RustDesk not found at '$rustdeskInstallPath'. Please ensure RustDesk is installed."
        exit
    }
    Set-Location -Path $rustdeskInstallPath

    # --get-id and --option both go over IPC, so the service must be running.
    if (-not (Wait-RustDeskServiceRunning)) {
        Write-Error "RustDesk service did not reach a running state. Aborting."
        exit
    }

    $clientId     = (& $rustdeskExe --get-id | Out-String).Trim()
    $idServer     = Get-RustDeskOption -ExePath $rustdeskExe -Key 'custom-rendezvous-server'
    $relayServer  = Get-RustDeskOption -ExePath $rustdeskExe -Key 'relay-server'
    $apiServer    = Get-RustDeskOption -ExePath $rustdeskExe -Key 'api-server'
    $publicKey    = Get-RustDeskOption -ExePath $rustdeskExe -Key 'key'

    Write-Host ("ID: {0}" -f $(if ([string]::IsNullOrEmpty($clientId)) { '(not set)' } else { $clientId }))
    Write-Host ("ID Server: {0}" -f $idServer)
    Write-Host ("Relay Server: {0}" -f $relayServer)
    Write-Host ("API Server: {0}" -f $apiServer)
    Write-Host ("Key: {0}" -f $publicKey)
}
catch {
    Write-Error "Failed to read RustDesk configuration."
    Write-Error $_.Exception.Message
    exit
}

#endregion Main Script
