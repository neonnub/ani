#!/usr/bin/env bash
# Compile the RMI server, the web gateway client and the database tools.
set -e
cd "$(dirname "$0")"

if [ ! -f lib/postgresql-42.7.4.jar ]; then
  bash tools/fetch-deps.sh
fi

mkdir -p out
find src -name '*.java' -print0 | xargs -0 javac -encoding UTF-8 -cp "lib/*" -d out
echo "Build complete — classes are in out/"
