# Requires PowerShell 7.0+ for some commands (like Invoke-WebRequest)
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
$rustdeskRelayServer = ${relay-server} = # "your_relay_server.example.com" can be blank
$rustdeskApiServer = ${api-server} # Required for RustDesk Pro can be blank otherwise
$rustdeskKey = ${key} #"your_public_key"
$rustdeskPermanentPassword = ${password} #"YourS3cureP@ssw0rd!"

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
# Script logic to download, install, and configure RustDesk
# ==============================================================================

if (-not (Test-IsAdmin)) {
    Write-Error "This script must be run with Administrator privileges. Please right-click and 'Run as Administrator'."
    exit
}

# Define installer URL. You can find the latest stable release on the RustDesk GitHub page.
$installerUrl = "https://github.com/rustdesk/rustdesk/releases/download/1.2.3/rustdesk-1.2.3-x86_64.exe"
$installerPath = "$env:TEMP\rustdesk-installer.exe"
$rustdeskInstallPath = "$env:ProgramFiles\RustDesk"

Write-Host "Downloading RustDesk installer from $installerUrl..."
try {
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -TimeoutSec 300
}
catch {
    Write-Error "Failed to download the RustDesk installer. Please check the URL and your network connection."
    exit
}

Write-Host "Starting silent installation..."
try {
    # The --silent-install flag performs a quiet installation
    Start-Process -FilePath $installerPath -ArgumentList "--silent-install" -Wait -NoNewWindow
    Write-Host "Installation completed successfully."
}
catch {
    Write-Error "RustDesk installation failed."
    exit
}

# Clean up the installer file
Remove-Item -Path $installerPath -Force

Write-Host "Configuring RustDesk with server details and permanent password..."
try {
    # Set permanent password using the command line
    # The executable must be run from its installation directory
    Set-Location -Path $rustdeskInstallPath
    & ".\rustdesk.exe" --password $rustdeskPermanentPassword
    Write-Host "Permanent password set successfully."

    # Wait for the service to start and the config file to be created
    Start-Sleep -Seconds 5

    # Define the path to the configuration file. This path is for the system-wide installation.
    $rustdeskConfigPath = "C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml"

    # Check if the config file exists
    if (-not (Test-Path $rustdeskConfigPath)) {
        Write-Error "RustDesk configuration file not found at '$rustdeskConfigPath'. Configuration failed."
        exit
    }

    # Read the content of the TOML file
    $content = Get-Content -Path $rustdeskConfigPath | Out-String

    # Replace the default server and key values with your own
    $content = $content -replace 'id_server = ".*"', "id_server = `"$rustdeskIdServer`""
    $content = $content -replace 'relay_server = ".*"', "relay_server = `"$rustdeskRelayServer`""
    $content = $content -replace 'api_server = ".*"', "api_server = `"$rustdeskApiServer`""
    $content = $content -replace 'key = ".*"', "key = `"$rustdeskKey`""

    # Write the modified content back to the file
    $content | Set-Content -Path $rustdeskConfigPath

    Write-Host "RustDesk configured with server details successfully."

    # Report the RustDesk client ID
    Write-Host ""
    Write-Host "Retrieving RustDesk client ID..."
    $clientId = & ".\rustdesk.exe" --get-id
    if ($clientId) {
        Write-Host "============================="
        Write-Host "RustDesk Client ID: $clientId"
        Write-Host "============================="
    } else {
        Write-Error "Failed to retrieve the RustDesk client ID."
    }
}
catch {
    Write-Error "Failed to configure RustDesk. Please check the permissions and file paths."
    Write-Error $_.Exception.Message
    exit
}

Write-Host "Script finished. RustDesk is now installed and configured."

#endregion Main Script
