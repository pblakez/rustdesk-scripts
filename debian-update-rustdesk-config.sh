#!/usr/bin/env bash
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

# src: debian-update-rustdesk-config.sh
# Debian/Ubuntu equivalent of act1-update-rustdesk-config.ps1.
# Updates server/key on an existing RustDesk install. Does not install or
# change the password.
#
# Must be run as root (sudo).
#
# Usage:
#   sudo ./debian-update-rustdesk-config.sh \
#     --id-server <host> \
#     --key <public-key> \
#     [--relay-server <host>] \
#     [--api-server <host>]

set -euo pipefail

id_server=""
relay_server=""
api_server=""
key=""

usage() {
    cat <<EOF
Usage: sudo $(basename "$0") --id-server <host> --key <key> \\
       [--relay-server <host>] [--api-server <host>]

Required:
  --id-server      New RustDesk ID (rendezvous) server address
  --key            New public key for server authentication

Optional:
  --relay-server   New relay server address (pass "" to clear)
  --api-server     New API server address for RustDesk Pro (pass "" to clear)
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --id-server)    id_server="${2-}";      shift 2 ;;
        --relay-server) relay_server="${2-}";   shift 2 ;;
        --api-server)   api_server="${2-}";     shift 2 ;;
        --key)          key="${2-}";            shift 2 ;;
        -h|--help)      usage; exit 0 ;;
        *)              echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
done

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: root privileges required (run with sudo)." >&2
    exit 1
fi

if [[ -z "$id_server" || -z "$key" ]]; then
    echo "ERROR: --id-server and --key are required." >&2
    usage >&2
    exit 1
fi

for cmd in systemctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd" >&2
        exit 1
    fi
done

rustdesk_bin=$(command -v rustdesk || echo /usr/bin/rustdesk)
if [[ ! -x "$rustdesk_bin" ]]; then
    echo "RustDesk is not installed. Nothing to update." >&2
    exit 1
fi

echo "Updating RustDesk server configuration..."

# --option goes over IPC to the running service; wait until it's active so
# writes don't silently land in the wrong profile.
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

# Apply server/key config via the CLI. Keys match the names accepted by
# RustDesk's --option handler (src/core_main.rs: "custom-rendezvous-server",
# "relay-server", "api-server", "key"). IPC writes take effect live — no
# service restart needed.
echo "Applying server options..."
"$rustdesk_bin" --option custom-rendezvous-server "$id_server"
"$rustdesk_bin" --option relay-server            "$relay_server"
"$rustdesk_bin" --option api-server              "$api_server"
"$rustdesk_bin" --option key                     "$key"

echo "RustDesk configuration updated successfully."
