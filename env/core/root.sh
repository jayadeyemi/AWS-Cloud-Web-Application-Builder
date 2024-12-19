# load environment variables
source "$(dirname "$0")/env/variables.env"

# load constants
source "$(dirname "$0")/env/constants.env"

# load settings
source "$(dirname "$0")/env/workers/settings.sh"

# Load functions
source "$(dirname "$0")/env/workers/functions.sh"