#!/usr/bin/env bash
# src: debian-install-rustdesk.sh
# Debian/Ubuntu equivalent of deploy-rustdesk-msi.ps1.
# Downloads, installs, and configures RustDesk with custom server details.
#
# Must be run as root (sudo).
#
# Usage:
#   sudo ./debian-install-rustdesk.sh \
#     --id-server <host> \
#     --key <public-key> \
#     --password <permanent-password> \
#     [--relay-server <host>] \
#     [--api-server <host>] \
#     [--version <x.y.z>]

set -euo pipefail

id_server=""
relay_server=""
api_server=""
key=""
password=""
version_override=""

usage() {
    cat <<EOF
Usage: sudo $(basename "$0") --id-server <host> --key <key> --password <pw> \\
       [--relay-server <host>] [--api-server <host>] [--version <x.y.z>]

Required:
  --id-server      RustDesk ID (rendezvous) server address
  --key            Public key for server authentication
  --password       Permanent password for the RustDesk client

Optional:
  --relay-server   Relay server address (pass "" to clear)
  --api-server     API server address for RustDesk Pro (pass "" to clear)
  --version        Pin a version (e.g. 1.4.1). Defaults to latest from GitHub.
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --id-server)    id_server="${2-}";      shift 2 ;;
        --relay-server) relay_server="${2-}";   shift 2 ;;
        --api-server)   api_server="${2-}";     shift 2 ;;
        --key)          key="${2-}";            shift 2 ;;
        --password)     password="${2-}";       shift 2 ;;
        --version)      version_override="${2-}"; shift 2 ;;
        -h|--help)      usage; exit 0 ;;
        *)              echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
done

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: root privileges required (run with sudo)." >&2
    exit 1
fi

if [[ -z "$id_server" || -z "$key" || -z "$password" ]]; then
    echo "ERROR: --id-server, --key, and --password are required." >&2
    usage >&2
    exit 1
fi

for cmd in curl dpkg dpkg-query systemctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd" >&2
        exit 1
    fi
done

case "$(uname -m)" in
    x86_64)  arch="x86_64" ;;
    aarch64) arch="aarch64" ;;
    armv7l)  arch="armv7" ;;
    *)       echo "ERROR: unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

# A1: Resolve target version — GitHub API or pinned override
if [[ -n "$version_override" ]]; then
    target_version="${version_override#v}"
    echo "Using pinned version: $target_version"
else
    echo "Fetching latest RustDesk release from GitHub..."
    # Grep tag_name straight out of the releases API (avoid jq dep).
    target_version=$(curl -fsSL --retry 3 --retry-delay 5 \
        https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
        | grep -oP '"tag_name":\s*"\K[^"]+' | head -1)
    target_version="${target_version#v}"
    if [[ -z "$target_version" ]]; then
        echo "ERROR: could not determine latest RustDesk version." >&2
        exit 1
    fi
    echo "Latest version: $target_version"
fi

installer_url="https://github.com/rustdesk/rustdesk/releases/download/${target_version}/rustdesk-${target_version}-${arch}.deb"
installer_path="/tmp/rustdesk-${target_version}-${arch}.deb"

# A2: Skip install if already at or above the target version
installed_version=""
if dpkg-query -W -f='${Version}' rustdesk >/dev/null 2>&1; then
    installed_version=$(dpkg-query -W -f='${Version}' rustdesk)
fi

skip_install=false
if [[ -n "$installed_version" ]]; then
    if dpkg --compare-versions "$installed_version" ge "$target_version"; then
        echo "RustDesk $installed_version already installed. Skipping download and install."
        skip_install=true
    else
        echo "RustDesk $installed_version installed, upgrading to $target_version..."
    fi
else
    echo "RustDesk not currently installed."
fi

if ! $skip_install; then
    echo "Downloading $installer_url..."
    curl -fL --retry 3 --retry-delay 5 --max-time 300 -o "$installer_path" "$installer_url"

    echo "Installing $installer_path..."
    # dpkg -i will fail if deps are missing; apt-get -f fills them in.
    if ! dpkg -i "$installer_path"; then
        echo "Resolving missing dependencies..."
        apt-get update -y
        apt-get install -f -y
    fi

    rm -f "$installer_path"
fi

# Service + config (always runs, even on skip_install — RMM may be pushing
# updated server details to an existing install).
echo "Enabling and starting rustdesk service..."
systemctl enable --now rustdesk

# --option / --password go over IPC to the running service; wait until it's
# active so writes don't silently land in the wrong profile.
for _ in {1..12}; do
    if systemctl is-active --quiet rustdesk; then break; fi
    systemctl start rustdesk || true
    sleep 5
done
if ! systemctl is-active --quiet rustdesk; then
    echo "ERROR: rustdesk service did not start within 60 seconds." >&2
    exit 1
fi
sleep 2  # let the IPC socket settle after the service comes up

rustdesk_bin=$(command -v rustdesk || echo /usr/bin/rustdesk)
if [[ ! -x "$rustdesk_bin" ]]; then
    echo "ERROR: rustdesk binary not found at $rustdesk_bin." >&2
    exit 1
fi

echo "Applying server options..."
"$rustdesk_bin" --option custom-rendezvous-server "$id_server"
"$rustdesk_bin" --option relay-server            "$relay_server"
"$rustdesk_bin" --option api-server              "$api_server"
"$rustdesk_bin" --option key                     "$key"

echo "Setting permanent password..."
"$rustdesk_bin" --password "$password"

client_id=$("$rustdesk_bin" --get-id 2>/dev/null | tr -d '[:space:]' || true)
if [[ -n "$client_id" ]]; then
    echo "ID: $client_id"
else
    echo "WARNING: failed to retrieve RustDesk client ID."
fi
