#!/usr/bin/env bash
# Update a running deployment. Run as the student, on the server.
set -euo pipefail

cd "$(dirname "$0")/.."

git pull --ff-only
venv/bin/pip install -r requirements.txt
venv/bin/python manage.py migrate --noinput
venv/bin/python manage.py collectstatic --noinput
sudo /usr/local/sbin/annuaire-restart
