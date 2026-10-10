#!/usr/bin/env bash
# One-time setup of the shared VPS (Ubuntu 24.04). Run as root, from the repo.
#   CERTBOT_EMAIL=you@example.com ./deploy/server-setup.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "run as root" >&2
    exit 1
fi

here="$(cd "$(dirname "$0")" && pwd)"

apt-get update
apt-get install -y ca-certificates curl git nginx certbot python3-certbot-nginx \
    ufw gettext-base uidmap dbus-user-session

# Docker from the official repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin \
    docker-compose-plugin docker-ce-rootless-extras

# Ubuntu 24.04 restricts unprivileged user namespaces; rootless Docker needs this
cat > /etc/apparmor.d/usr.bin.rootlesskit <<'EOF'
abi <abi/4.0>,
include <tunables/global>

/usr/bin/rootlesskit flags=(unconfined) {
  userns,

  include if exists <local/usr.bin.rootlesskit>
}
EOF
systemctl restart apparmor

# Pull the base images once and keep them as a tarball: every rootless daemon
# has its own image store, and a whole class pulling from one IP would hit
# Docker Hub's anonymous rate limit
systemctl start docker
images="python:3.12-slim postgres:16-alpine nginx:1.27-alpine"
for image in $images; do
    docker pull "$image"
done
install -d /opt/annuaire
# shellcheck disable=SC2086
docker save -o /opt/annuaire/images.tar $images
chmod 644 /opt/annuaire/images.tar

# Students only get rootless Docker: the system daemon would make them root
systemctl disable --now docker.service docker.socket

# Firewall: SSH + HTTP/HTTPS only
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# The stock site would answer for unknown hosts
rm -f /etc/nginx/sites-enabled/default

groupadd -f students

install -d /etc/annuaire/templates
install -m 644 "$here"/nginx.conf.template /etc/annuaire/templates/
echo "${CERTBOT_EMAIL:-}" > /etc/annuaire/certbot_email

# Helper students can run through sudo (see sudoers below)
install -m 755 "$here"/annuaire-https /usr/local/sbin/

cat > /etc/sudoers.d/annuaire-students <<'EOF'
%students ALL=(root) NOPASSWD: /usr/local/sbin/annuaire-https
EOF
chmod 440 /etc/sudoers.d/annuaire-students
visudo -cf /etc/sudoers.d/annuaire-students

systemctl enable --now nginx

echo
echo "Done. Next: harden SSH by hand (key login only), then run add-student.sh."
