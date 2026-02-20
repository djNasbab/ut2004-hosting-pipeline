#!/usr/bin/env bash
set -euo pipefail

UT2004_DIR="${UT2004_DIR:-/opt/ut2004}"
cd "${UT2004_DIR}/System"

MAP="${MAP:-DM-Rankin}"
GAME="${GAME:-XGame.xDeathMatch}"
PORT="${PORT:-7777}"
QUERYPORT="${QUERYPORT:-7778}"

# If you pass a full command, run that instead.
if [[ $# -gt 0 ]]; then
  exec "$@"
fi

# Start dedicated server
exec ./UCC server "${MAP}?game=${GAME}?Port=${PORT}?QueryPort=${QUERYPORT}" ini=UT2004.ini -nohomedir
