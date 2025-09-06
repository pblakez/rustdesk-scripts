# Requires PowerShell 7.0+
# This script must be run with Administrator privileges.
# src: update-rustdesk-config.ps1
# this script is designed to run in action1 enviroment
# act1: attain-update-rustdesk-config
# parameters: id-server, relay-server, api-server, key


#region User Configuration
# ==============================================================================
# EDIT THESE VARIABLES WITH YOUR NEW SERVER DETAILS
# ==============================================================================
$rustdeskIdServer = ${id-server}
$rustdeskRelayServer = ${relay-server} # This parameter is optional. Set it to a blank string ("") to not use an API server.
$rustdeskApiServer = ${api-server} # This parameter is optional. Set it to a blank string ("") to not use an API server.
$rustdeskKey = ${key} #"your_new_public_key"
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
# Script logic to update RustDesk configuration
# ==============================================================================

if (-not (Test-IsAdmin)) {
    Write-Error "This script must be run with Administrator privileges. Please right-click and 'Run as Administrator'."
    exit
}

# Check if required parameters are provided.
if (-not $rustdeskIdServer -or -not $rustdeskKey) {
    Write-Error "ID Server, and Key are required parameters. Please provide them in the 'User Configuration' section."
    exit
}

Write-Host "Updating RustDesk server configuration..."

try {
    # Define the path to the configuration file. This path is for the system-wide installation.
    $rustdeskConfigPath = "C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml"

    # Check if the config file exists
    if (-not (Test-Path $rustdeskConfigPath)) {
        Write-Error "RustDesk configuration file not found at '$rustdeskConfigPath'. Please ensure RustDesk is installed."
        exit
    }

    # Read the content of the TOML file
    $content = Get-Content -Path $rustdeskConfigPath | Out-String

    # Replace the existing server and key values with your new ones
    $content = $content -replace 'id_server = ".*"', "id_server = `"$rustdeskIdServer`""
    $content = $content -replace 'relay_server = ".*"', "relay_server = `"$rustdeskRelayServer`""
    $content = $content -replace 'api_server = ".*"', "api_server = `"$rustdeskApiServer`""
    $content = $content -replace 'key = ".*"', "key = `"$rustdeskKey`""

    # Write the modified content back to the file
    $content | Set-Content -Path $rustdeskConfigPath

    Write-Host "RustDesk configuration updated successfully."
    Write-Host "You may need to restart the RustDesk service for changes to take effect."
}
catch {
    Write-Error "Failed to update RustDesk configuration."
    Write-Error $_.Exception.Message
    exit
}

Write-Host "Script finished."

#endregion Main Script
