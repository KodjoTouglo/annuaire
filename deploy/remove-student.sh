#!/usr/bin/env bash
# Delete a student's account, containers, data and site. Cannot be undone.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "run as root" >&2
    exit 1
fi

user="${1:?usage: remove-student.sh <username>}"

if ! [[ "$user" =~ ^[a-z][a-z0-9]{1,15}$ ]] || ! groups "$user" 2>/dev/null | grep -qw students; then
    echo "$user is not a student account" >&2
    exit 1
fi

read -r -p "Delete $user, its home, its containers and its data? [y/N] " answer
[ "$answer" = "y" ] || exit 0

host="$(awk '/server_name/ {gsub(";", "", $2); print $2; exit}' "/etc/nginx/sites-available/annuaire-$user" 2>/dev/null || true)"

rm -f "/etc/nginx/sites-enabled/annuaire-$user" "/etc/nginx/sites-available/annuaire-$user"
nginx -t && systemctl reload nginx

# Otherwise certbot keeps trying to renew a certificate for a dead site
if [ -n "$host" ]; then
    certbot delete --cert-name "$host" --non-interactive >/dev/null 2>&1 || true
fi

# Stopping the user manager stops the rootless daemon and its containers
loginctl disable-linger "$user"
systemctl stop "user@$(id -u "$user").service" || true

deluser --remove-home "$user"
