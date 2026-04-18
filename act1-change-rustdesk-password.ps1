# Copyright [2026] [Peter Blakeley : @pblakez pb@blakez.org]
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Requires PowerShell 7.0+
# This script must be run with Administrator privileges.
# src: act1-change-rustdesk-password.ps1
# this script is designed to run in action1 enviroment
# act1: change-rustdesk-password
# parameters: password

$rustdeskPermanentPassword = ${password} # "YourN3wS3cureP@ssw0rd!"

# Returns $true when the current session is running with Administrator rights.
function Test-IsAdmin {
    $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Waits for the RustDesk service's TOML config files to exist in the
# LocalService profile. --password persists to these files; calling it
# before the initial TOML exists fails with "os error 2" on fresh boxes.
function Wait-RustDeskConfigReady {
    param(
        [string]$ConfigDir = "$env:WINDIR\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config",
        [int]$MaxAttempts = 20,
        [int]$DelaySeconds = 1
    )
    for ($i = 0; $i -lt $MaxAttempts; $i++) {
        if (Get-ChildItem -Path $ConfigDir -Filter 'RustDesk*.toml' -ErrorAction SilentlyContinue) {
            Start-Sleep -Seconds 2  # extra settle for the service's initial TOML write
            return $true
        }
        Start-Sleep -Seconds $DelaySeconds
    }
    return $false
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

    [void](Wait-RustDeskConfigReady)

    Set-Location -Path $rustdeskInstallPath
    $null = & ".\rustdesk.exe" --password $rustdeskPermanentPassword 2>&1
    if ($LASTEXITCODE -ne 0) {
        Start-Sleep -Seconds 3
        & ".\rustdesk.exe" --password $rustdeskPermanentPassword
    }

    Write-Host "Permanent password set successfully."
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
}
