# rustdesk-scripts

PowerShell scripts for deploying and managing RustDesk remote desktop software in enterprise environments. These scripts are designed for use with Action1 RMM platform but can be adapted for standalone use.

## Prerequisites

- PowerShell 7.0 or higher
- Administrator privileges
- Windows operating system
- Network access to download RustDesk installer (for deployment script)

## Scripts

### deploy-rustdesk.ps1

**Purpose**: Downloads, installs, and configures RustDesk with custom server settings and a permanent password.

**Usage**:
```powershell
# Run with Administrator privileges
.\deploy-rustdesk.ps1
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

### update-rustdesk-config.ps1

**Purpose**: Updates an existing RustDesk installation with new server configuration details.

**Usage**:
```powershell
# Run with Administrator privileges
.\update-rustdesk-config.ps1
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

### change-rustdesk-password.ps1

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

These scripts are provided as-is for managing RustDesk deployments. RustDesk itself is subject to its own licensing terms.