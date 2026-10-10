#!/usr/bin/env bash
# Update a running deployment. Run as the student, on the server.
set -euo pipefail

cd "$(dirname "$0")/.."

git pull --ff-only
# Rebuilds the web image; migrate and collectstatic run when it starts
docker compose up -d --build
docker compose ps
