# rustdesk-scripts

PowerShell scripts for deploying and managing RustDesk remote desktop software in enterprise environments. These scripts are designed for use with Action1 RMM platform but can be adapted for standalone use.

## Prerequisites

- PowerShell 7.0 or higher
- Administrator privileges
- Windows operating system
- Network access to download RustDesk installer (for deployment script)

## Scripts

### act1-deploy-rustdesk.ps1

**Purpose**: Downloads, installs, and configures RustDesk with custom server settings and a permanent password.

**Usage**:
```powershell
# Run with Administrator privileges
.\act1-deploy-rustdesk.ps1
```

**Parameters** (configured in script or via Action1):
- `id-server`: Your RustDesk ID server address (required)
- `relay-server`: Your relay server address (optional, can be blank)
- `api-server`: API server for RustDesk Pro (optional, can be blank)
- `key`: Public key for server authentication (required)
- `password`: Permanent password for the RustDesk client (required)

**What it does**:
1. Downloads RustDesk installer from GitHub (currently v1.2.3)
2. Performs silent installation
3. Sets the permanent password
4. Configures server settings in the TOML configuration file
5. Reports the RustDesk client ID upon completion

**Notes**:
- Installer is downloaded to temp folder and cleaned up after installation
- Configuration file is located at: `C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml`
- Installation directory: `C:\Program Files\RustDesk`

### act1-update-rustdesk-config.ps1

**Purpose**: Updates an existing RustDesk installation with new server configuration details.

**Usage**:
```powershell
# Run with Administrator privileges
.\act1-update-rustdesk-config.ps1
```

**Parameters** (configured in script or via Action1):
- `id-server`: New RustDesk ID server address (required)
- `relay-server`: New relay server address (optional, can be blank)
- `api-server`: New API server for RustDesk Pro (optional, can be blank)
- `key`: New public key for server authentication (required)

**What it does**:
1. Validates that RustDesk is already installed
2. Updates the existing TOML configuration file with new server details
3. Preserves other existing configuration settings

**Notes**:
- Does not change the permanent password
- May require RustDesk service restart for changes to take effect
- Will fail if RustDesk is not already installed

### act1-change-rustdesk-password.ps1

**Purpose**: Changes the permanent password for an existing RustDesk installation.

**Status**: Currently not implemented (empty file)

**Planned functionality**:
- Update the permanent password for the RustDesk client
- Require administrator privileges
- Work with existing RustDesk installation

## Action1 RMM Integration

These scripts are designed to work with Action1 RMM platform. When used in Action1:

1. Create a new script in Action1
2. Copy the PowerShell script content
3. Define parameters in Action1 matching the script variables:
   - `id-server`
   - `relay-server` 
   - `api-server`
   - `key`
   - `password` (for deploy script only)
4. Deploy to target machines through Action1 policies

## Standalone Usage

To use these scripts outside of Action1:

1. Edit the script files directly
2. Replace the `${parameter}` placeholders with actual values:
   ```powershell
   $rustdeskIdServer = "your-server.example.com"
   $rustdeskRelayServer = "your-relay.example.com"
   $rustdeskApiServer = ""  # Leave blank if not using RustDesk Pro
   $rustdeskKey = "your-public-key-here"
   $rustdeskPermanentPassword = "YourSecurePassword123!"
   ```
3. Run the script with Administrator privileges

## Linux (Ubuntu/Debian) Equivalents

RustDesk's `--option` and `--password` CLI flags behave the same on Linux as on Windows, so the logic of `act1-update-rustdesk-config.ps1` and `act1-change-rustdesk-password.ps1` maps directly.

### debian-install-rustdesk.sh

Debian/Ubuntu equivalent of `act1-deploy-rustdesk-msi.ps1`. Takes its parameters from the CLI instead of Action1 placeholders.

```bash
sudo ./debian-install-rustdesk.sh \
  --id-server    id.example.com \
  --key          "<public-key>" \
  --password     'YourS3cureP@ssw0rd!' \
  --relay-server relay.example.com \
  --api-server   "" \
  --version      1.4.1        # optional; omit for latest from GitHub
```

What it does (same flow as the MSI script):

1. Resolves the target version (GitHub `releases/latest`, or `--version`).
2. Skips download/install if the installed `rustdesk` package is already at or above the target (uses `dpkg --compare-versions`).
3. Downloads `rustdesk-<version>-<arch>.deb` from GitHub (x86_64 / aarch64 / armv7).
4. Installs with `dpkg -i`, falling back to `apt-get install -f` to resolve deps.
5. Enables and starts `rustdesk.service`, waits for it to become active.
6. Pushes `custom-rendezvous-server`, `relay-server`, `api-server`, `key` via `rustdesk --option`.
7. Sets the permanent password via `rustdesk --password`.
8. Prints the client ID.

Always re-applies the config even when the install is skipped, so the same script handles first-install *and* server-detail updates on already-provisioned boxes.

### Install locations

- **Binary**: `/usr/bin/rustdesk` (symlink to `/usr/share/rustdesk/rustdesk`)
- **Systemd unit**: `rustdesk.service` at `/lib/systemd/system/rustdesk.service`
  - `ExecStart=/usr/bin/rustdesk --service`, runs as `root`
- **Service config dir** (the one the service reads, since it runs as root): `/root/.config/rustdesk/`
  - Contains `RustDesk.toml`, `RustDesk2.toml`, `RustDesk_local.toml`, etc.
- **User config dir** (per-user GUI session): `~/.config/rustdesk/`
- **Logs**: `~/.local/share/logs/RustDesk/`

### Equivalent of `act1-update-rustdesk-config.ps1`

`--option` goes over IPC to the running service, so the service must be up and the commands must run as root (same caveat as Windows).

```bash
sudo systemctl start rustdesk
sudo rustdesk --option custom-rendezvous-server <id-server>
sudo rustdesk --option relay-server        <relay-server>   # "" to clear
sudo rustdesk --option api-server          <api-server>     # "" to clear
sudo rustdesk --option key                 <public-key>
```

Read a value back with `sudo rustdesk --option <key>` (no value argument).

Alternative bulk import (useful for first-run provisioning):

```bash
sudo rustdesk --import-config /path/to/RustDesk2.toml
```

### Equivalent of `act1-print-rustdesk-config.ps1`

Read-only version of the same IPC calls — useful to confirm what the running service currently has applied.

```bash
sudo systemctl start rustdesk
rustdesk --version
rustdesk --get-id
sudo rustdesk --option custom-rendezvous-server
sudo rustdesk --option relay-server
sudo rustdesk --option api-server
sudo rustdesk --option key
```

Each `--option <key>` with no value prints the current setting (empty line = not set). One-liner:

```bash
for k in custom-rendezvous-server relay-server api-server key; do
  printf '%-26s %s\n' "$k:" "$(sudo rustdesk --option "$k")"
done
```

### Equivalent of `act1-change-rustdesk-password.ps1`

```bash
sudo systemctl start rustdesk
sudo rustdesk --password '<NewPermanentPassword>'
```

### Other useful commands

```bash
rustdesk --get-id                       # print this machine's RustDesk ID
sudo systemctl status rustdesk          # service state
sudo systemctl restart rustdesk         # apply changes that need a restart
sudo systemctl enable --now rustdesk    # start now + enable at boot
```

### "No displays" / Wayland workaround (headless / unattended)

On a Wayland session — or a box with no logged-in console user — the RustDesk client errors with **`Error: No displays`**. The service-mode capture path needs an Xorg session it can attach to; on Wayland the portal can't grant it without a user clicking through a prompt, and with no user logged in there's nothing to grab at all.

#### Path A — quick: switch the console to Xorg
Use this if a person *will* log in at the console after the change. Disables Wayland in GDM so the next login lands on Xorg, where RustDesk's capture works.

```bash
sudo sed -i 's/^#\?WaylandEnable=.*/WaylandEnable=false/' /etc/gdm3/custom.conf
grep WaylandEnable /etc/gdm3/custom.conf      # confirm
sudo systemctl restart gdm3                   # SSH-safe; only kills console sessions
```
Then have a user log in at the console and reconnect with RustDesk.

#### Path B — full headless (no console user, no monitor)
Official `allow-linux-headless` flow. Heavier — replaces GDM with LightDM and adds the dummy X driver so RustDesk has something to render into when nobody is logged in.

> **Test on a local Pop!_OS / Ubuntu box first.** Swapping the display manager on a remote-only host without verifying the LightDM greeter comes up cleanly can lock you out at the console. RustDesk officially "tested on Ubuntu, GNOME desktop" only — Pop!_OS works in practice but isn't on the supported matrix.

```bash
# 1. Install dummy X driver + lightdm
sudo apt update
sudo apt install -y xserver-xorg-video-dummy lightdm

# 2. Make LightDM the default display manager (interactive prompt)
sudo dpkg-reconfigure lightdm
#    pick "lightdm" when asked

# 3. Tell RustDesk it's allowed to serve when no displays are attached
sudo systemctl restart rustdesk
sudo rustdesk --option allow-linux-headless Y
sudo rustdesk --option allow-linux-headless          # read back; should print "Y"
sudo systemctl restart rustdesk
```

Reboot (or restart `lightdm`) so the new DM takes over, then connect with RustDesk — the "No displays" error should be gone even with no user logged in.

To roll back: `sudo dpkg-reconfigure lightdm` and pick `gdm3` again, or `sudo apt purge lightdm xserver-xorg-video-dummy && sudo dpkg-reconfigure gdm3`.

#### Path C — also useful regardless
In RustDesk → Settings → Display, enable **Allow remote connection if there are no displays**. This is the GUI toggle for the same `allow-linux-headless` option above.

### Notes / gotchas

- The service runs as `root`, so its effective config lives under `/root/.config/rustdesk/`, **not** the logged-in user's `~/.config/rustdesk/`. Editing the user file will not affect the service.
- `--option` and `--password` both require the service to be running; if it's stopped, writes can silently land in the wrong profile.
- Install via the official `.deb` from [github.com/rustdesk/rustdesk/releases](https://github.com/rustdesk/rustdesk/releases): `sudo apt install ./rustdesk-<version>.deb`.

## Security Considerations

- Scripts require Administrator privileges to modify system files
- Permanent passwords are set via command line (may be visible in process lists)
- Configuration files contain server connection details
- Ensure scripts are stored and transmitted securely
- Consider using encrypted variables in Action1 for sensitive parameters

## Troubleshooting

**Script fails with permission error**:
- Ensure running with Administrator privileges
- Right-click PowerShell and select "Run as Administrator"

**Configuration file not found**:
- Verify RustDesk is installed correctly
- Check if service is running
- Wait a few seconds after installation for config file creation

**RustDesk installer download fails**:
- Check network connectivity
- Verify the GitHub URL is accessible
- Update installer URL if using a different RustDesk version

**Changes not taking effect**:
- Restart the RustDesk service
- Reboot the machine if necessary
- Verify configuration file was updated correctly

## License

Licensed under the Apache License, Version 2.0 — see [LICENSE-2.0.txt](LICENSE-2.0.txt). RustDesk itself is distributed under its own license.