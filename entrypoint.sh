#!/bin/bash

set -e
umask 0027

# Import functions
. entrypoint_common.sh
. entrypoint_functions.sh

# Apply Configuration
configure

# Clears variables starting with METASTORE_ to avoid any secret leakage.
unset "${!METASTORE_@}"

${HOME}/bin/start-metastore