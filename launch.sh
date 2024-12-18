# Log files
EXECUTION_LOG="$(dirname "$0")/execution.log"
RESPONSE_LOG="$(dirname "$0")/response.log"
VARIABLES_LOG="$(dirname "$0")/created_resourses.log"

######################################
# Main Script Execution
RESOURCES_LOG="$(dirname "$0")/created_resourses.log"

# Function to prompt phase
prompt_phase() {
  echo "Prompting phase $1"
}

# Example function calls
    }
    
    # Prompt for user input with a default value and validation
    read -r -p "Enter the script name (default: launch.sh): " scriptName
    scriptName=${scriptName:-launch.sh}
    
    # Validate the input
    if [[ ! " launch.sh env/config/functions.sh env/config/main_config.sh env/config/settings.sh env/phase_files/phase1.sh env/phase_files/phase2.sh env/phase_files/phase3.sh env/phase_files/phase4.sh env/phase_files/phase5.sh env/data_files/ec2_v1_userdata.sh env/data_files/ec2_v2_userdata.sh " =~ " $scriptName " ]]; then
      echo "Invalid script name. Exiting."
      exit 1
    fi
prompt_phase 2
prompt_phase 3
