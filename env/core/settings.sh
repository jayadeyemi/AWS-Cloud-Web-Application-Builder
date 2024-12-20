####################################################################################################
# Configuration
####################################################################################################

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

# Decide the SSH key format
if [ "$USER_OS" != "windows" ]; then
    KEY_FORMAT="pem"
else
    KEY_FORMAT="ppk"
fi

# Set the DB dump file to use
if $USE_DEFAULT_DB==true; then
    CHOSEN_DB="sample_entries.sql"
else
    CHOSEN_DB="data.sql"
fi


####################################################################################################
# End of settings.sh
####################################################################################################