#!/usr/bin/env bash
# Create one student: Linux user, rootless Docker, port and nginx site.
#   ./deploy/add-student.sh alice /path/to/alice.pub
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "run as root" >&2
    exit 1
fi

user="${1:?usage: add-student.sh <username> <public-key-file>}"
keyfile="${2:?usage: add-student.sh <username> <public-key-file>}"

# Lowercase letters and digits only: safe as a unix user and a DNS label
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
usermod -aG students "$user"

install -d -m 700 -o "$user" -g "$user" "/home/$user/.ssh"
install -m 600 -o "$user" -g "$user" "$keyfile" "/home/$user/.ssh/authorized_keys"

uid="$(id -u "$user")"
# One port per student, derived from the uid so it never collides
port=$((8000 + uid - 1000))

# Linger keeps the student's Docker daemon running without an open session
loginctl enable-linger "$user"
for _ in $(seq 1 30); do
    [ -S "/run/user/$uid/bus" ] && break
    sleep 1
done

as_student() {
    (cd "/home/$user" && runuser -u "$user" -- env HOME="/home/$user" \
        XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        PATH=/usr/bin:/bin "$@")
}

# The setup tool also creates and selects the "rootless" CLI context,
# so the docker command finds the student's daemon in every shell
as_student dockerd-rootless-setuptool.sh install
as_student docker load -i /opt/annuaire/images.tar

export APP_HOST="$host" APP_PORT="$port"
envsubst '${APP_HOST} ${APP_PORT}' < /etc/annuaire/templates/nginx.conf.template \
    > "/etc/nginx/sites-available/annuaire-$user"
ln -sf "/etc/nginx/sites-available/annuaire-$user" "/etc/nginx/sites-enabled/annuaire-$user"
nginx -t
systemctl reload nginx

cat <<EOF

Student ready: $user
  ssh:       ssh $user@$ip
  url:       http://$host
  APP_PORT:  $port
EOF
