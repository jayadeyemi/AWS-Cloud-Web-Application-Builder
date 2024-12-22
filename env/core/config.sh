####################################################################################################
# Configuration
####################################################################################################
# Retry settings
RETRY_LIMIT=5
RETRY_INTERVAL=30

# DB Password wait duration
DB_Password_wait=300

# Phase Commencement Delay duration
PHASE_DELAY=60

# Database File for migration
USE_TEST_DB_FILE="false"  # Change this to true if you're planning to use my sample_entries.sql file'

####################################################################################################
# Do not modify below this line
####################################################################################################
# Authorize the sub-scripts
chmod -R +r ./env
find ./env -type f -name "*.sh" -exec chmod +x {} \;
find ./env -type d -exec chmod +x {} \;

# Command counter for logging
COMMAND_COUNTER=0

# Decide the SSH key format
if [ "$USER_OS" != "windows" ]; then
    KEY_FORMAT="pem"
else
    KEY_FORMAT="ppk"
fi

# Set the DB dump file to use
if [ "$USE_TEST_DB_FILE" == "true" ]; then
    CHOSEN_DB="sample_entries.sql"
else
    CHOSEN_DB="data.sql"
fi

# Path to Input files
CHOSEN_DB_FILE="$DB_DR$CHOSEN_DB"
PUB_KEY="$KEY_PATH$PUBLIC_KEY.$KEY_FORMAT"
PRIV_KEY="$KEY_PATH$PRIVATE_KEY.$KEY_FORMAT"

####################################################################################################
# End of settings.sh
####################################################################################################