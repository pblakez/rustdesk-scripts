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
#endregion Helper Functions

#region Main Script
# ==============================================================================
# Script logic to update RustDesk's permanent password
# ==============================================================================

if (-not (Test-IsAdmin)) {
    Write-Error "This script must be run with Administrator privileges. Please right-click and 'Run as Administrator'."
    exit
}

Write-Host "Updating RustDesk permanent password..."

try {
    # Define the installation path. This is the default path for a system-wide installation.
    $rustdeskInstallPath = "$env:ProgramFiles\RustDesk"

    # Check if the installation directory exists
    if (-not (Test-Path $rustdeskInstallPath)) {
        Write-Error "RustDesk installation not found at '$rustdeskInstallPath'. Please ensure RustDesk is installed."
        exit
    }

    # --password goes over IPC to the running service, so the service must be up.
    # If it's stopped, the password silently lands in the wrong profile.
    if (-not (Wait-RustDeskServiceRunning)) {
        Write-Error "RustDesk service did not reach a running state. Aborting password change."
        exit
    }

    # Set the location to the installation directory
    Set-Location -Path $rustdeskInstallPath

    # Execute the RustDesk executable with the --password flag to set the new permanent password
    & ".\rustdesk.exe" --password $rustdeskPermanentPassword

    Write-Host "Permanent password set successfully."
}
catch {
    Write-Error "Failed to update RustDesk password."
    Write-Error $_.Exception.Message
    exit
}

Write-Host "Script finished."

#endregion Main Script
