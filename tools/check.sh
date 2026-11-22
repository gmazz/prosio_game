#!/bin/sh
# Builds the test program and runs it. With no arguments it runs the check
# suite; "autoplay" lets a bot play (see src/check/autoplay.odin):
#
#   tools/check.sh
#   tools/check.sh autoplay --minutes 30 --seed 3
set -e
cd "$(dirname "$0")/.."
mkdir -p build/check
odin build src/check -out:build/check/prosio-check -vet
exec build/check/prosio-check "$@"
