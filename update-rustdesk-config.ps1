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

function Set-RustDeskOption {
    param(
        [Parameter(Mandatory)][string]$ExePath,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )
    if ([string]::IsNullOrEmpty($Value)) {
        # PS < 7.3 strips empty-string args from `& exe $var` invocations,
        # which would turn --option's 3-arg write into a 2-arg read (no-op).
        # Start-Process with an explicit "" literal forces the empty arg
        # through so rustdesk.exe actually clears the option.
        Start-Process -FilePath $ExePath -ArgumentList '--option', $Key, '""' -Wait -NoNewWindow
    } else {
        & $ExePath --option $Key $Value
    }
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
    # rustdesk.exe must be invoked from its installation directory so that
    # is_installed() passes inside the binary.
    $rustdeskInstallPath = "$env:ProgramFiles\RustDesk"
    if (-not (Test-Path (Join-Path $rustdeskInstallPath 'rustdesk.exe'))) {
        Write-Error "RustDesk not found at '$rustdeskInstallPath'. Please ensure RustDesk is installed."
        exit
    }
    Set-Location -Path $rustdeskInstallPath

    # --option goes over IPC to the running service, so the service must be up.
    if (-not (Wait-RustDeskServiceRunning)) {
        Write-Error "RustDesk service did not reach a running state. Aborting update."
        exit
    }

    # Apply server/key config via the CLI. Keys match the names accepted by
    # RustDesk's --option handler (src/core_main.rs: "custom-rendezvous-server",
    # "relay-server", "api-server", "key"). IPC writes take effect live — no
    # service restart needed.
    Write-Host "Applying server options..."
    $rustdeskExe = Join-Path $rustdeskInstallPath 'rustdesk.exe'
    Set-RustDeskOption -ExePath $rustdeskExe -Key 'custom-rendezvous-server' -Value $rustdeskIdServer
    Set-RustDeskOption -ExePath $rustdeskExe -Key 'relay-server' -Value $rustdeskRelayServer
    Set-RustDeskOption -ExePath $rustdeskExe -Key 'api-server' -Value $rustdeskApiServer
    Set-RustDeskOption -ExePath $rustdeskExe -Key 'key' -Value $rustdeskKey

    Write-Host "RustDesk configuration updated successfully."
}
catch {
    Write-Error "Failed to update RustDesk configuration."
    Write-Error $_.Exception.Message
    exit
}

Write-Host "Script finished."

#endregion Main Script
