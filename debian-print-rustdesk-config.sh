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

# src: debian-print-rustdesk-config.sh
# Debian/Ubuntu equivalent of act1-print-rustdesk-config.ps1.
# Prints the current RustDesk version, client ID, server settings, and key.
#
# Must be run as root (sudo) so --option / --get-id can reach the service
# over IPC.
#
# Usage:
#   sudo ./debian-print-rustdesk-config.sh

set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: root privileges required (run with sudo)." >&2
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo "ERROR: required command not found: systemctl" >&2
    exit 1
fi

rustdesk_bin=$(command -v rustdesk || echo /usr/bin/rustdesk)
if [[ ! -x "$rustdesk_bin" ]]; then
    echo "RustDesk is not installed." >&2
    exit 1
fi

# --get-id and --option both go over IPC, so the service must be running.
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

# Reads a RustDesk option via IPC. Prints '(not set)' when the option is empty.
# --option with no value argument reads and prints the current setting
# (src/core_main.rs).
get_option() {
    local out
    out=$("$rustdesk_bin" --option "$1" 2>/dev/null | tr -d '[:space:]' || true)
    if [[ -z "$out" ]]; then
        echo '(not set)'
    else
        echo "$out"
    fi
}

version=$("$rustdesk_bin" --version 2>/dev/null | tr -d '[:space:]' || true)
client_id=$("$rustdesk_bin" --get-id 2>/dev/null | tr -d '[:space:]' || true)
id_server=$(get_option custom-rendezvous-server)
relay_server=$(get_option relay-server)
api_server=$(get_option api-server)
public_key=$(get_option key)

echo "Version: ${version:-(unknown)}"
echo "ID: ${client_id:-(not set)}"
echo "ID Server: $id_server"
echo "Relay Server: $relay_server"
echo "API Server: $api_server"
echo "Key: $public_key"
