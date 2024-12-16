#!/bin/bash
set -x
######################################
# Configuration
######################################

# Load variables from external file
source "$(dirname "$0")/variables.env"

# Log files
EXECUTION_LOG="$(dirname "$0")/execution.log"
RESPONSE_LOG="$(dirname "$0")/response.log"
VARIABLES_LOG="$(dirname "$0")/created_resourses.log"

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

######################################
# Utility Functions
######################################

# Logging function
log() {
    local log_file="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $message" | tee -a "$log_file"
}

# Function to log variables
store_variable() {
    local var_name="$1"
    local var_value="${!var_name}"
    echo "$var_name=$var_value" >> "$VARIABLES_LOG"
}

# Command execution function
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
            [[ $status -eq 0 ]] && eval "$output_var=\"\$response\"" && store_variable "$output_var"
        else
            response=$(eval "$actual_command" 2>&1)
            status=$?
        fi

        # Log response and status
        log "$RESPONSE_LOG" "Command_ID=$command_id Response: $response"
        log "$RESPONSE_LOG" "Command_ID=$command_id Status: $status"

        if [[ $status -eq 0 ]]; then
            log "$EXECUTION_LOG" "Command_ID=$command_id succeeded."
            return 0
        else
            log "$EXECUTION_LOG" "Command_ID=$command_id failed. Retrying ($((retries + 1))/$RETRY_LIMIT)..."
            sleep $RETRY_INTERVAL
            ((retries++))
        fi
    done

    log "$EXECUTION_LOG" "Command_ID=$command_id failed after $RETRY_LIMIT retries."
    return $status
}

######################################
# Phase Execution Wrapper
######################################
execute_command "echo Test Command Execution"

prompt_phase() {
    local phase_num=$1
    local phase_file=$2
    local phase_name=$3

    while true; do
        read -t 300 -r -p "Proceed to Phase ${phase_num} (${phase_name})? (yes/exit/[Press Enter to skip]): " cont
        cont="${cont,,}"
        echo "$phase_num" >> "$VARIABLES_LOG"

        if [[ "$cont" == "yes" ]]; then
            log "$EXECUTION_LOG" "Executing Phase ${phase_num} (${phase_name})..."
            source "$phase_file"
            if [[ $? -ne 0 ]]; then
                log "$EXECUTION_LOG" "Phase ${phase_num} failed. Jumping to Phase 5..."
                source "$(dirname "$0")/phase5.sh"
                return 1
            fi
            break

        elif [[ "$cont" == "exit" ]]; then
            log "$EXECUTION_LOG" "User exited the script."
            exit 0
        elif [[ -z "$cont" ]]; then
            log "$EXECUTION_LOG" "Skipping Phase ${phase_num}."
            break
        else
            echo "Invalid input. Please enter 'yes', 'exit', or press Enter to skip."
        fi
    done
}

######################################
# Main Script Execution
######################################

# Main loop
while true; do
    echo "######################################"
    echo "# Prompts to Execute Phases 1-5"
    echo "######################################"

    # Execute each phase
    prompt_phase 1 "$(dirname "$0")/phase1.sh" "Phase 1 - 1st Instance Deployment" || continue
    prompt_phase 2 "$(dirname "$0")/phase2.sh" "Phase 2 - 2nd Instance Deployment" || continue
    prompt_phase 3 "$(dirname "$0")/phase3.sh" "Phase 3 - Autoscaling Group Deployment" || continue
    prompt_phase 4 "$(dirname "$0")/phase4.sh" "Phase 4 - Load-Tester for the Autoscaling Group" || continue
    prompt_phase 5 "$(dirname "$0")/phase5.sh" "Phase 5 - Cleanup Function" || continue

    log "$EXECUTION_LOG" "All phases have been processed."

    # Ask if the script should run again
    read -r -p "Do you want to run the phases again? (yes/no): " repeat
    repeat="${repeat,,}"

    if [[ "$repeat" == "no" ]]; then
        log "$EXECUTION_LOG" "Exiting the script."
    fi
done
