#!/usr/bin/env bash
# Create several student accounts from a folder of public keys.
# The file name (without .pub) becomes the username.
#   ./deploy/add-students.sh /path/to/keys
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "run as root" >&2
    exit 1
fi

keys="${1:?usage: add-students.sh <folder-with-.pub-files>}"
here="$(cd "$(dirname "$0")" && pwd)"
report="$(mktemp)"

for key in "$keys"/*.pub; do
    user="$(basename "$key" .pub | tr '[:upper:]' '[:lower:]')"
    if id "$user" >/dev/null 2>&1; then
        echo "skip $user (exists)"
        continue
    fi
    echo "== $user"
    if out="$("$here"/add-student.sh "$user" "$key" 2>&1)"; then
        port="$(sed -n 's/^  APP_PORT: *//p' <<<"$out")"
        url="$(sed -n 's/^  url: *//p' <<<"$out")"
        printf '%-12s %-6s %s\n' "$user" "$port" "$url" >> "$report"
    else
        echo "FAILED $user" >&2
        printf '%-12s FAILED\n' "$user" >> "$report"
    fi
done

echo
printf '%-12s %-6s %s\n' USER PORT URL
cat "$report"
rm -f "$report"
