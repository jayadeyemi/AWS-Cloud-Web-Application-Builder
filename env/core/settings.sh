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

#Path to key pair
PUB_KEY="$(dirname "$0")/env/keys/$$PUBLIC_KEY.$KEY_FORMAT"
PRIV_KEY="$(dirname "$0")/env/keys/$$PRIVATE_KEY.$KEY_FORMAT"

# Log files
EXECUTION_LOG="$(dirname "$0")/logs/execution.log"
RESPONSE_LOG="$(dirname "$0")/logs/response.log"
VARIABLES_LOG="$(dirname "$0")/logs/created_resourses.log"

#Data files
DATA_DIR="$(dirname "$0")/env/data/data.sql"
DEFAULT_DB_FILE="$(dirname "$0")/env/data/sample_entries.sql"
USER_DATA_FILE_V1="$(dirname "$0")/env/data/ec2_v1_userdata.sh"
USER_DATA_FILE_V2="$(dirname "$0")/env/data/ec2_v2_userdata.sh"

# ASG Configuration file
ASG_CONFIG="$(dirname "$0")/env/asg_config/config.json"

# Phase scripts
PHASE_1_SCRIPT="$(dirname "$0")/env/phase_files/phase1.sh"
PHASE_2_SCRIPT="$(dirname "$0")/env/phase_files/phase2.sh"
PHASE_3_SCRIPT="$(dirname "$0")/env/phase_files/phase3.sh"
PHASE_4_SCRIPT="$(dirname "$0")/env/phase_files/phase4.sh"
PHASE_5_SCRIPT="$(dirname "$0")/env/phase_files/phase5.sh"

####################################################################################################
# End of settings.sh
####################################################################################################