#!/bin/bash

# Setting the region
aws configure set region "$REGION"

# Setting the path
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")

# Renaming variables for IPs
USER_IP=$USER_PUBLIC_IP_INPUT
USER_CIDR="$USER_IP/32"

# Decide the SSH key forma
if [ "$USER_OS" = "mac" ]; then
    KEY_FORMAT="pem"
else
    KEY_FORMAT="ppk"
fi

# ASG Target Value Modifier
sed -i "s/\"TargetValue\": [^,]*/\"TargetValue\": $ASG_TARGET/" "./config.json"