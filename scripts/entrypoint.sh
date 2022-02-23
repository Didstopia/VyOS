#!/usr/bin/env bash

# set -eo pipefail
# set -x

echo
echo "--- VyOS Build Script ---"
echo

## TODO: Ensure that the Docker socket (and Docker as a whole) is available?

# Switch working directory.
# cd /vyos

# Start the build script.
exec /build.sh "$@"
# ../build.sh "$@"
