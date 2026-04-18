# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Scripts for deploying and managing RustDesk remote desktop software in enterprise environments. The PowerShell scripts target Action1 RMM; a standalone bash script covers Debian/Ubuntu.

## Scripts

Action1 PowerShell scripts (prefix `act1-`, `${...}` placeholders are Action1 parameter substitutions):

- **act1-deploy-rustdesk.ps1**: Downloads the EXE installer, silent-installs, and configures server/key/password.
- **act1-deploy-rustdesk-msi.ps1**: Same as above but using the MSI installer via `msiexec /qn`.
- **act1-update-rustdesk-config.ps1**: Updates server/key on an existing install (no install, no password change).
- **act1-change-rustdesk-password.ps1**: Sets the permanent password on an existing install.
- **act1-print-rustdesk-config.ps1**: Reads and prints version, client ID, server settings, and key.

Linux:

- **debian-install-rustdesk.sh**: Debian/Ubuntu equivalent of `act1-deploy-rustdesk-msi.ps1`. Takes parameters from CLI flags (`--id-server`, `--key`, `--password`, etc.) instead of Action1 placeholders.
- **debian-update-rustdesk-config.sh**: Debian/Ubuntu equivalent of `act1-update-rustdesk-config.ps1`. Updates server/key on an existing install; requires `--id-server` and `--key`, optional `--relay-server` / `--api-server`.
- **debian-print-rustdesk-config.sh**: Debian/Ubuntu equivalent of `act1-print-rustdesk-config.ps1`. Prints version, client ID, server settings, and key.
- **debian-change-rustdesk-password.sh**: Debian/Ubuntu equivalent of `act1-change-rustdesk-password.ps1`. Sets the permanent password via `rustdesk --password`.

## Action1 Parameters

Scripts substitute these `${name}` placeholders at execution time:

- `${id-server}`: RustDesk ID (rendezvous) server address
- `${relay-server}`: Relay server (optional, pass `""` to clear)
- `${api-server}`: API server for RustDesk Pro (optional, pass `""` to clear)
- `${key}`: Public key for server authentication
- `${password}`: Permanent password for the RustDesk client (deploy and change-password only)

## Configuration Mechanism

All config writes go through `rustdesk.exe --option <key> <value>` and `rustdesk.exe --password <value>`, which talk over IPC to the running Rustdesk service. Scripts do **not** edit the TOML config files directly.

Implication: the Rustdesk service must be running before any `--option` / `--password` / `--get-id` call. Every script that writes or reads config calls `Wait-RustDeskServiceRunning` (or the bash equivalent) first.

Config keys used: `custom-rendezvous-server`, `relay-server`, `api-server`, `key` (see `src/core_main.rs` in the upstream RustDesk repo).

## Installation Path and Service

- **Install path (Windows)**: `$env:ProgramFiles\RustDesk`
- **Service name (Windows)**: `Rustdesk`
- **Binary (Linux)**: `/usr/bin/rustdesk`
- **Service config dir (Linux, runs as root)**: `/root/.config/rustdesk/`

## Version Resolution

Deploy scripts resolve the target version at runtime via the GitHub releases API (`api.github.com/repos/rustdesk/rustdesk/releases/latest`). To pin a version, set `$rustdeskVersionOverride` (PowerShell) or pass `--version` (bash). If the installed version is already ≥ target, download/install is skipped; config is still re-applied.

## Requirements

- PowerShell 7.0+ and Administrator privileges on Windows
- root (via `sudo`) on Debian/Ubuntu
- Network access to `api.github.com` and `github.com` for installer download

## License

Apache License, Version 2.0 (see `LICENSE-2.0.txt`).
