###################################################################################################
# Functions
###################################################################################################

# Logging function
log() {
    local log_file="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $message" | tee -a "$log_file"
}

####################################################################################################
# Function to log variables
####################################################################################################

store_variable() {
    local var_name="$1"
    local var_value="${!var_name}"
    echo "$var_name=\"$var_value\"" >> "$VARIABLES_LOG"
}

####################################################################################################
# Command execution function
####################################################################################################

execute_command() {
    local command="$1"
    local retries=0
    local status=1
    local output_var=""
    local actual_command=""

    # Handle variable assignment
    if [[ "$command" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=\$\((.*)\)$ ]]; then
        output_var="${BASH_REMATCH[1]}"
        actual_command="${BASH_REMATCH[2]}"
    else
        actual_command="$command"
    fi

    while [[ $retries -lt $RETRY_LIMIT ]]; do
        ((COMMAND_COUNTER++))
        local command_id="CMD_$COMMAND_COUNTER"

        # Log execution
        log "$EXECUTION_LOG" "Executing Command_ID=$command_id: $actual_command"

        # Execute command and capture response
        if [[ -n "$output_var" ]]; then
            response=$(eval "$actual_command" 2>&1)
            status=$?
            if [[ $status -eq 0 ]]; then
                eval "$output_var=\"\$response\""
                store_variable "$output_var"
                log "$EXECUTION_LOG" "Command_ID=$command_id succeeded."
                return 0
            fi
        else
            response=$(eval "$actual_command" 2>&1)
            status=$?
            if [[ $status -eq 0 ]]; then
                log "$EXECUTION_LOG" "Command_ID=$command_id succeeded."
                return 0
            fi
        fi

        # Log response and status
        log "$RESPONSE_LOG" "Command_ID=$command_id Response: $response"
        log "$RESPONSE_LOG" "Command_ID=$command_id Status: $status"

        log "$EXECUTION_LOG" "Command_ID=$command_id failed. Retrying ($((retries + 1))/$RETRY_LIMIT)..."
        sleep $RETRY_INTERVAL
        ((retries++))
    done

    log "$EXECUTION_LOG" "Command_ID=$command_id failed after $RETRY_LIMIT retries."
    return $status
}

######################################
# Phase Execution Wrapper
######################################

prompt_phase() {
    local phase_num=$1
    local phase_file=$2
    local phase_name=$3

    while true; do
        read -t 300 -r -p "Proceed to Phase ${phase_num} (${phase_name})? (y/n/[Press Enter to skip]): " cont
        cont="${cont,,}"
        echo "$phase_num" >> "$VARIABLES_LOG"

        if [[ "$cont" == "y" ]]; then
            log "$EXECUTION_LOG" "Executing Phase ${phase_num} (${phase_name})..."
            source "$phase_file"
            if [[ $? -ne 0 ]]; then
                log "$EXECUTION_LOG" "Phase ${phase_num} failed. Jumping to Phase 5..."
                source "$(dirname "$0")/phase5.sh"
                return 1
            fi
            break

        elif [[ "$cont" == "n" ]]; then
            log "$EXECUTION_LOG" "User exited the script."
            exit 0
        elif [[ -z "$cont" ]]; then
            log "$EXECUTION_LOG" "Skipping Phase ${phase_num}."
            break
        else
            echo "Invalid input. Please enter 'y', 'n', or [press Enter to skip]."
        fi
    done
}

####################################################################################################
# End of functions.sh
####################################################################################################