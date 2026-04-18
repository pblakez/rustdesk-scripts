# Requires PowerShell 7.0+
# This script must be run with Administrator privileges.
# src: act1-update-rustdesk-config.ps1
# this script is designed to run in action1 enviroment
# act1: update-rustdesk-config
# parameters: id-server, relay-server, api-server, key


$rustdeskIdServer = ${id-server}
$rustdeskRelayServer = ${relay-server} # This parameter is optional. Set it to a blank string ("") to not use an API server.
$rustdeskApiServer = ${api-server} # This parameter is optional. Set it to a blank string ("") to not use an API server.
$rustdeskKey = ${key} #"your_new_public_key"

# Returns $true when the current session is running with Administrator rights.
function Test-IsAdmin {
    $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Writes a RustDesk --option setting via IPC to the running service.
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

if (-not (Test-IsAdmin)) {
    Write-Host "ERROR: Administrator privileges required."
    exit 1
}

if (-not $rustdeskIdServer -or -not $rustdeskKey) {
    Write-Host "ERROR: id-server and key parameters are required."
    exit 1
}

$rustdeskInstallPath = "$env:ProgramFiles\RustDesk"
if (-not (Test-Path (Join-Path $rustdeskInstallPath 'rustdesk.exe'))) {
    Write-Host "RustDesk is not installed. Nothing to update."
    exit 1
}

Write-Host "Updating RustDesk server configuration..."

try {
    Set-Location -Path $rustdeskInstallPath

    # --option goes over IPC to the running service, so the service must be up.
    if (-not (Wait-RustDeskServiceRunning)) {
        exit 1
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
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
}
