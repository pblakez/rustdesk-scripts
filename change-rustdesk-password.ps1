# Requires PowerShell 7.0+
# This script must be run with Administrator privileges.
# src: change-rustdesk-password.ps1
# this script is designed to run in action1 enviroment
# act1: attain-change-rustdesk-password
# parameters: password
# tested 2025-09-06 OK


#region User Configuration
# ==============================================================================
# EDIT THIS VARIABLE WITH YOUR NEW PERMANENT PASSWORD
# ==============================================================================
$rustdeskPermanentPassword = ${password} # "YourN3wS3cureP@ssw0rd!"
#endregion User Configuration

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
#endregion Helper Functions

#region Main Script
# ==============================================================================
# Script logic to update RustDesk's permanent password
# ==============================================================================

if (-not (Test-IsAdmin)) {
    Write-Host "ERROR: Administrator privileges required."
    exit 1
}

$rustdeskInstallPath = "$env:ProgramFiles\RustDesk"
if (-not (Test-Path (Join-Path $rustdeskInstallPath 'rustdesk.exe'))) {
    Write-Host "RustDesk is not installed. Nothing to update."
    exit 1
}

Write-Host "Updating RustDesk permanent password..."

try {
    # --password goes over IPC to the running service, so the service must be up.
    # If it's stopped, the password silently lands in the wrong profile.
    if (-not (Wait-RustDeskServiceRunning)) {
        exit 1
    }

    Set-Location -Path $rustdeskInstallPath
    & ".\rustdesk.exe" --password $rustdeskPermanentPassword

    Write-Host "Permanent password set successfully."
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
}

#endregion Main Script
