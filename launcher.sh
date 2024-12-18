#!/bin/bash

######################################
# Load environment variables
######################################

# load environment variables
source "$(dirname "$0")/env/variables.env"
source "$(dirname "$0")/env/constants.env"

######################################
# Load the settings
######################################

# load settings file
source "$(dirname "$0")/env/config/settings.sh"

######################################
# Load variables from external file
######################################

source "$(dirname "$0")/env/config/functions.sh"
source "$(dirname "$0")/env/config/settings.sh"

######################################
# Main Script Execution
######################################

# Main loop
# This script runs an infinite loop using a while loop.
# The loop will continue to execute until it is manually stopped.
while true; do
    echo "######################################"
    echo "# Prompts to Execute Phases 1-5"
    echo "######################################"

# Prompt for user input and wait 60 seconds for a response
read -t 60 -r -p "Do you want to input a new password? (y/n): " generate_password

if [[ "$generate_password" =~ ^[Yy]$ ]]; then
    # User chooses to input their own password
    while true; do
        read -r -p "Enter password: " SECRET_PASSWORD
        read -r -p "Confirm password: " confirm_password

        if [[ "$SECRET_PASSWORD" == "$confirm_password" ]]; then
            echo "Passwords match. Password set successfully."
            break
        else
            echo "Passwords do not match. Please try again."
        fi
    done
else
    # Generate a random password
SECRET_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)

fi

log "$VARIABLES_LOG" "SECRET_PASSWORD=$SECRET_PASSWORD"
    
    # Execute each phase
    prompt_phase 1 "$(dirname "$0")/env/phase_files/phase1.sh" "Phase 1 - 1st Instance Deployment" || continue
    prompt_phase 2 "$(dirname "$0")/env/phase_files/phase2.sh" "Phase 2 - 2nd Instance Deployment" || continue
    prompt_phase 3 "$(dirname "$0")/env/phase_files/phase3.sh" "Phase 3 - Autoscaling Group Deployment" || continue
    prompt_phase 4 "$(dirname "$0")/env/phase_files/phase4.sh" "Phase 4 - Load-Tester for the Autoscaling Group" || continue
    prompt_phase 5 "$(dirname "$0")/env/phase_files/phase5.sh" "Phase 5 - Cleanup Function" || continue
    log "$EXECUTION_LOG" "All phases have been processed."

    # Ask if the script should run again
    read -r -p "Do you want to run the phases again? (y/e): " repeat
    repeat="${repeat,,}"

    if [[ "$repeat" == "n" ]]; then
        log "$EXECUTION_LOG" "Exiting the script."
        break
    fi
done
