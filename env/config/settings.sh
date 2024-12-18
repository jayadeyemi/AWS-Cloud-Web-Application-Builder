######################################
# Configuration
######################################

# Setting personal variables
chmod -R +r ./env
find ./env -type f -name "*.sh" -exec chmod +x {} \;
find ./env -type d -exec chmod +x {} \;

# Log files
EXECUTION_LOG="$(dirname "$0")/execution.log"
RESPONSE_LOG="$(dirname "$0")/response.log"
VARIABLES_LOG="$(dirname "$0")/created_resourses.log"
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")

# Retry settings
RETRY_LIMIT=5
RETRY_INTERVAL=30

# Command counter for logging
COMMAND_COUNTER=0
# Set the region
aws configure set region "$REGION"

# Renaming variables for IPs
USER_IP=$USER_PUBLIC_IP_INPUT
USER_CIDR="$USER_IP/32"

# Decide the SSH key forma
if [ "$USER_OS" = "mac" ]; then
    KEY_FORMAT="pem"
else
    KEY_FORMAT="ppk"
fi
#######################################
# End of env/config/settings.sh
#######################################