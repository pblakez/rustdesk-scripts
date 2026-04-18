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

# src: debian-change-rustdesk-password.sh
# Debian/Ubuntu equivalent of act1-change-rustdesk-password.ps1.
# Sets the permanent password on an existing RustDesk install.
#
# Must be run as root (sudo).
#
# Usage:
#   sudo ./debian-change-rustdesk-password.sh --password <permanent-password>

set -euo pipefail

password=""

usage() {
    cat <<EOF
Usage: sudo $(basename "$0") --password <permanent-password>

Required:
  --password       New permanent password for the RustDesk client
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --password)  password="${2-}"; shift 2 ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
done

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: root privileges required (run with sudo)." >&2
    exit 1
fi

if [[ -z "$password" ]]; then
    echo "ERROR: --password is required." >&2
    usage >&2
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo "ERROR: required command not found: systemctl" >&2
    exit 1
fi

rustdesk_bin=$(command -v rustdesk || echo /usr/bin/rustdesk)
if [[ ! -x "$rustdesk_bin" ]]; then
    echo "RustDesk is not installed. Nothing to update." >&2
    exit 1
fi

echo "Updating RustDesk permanent password..."

# --password goes over IPC to the running service, so the service must be up.
# If it's stopped, the password silently lands in the wrong profile.
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

"$rustdesk_bin" --password "$password"

echo "Permanent password set successfully."
