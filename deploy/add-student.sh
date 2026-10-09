#!/usr/bin/env bash
# Create one student: Linux user, Postgres database, gunicorn unit, nginx site.
#   ./deploy/add-student.sh alice /path/to/alice.pub
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "run as root" >&2
    exit 1
fi

user="${1:?usage: add-student.sh <username> <public-key-file>}"
keyfile="${2:?usage: add-student.sh <username> <public-key-file>}"

# Lowercase letters and digits only: safe as a unix user, a DB name and a DNS label
if ! [[ "$user" =~ ^[a-z][a-z0-9]{1,15}$ ]]; then
    echo "invalid username: use 2-16 lowercase letters/digits, starting with a letter" >&2
    exit 1
fi

if id "$user" >/dev/null 2>&1; then
    echo "user $user already exists" >&2
    exit 1
fi

# Public IP as seen by the default route; override with SERVER_IP if needed
ip="${SERVER_IP:-$(ip -4 route get 1.1.1.1 | awk '{for (i = 1; i <= NF; i++) if ($i == "src") print $(i + 1)}')}"
host="${user}.${ip//./-}.sslip.io"

adduser --disabled-password --gecos "" "$user"
# systemd-journal lets the student read their own service logs
usermod -aG students,systemd-journal "$user"

install -d -m 700 -o "$user" -g "$user" "/home/$user/.ssh"
install -m 600 -o "$user" -g "$user" "$keyfile" "/home/$user/.ssh/authorized_keys"

# nginx (www-data) must be able to traverse the home dir to serve static files
chmod 711 "/home/$user"

dbpass="$(openssl rand -hex 16)"
runuser -u postgres -- psql -v ON_ERROR_STOP=1 <<SQL
CREATE ROLE "$user" LOGIN PASSWORD '$dbpass';
CREATE DATABASE "$user" OWNER "$user";
SQL

export APP_USER="$user" APP_HOST="$host"
envsubst '${APP_USER} ${APP_HOST}' < /etc/annuaire/templates/gunicorn.service.template \
    > "/etc/systemd/system/annuaire-$user.service"
envsubst '${APP_USER} ${APP_HOST}' < /etc/annuaire/templates/nginx.conf.template \
    > "/etc/nginx/sites-available/annuaire-$user"
ln -sf "/etc/nginx/sites-available/annuaire-$user" "/etc/nginx/sites-enabled/annuaire-$user"

systemctl daemon-reload
systemctl enable "annuaire-$user"
nginx -t
systemctl reload nginx

cat <<EOF

Student ready: $user
  ssh:       ssh $user@$ip
  url:       http://$host
  DB_NAME:   $user
  DB_USER:   $user
  DB_PASSWORD (shown once): $dbpass
EOF
