#!/bin/bash

##################################################################################################################
# Load environment variables and path
##################################################################################################################
source "$(dirname "$0")/env/core/root.sh"

# Setting the region
aws configure set region "$REGION"

# ASG Target Value Modifier
sed -i "s/\"TargetValue\": [^,]*/\"TargetValue\": $ASG_TARGET/" "$(dirname "$0")/env/workers/config.json"
# Obtain DB password
echo "############################################################################################################"
echo "# Variables Initialized"
echo "# Press [y] to input a password, or"
echo "# Press any other key to generate a random password."
echo "############################################################################################################"
read -t $DB_Password_wait -r -p "# User Input: " generate_password
echo "############################################################################################################"
echo -e "\n\n\n"

if [[ "$generate_password" =~ ^[Yy]$ ]]; then
    # User chooses to input their own password
    while true; do
        read -s -r -p  "# Enter a password: " SECRET_PASSWORD
        echo "#"
        read -s -r -p  "# Confirm password: " confirm_password
        if [[ "$SECRET_PASSWORD" == "$confirm_password" && "$SECRET_PASSWORD" != "" ]]; then
            echo "# Passwords match. Password: $SECRET_PASSWORD"
            echo "############################################################################################################"

            break
        else
            echo "# Passwords do not match. Please try again."
        fi
    done
else
    # Generate a random password
SECRET_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)

echo "# Random password generated: $SECRET_PASSWORD"
echo "############################################################################################################"
fi

log "$VARIABLES_LOG" "SECRET_PASSWORD=$SECRET_PASSWORD"
echo -e "\n\n\n"

#######################################
# Main loop
#######################################

# The loop will continue to execute until it is manually stopped.
while true; do
    echo "############################################################################################################"
    echo "# Prompts to Execute Phases 1-5"
    echo "############################################################################################################"

    # Execute each phase
    prompt_phase 1 "$(dirname "$0")/env/phase_files/phase1.sh" "1st Instance Deployment" || continue
    prompt_phase 2 "$(dirname "$0")/env/phase_files/phase2.sh" "2nd Instance Deployment" || continue
    prompt_phase 3 "$(dirname "$0")/env/phase_files/phase3.sh" "Autoscaling Group Deployment" || continue
    prompt_phase 4 "$(dirname "$0")/env/phase_files/phase4.sh" "Load-Tester for the Autoscaling Group" || continue
    log "$EXECUTION_LOG" "All phases have been processed."

    # Ask if the script should run again
    echo "############################################################################################################"
    echo "# Press 'n' to clear all resources and exit the script, or"
    echo "# Press [Enter] to restart the script, or"
    echo "# Press any other key to exit the script."
    read -r -p "# User Input: " repeat
    echo "############################################################################################################"
    repeat="${repeat,,}"

    if [[ "$repeat" == "n" ]]; then
        source "$(dirname "$0")/env/phase_files/phase5.sh"
        log "$EXECUTION_LOG" "Phase 5 completed."
        read -r -p "# Press [Enter] to restart the script, or Press any other key to exit the script." repeat
        
        if [[ "$repeat" != "" ]]; then
            log "$EXECUTION_LOG" "Exiting the script."
            break
        fi

    elif [[ "$repeat" != "" ]]; then
        log "$EXECUTION_LOG" "Exiting the script."
        break
    fi
done
echo "############################################################################################################"
echo "# End of Script"
echo "############################################################################################################"

##################################################################################################################
# End of launcher.sh
##################################################################################################################