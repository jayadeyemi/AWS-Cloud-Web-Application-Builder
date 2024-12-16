######################################
# Functions to execute a command and handle failures
######################################

execute_command() {
    local command=$1
    local error_message=$2
    local retries=5
    local delay=30

    echo "Executing: $command"
    retry_command "$command" $retries $delay
    if [ $? -ne 0 ]; then
        echo "ERROR: $error_message"
        echo "Command: $command"
        log_status "N/A" "$command" 1
        return 1
    fi

    log_status "N/A" "$command" 0
    return 0
}

retry_command() {
    local command=$1
    local retries=$2
    local delay=$3
    local count=0

    until eval "$command"; do
        count=$((count + 1))
        if [[ $count -ge $retries ]]; then
            echo "Command failed after $retries attempts."
            return 1
        fi
        echo "Retrying in $delay seconds... ($count/$retries)"
        sleep "$delay"
    done
    return 0
}

log_status() {
    local response=$1
    local command=$2
    local status=$3
    ID=$((ID+1))
    formatted_id=$(printf "%03d" $ID)

    if [[ $status -eq 0 ]]; then
        echo "$formatted_id: [SUCCESS]: $command executed successfully." >>execution.log
    else
        echo "$formatted_id: [FAILURE]: $command failed." >>execution.log
        echo "$formatted_id: [RESPONSE]: $response" >>response.log
    fi
}

######################################
# Function to handle each phase
######################################

prompt_phase() {
    # Arguments: phase number, phase command, phase name
    local phase_num=$1  # Phase number
    local phase_cmd=$2  # Function name to execute
    local phase_name=$3 # Phase name

    while true; do
        read -t 300 -p "Proceed to Phase ${phase_num} (${phase_name})? (yes/exit/[Press Enter to skip]): " cont
        cont="${cont,,}" # Convert input to lowercase for case-insensitive comparison

        if [[ "$cont" == "yes" ]]; then
            echo "Executing Phase ${phase_num} (${phase_name})..."
            $phase_cmd
            if [[ $? -ne 0 ]]; then
                echo "Phase ${phase_num} failed. Jumping to Phase 5..."
                phase5
                return 1 # Signal failure to the main loop
            fi
            break
        elif [[ "$cont" == "exit" ]]; then
            echo "Exiting the script."
            exit 0
        elif [[ -z "$cont" ]]; then
            echo "Skipping Phase ${phase_num}."
            break
        else
            echo "Invalid input. Please enter 'yes', 'exit', or press Enter to skip."
        fi
    done
}

######################################
# Main Script Execution
######################################

while true; do
    echo "######################################"
    echo "# Prompts to Execute Phases 1-5"
    echo "######################################"

    # Prompt for each phase. If a phase fails, skip remaining phases and jump to Phase 5.
    prompt_phase 1 phase1 "Phase 1" || continue
    prompt_phase 2 phase2 "Phase 2" || continue
    prompt_phase 3 phase3 "Phase 3" || continue
    prompt_phase 4 phase4 "Phase 4" || continue
    prompt_phase 5 phase5 "Phase 5"

    echo "All phases have been processed."

    # Optionally, ask the user if they want to run the phases again
    read -r -p "Do you want to run the phases again? (yes/no): " repeat
    repeat="${repeat,,}" # Convert input to lowercase

    if [[ "$repeat" = "no" ]]; then
        echo "Exiting the script."
        exit 0
    fi
done

# End of script