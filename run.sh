#!/usr/bin/env bash
# One-command demo: embedded RMI registry + server + web gateway.
set -e
cd "$(dirname "$0")"
if [ ! -f out/com/mmtrip/client/WebMain.class ]; then bash build.sh; fi
echo "Open http://localhost:8080 in your browser."
exec java -Dmht.demo=true -cp "out:lib/*" com.mmtrip.client.WebMain --embedded
