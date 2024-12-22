##################################################################################################################
# Root Script for the Launcher
##################################################################################################################

# load environment variables
source $variables_env

# load constants
source $constants_env

# load settings
source $config_sh

# Load phase worker
source $phase_worker_sh

# Setting the region
aws configure set region "$REGION"

# ASG Target Value Modifier
sed -i "s/\"TargetValue\": [^,]*/\"TargetValue\": $ASG_TARGET/" "$ASG_CONFIG"

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
            echo "# Passwords match"
            echo "############################################################################################################"

            break
        else
            echo "# Passwords do not match. Please try again."
        fi
    done
else
    # Generate a random password
SECRET_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)

echo "# Random password generated"
echo "############################################################################################################"
fi

log "$VARIABLES_LOG" "SECRET_PASSWORD=$SECRET_PASSWORD"
echo -e "\n\n\n"

##################################################################################################################
# Main loop
##################################################################################################################

# This script continuously loops to execute all phases until manually stopped
main_launcher() {
    while true; do
        echo "############################################################################################################"
        echo "# Prompts to Execute Phases 1-5"
        echo "############################################################################################################"

        # Execute each phase
        execute_phase 1 "$PHASE_1_SCRIPT" "1st Instance Deployment" || continue
        execute_phase 2 "$PHASE_2_SCRIPT" "2nd Instance Deployment" || continue
        execute_phase 3 "$PHASE_3_SCRIPT" "Autoscaling Group Deployment" || continue
        execute_phase 4 "$PHASE_4_SCRIPT" "Load-Tester for the Autoscaling Group" || continue
        log "$EXECUTION_LOG" "All phases have been processed."

        # Ask if the script should run again
        echo "############################################################################################################"
        echo "#                                        Clean Resources?                                                  #"
        echo "############################################################################################################"
        echo "# Type 'y' to proceed to Phase 5"
        echo "# Type 'n' to exit"
        echo "# [Press Enter to skip]"
        read -r -p "# User Input: " repeat
        echo "############################################################################################################"
        repeat="${repeat,,}"

        if [[ "$repeat" == "y" ]]; then
            execute_phase 5 "$PHASE_5_SCRIPT" "Resource Deletion"
            return 0
            read -r -p "# Press [Enter] to continue back to phase #1, or Type 'n' to exit the script" repeat           
            if [[ "$repeat" == "n" ]]; then
                log "$EXECUTION_LOG" "# Exiting the script." 
                break
            elif [[ -z "$repeat" ]]; then
                log "$EXECUTION_LOG" "# returning to phase 1."
            else
                echo "Invalid input. returning to phase 1."
            fi
        elif [[ "$repeat" == "n" ]]; then
            log "$EXECUTION_LOG" "# Exiting the script."
            break
        else
            echo "# Invalid input. Please enter 'y' or 'n' or press [Enter] to skip."
        fi
    done
}

# Run the main launcher
main_launcher
##################################################################################################################
# End of launcher.sh
##################################################################################################################