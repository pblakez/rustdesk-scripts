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

    # Set the location to the installation directory
    Set-Location -Path $rustdeskInstallPath

    # Execute the RustDesk executable with the --password flag to set the new permanent password
    & ".\rustdesk.exe" --password $rustdeskPermanentPassword

    Write-Host "Permanent password set successfully."
    Write-Host "You may need to restart the RustDesk service or client for changes to take effect."
}
catch {
    Write-Error "Failed to update RustDesk password."
    Write-Error $_.Exception.Message
    exit
}

Write-Host "Script finished."

#endregion Main Script
