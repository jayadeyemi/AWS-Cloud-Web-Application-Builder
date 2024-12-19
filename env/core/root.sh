####################################################################################################
# Program Root
####################################################################################################

# load environment variables
source "$(dirname "$0")/env/variables.env"

# load constants
source "$(dirname "$0")/env/constants.env"

# load settings
source "$(dirname "$0")/env/core/settings.sh"

# Load functions
source "$(dirname "$0")/env/core/workers.sh"

####################################################################################################
# Main Worker Script
####################################################################################################


# Phase Worker Function
execute_phase() {
    local phase_num="$1"
    local phase_file="$2"
    local phase_name="$3"
    local timed_out=0

    while true; do
        read -t $PHASE_DELAY -r -p "Proceed to Phase ${phase_num} (${phase_name})? (y/n/[Press Enter to skip]): " cont

        if [[ $? -gt 0 ]]; then
            timed_out=1
        fi

        cont="${cont,,}"

        if [[ "$cont" == "y" ]]; then
            log "$EXECUTION_LOG" "Executing Phase ${phase_num} (${phase_name})..."
            source "$phase_file"
            if [[ $? -ne 0 ]]; then
                log "$EXECUTION_LOG" "Phase ${phase_num} failed."
                return 0
            fi
            break
        elif [[ "$cont" == "n" ]]; then
            log "$EXECUTION_LOG" "User chose to exit."
            exit 0
        elif [[ -z "$cont" && $timed_out -eq 0 ]]; then
            log "$EXECUTION_LOG" "Skipping Phase ${phase_num}."
            break
        elif [[ $timed_out -eq 1 ]]; then
            log "$EXECUTION_LOG" "Timeout reached. Automatically proceeding to Phase ${phase_num} (${phase_name})."
            source "$phase_file"
            if [[ $? -ne 0 ]]; then
                log "$EXECUTION_LOG" "Phase ${phase_num} failed on timeout execution."
                return 0
            fi
            break
        else
            echo "Invalid input. Please enter 'y', 'n', or press Enter to skip."
        fi
    done
}
