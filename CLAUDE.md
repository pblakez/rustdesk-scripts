# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains PowerShell scripts for deploying and managing RustDesk remote desktop software in enterprise environments, specifically designed for Action1 RMM platform integration.

## Key Scripts

- **act1-deploy-rustdesk.ps1**: Downloads, installs, and configures RustDesk with custom server settings and permanent password
- **act1-update-rustdesk-config.ps1**: Updates existing RustDesk configuration with new server details
- **act1-change-rustdesk-password.ps1**: Currently empty, intended for password management functionality

## Action1 Integration

Scripts are designed for Action1 RMM with parameter placeholders:
- `${id-server}`: RustDesk ID server address
- `${relay-server}`: Relay server address (optional)
- `${api-server}`: API server for RustDesk Pro (optional)
- `${key}`: Public key for server authentication
- `${password}`: Permanent password for RustDesk client

## Important Configuration Details

- **Config file location**: `C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk.toml`
- **Installation path**: `$env:ProgramFiles\RustDesk`
- **Requires**: PowerShell 7.0+ and Administrator privileges
- **RustDesk version**: Currently hardcoded to 1.2.3 in deploy script

## Development Notes

- All scripts check for administrator privileges before execution
- Scripts use TOML file manipulation for configuration updates
- Error handling includes descriptive messages for troubleshooting
- Scripts are self-contained with helper functions included