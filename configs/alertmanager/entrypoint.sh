#!/bin/bash

# Alertmanager entrypoint script with MS Teams webhook configuration
# This script substitutes environment variables into the alertmanager.yml config

set -e

CONFIG_FILE="/etc/alertmanager/alertmanager.yml"
TEMP_CONFIG="/tmp/alertmanager.yml"

# Copy the config file
cp "$CONFIG_FILE" "$TEMP_CONFIG"

# Substitute webhook URLs if environment variables are set
if [ -n "$MSTEAMS_WEBHOOK_URL" ]; then
    sed -i "s|MSTEAMS_WEBHOOK_URL_PLACEHOLDER|$MSTEAMS_WEBHOOK_URL|g" "$TEMP_CONFIG"
fi

if [ -n "$MSTEAMS_CRITICAL_WEBHOOK_URL" ]; then
    sed -i "s|MSTEAMS_CRITICAL_WEBHOOK_URL_PLACEHOLDER|$MSTEAMS_CRITICAL_WEBHOOK_URL|g" "$TEMP_CONFIG"
fi

if [ -n "$MSTEAMS_WARNING_WEBHOOK_URL" ]; then
    sed -i "s|MSTEAMS_WARNING_WEBHOOK_URL_PLACEHOLDER|$MSTEAMS_WARNING_WEBHOOK_URL|g" "$TEMP_CONFIG"
fi

# Replace the original config with the processed one
mv "$TEMP_CONFIG" "$CONFIG_FILE"

# Start Alertmanager with the processed configuration
exec /bin/alertmanager "$@"