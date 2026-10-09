#!/usr/bin/env bash
# Delete a student's account, database and site. Cannot be undone.
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

read -r -p "Delete $user, its home and its database? [y/N] " answer
[ "$answer" = "y" ] || exit 0

systemctl disable --now "annuaire-$user" || true
rm -f "/etc/systemd/system/annuaire-$user.service"
rm -f "/etc/nginx/sites-enabled/annuaire-$user" "/etc/nginx/sites-available/annuaire-$user"
systemctl daemon-reload
nginx -t && systemctl reload nginx

runuser -u postgres -- psql -v ON_ERROR_STOP=1 <<SQL
DROP DATABASE IF EXISTS "$user";
DROP ROLE IF EXISTS "$user";
SQL

deluser --remove-home "$user"
