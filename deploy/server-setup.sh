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
apt-get install -y nginx postgresql git python3-venv python3-dev \
    certbot python3-certbot-nginx ufw gettext-base

# Firewall: SSH + HTTP/HTTPS only
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# The stock site would answer for unknown hosts
rm -f /etc/nginx/sites-enabled/default

groupadd -f students

install -d /etc/annuaire/templates
install -m 644 "$here"/gunicorn.service.template "$here"/nginx.conf.template \
    /etc/annuaire/templates/
echo "${CERTBOT_EMAIL:-}" > /etc/annuaire/certbot_email

# Helpers students can run through sudo (see sudoers below)
install -m 755 "$here"/annuaire-restart "$here"/annuaire-https /usr/local/sbin/

cat > /etc/sudoers.d/annuaire-students <<'EOF'
%students ALL=(root) NOPASSWD: /usr/local/sbin/annuaire-restart, /usr/local/sbin/annuaire-https
EOF
chmod 440 /etc/sudoers.d/annuaire-students
visudo -cf /etc/sudoers.d/annuaire-students

systemctl enable --now nginx postgresql

echo
echo "Done. Next: harden SSH by hand (key login only), then run add-student.sh."
