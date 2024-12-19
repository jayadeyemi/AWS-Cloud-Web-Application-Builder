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

####################################################################################################
# End of functions.sh
####################################################################################################