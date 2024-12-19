######################################
# Configuration
######################################

# Authorize the sub-scripts
chmod -R +r ./env
find ./env -type f -name "*.sh" -exec chmod +x {} \;
find ./env -type d -exec chmod +x {} \;

# Retry settings
RETRY_LIMIT=5
RETRY_INTERVAL=30

# DB Password wait duration
DB_Password_wait=300

# Phase Commencement Delay duration
PHASE_DELAY=60

# Command counter for logging
COMMAND_COUNTER=0

# Log files
EXECUTION_LOG="$(dirname "$0")/execution.log"
RESPONSE_LOG="$(dirname "$0")/response.log"
VARIABLES_LOG="$(dirname "$0")/created_resourses.log"

#######################################
# End of env/config/settings.sh
#######################################