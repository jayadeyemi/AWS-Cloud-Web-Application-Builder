#!/bin/bash
####################################################################################################
####################################################################################################
# Program name: Launcher                                                                           #
####################################################################################################
#                                                                                                  #
#                                                                                                  #
####################################################################################################
# Defining the environment variables                                                               #
####################################################################################################

# load environment variables
variables_env="$(dirname "$0")/env/variables.env"
constants_env="$(dirname "$0")/env/core/constants.env"
config_sh="$(dirname "$0")/env/core/config.sh"
phase_worker_sh="$(dirname "$0")/env/core/phase_worker.sh"


#Path to key pair
mkdir -p $(dirname "$0")/env/keys/
KEY_PATH="$(dirname "$0")/env/keys/"

# Log files
mkdir -p $(dirname "$0")/logs/
EXECUTION_LOG="$(dirname "$0")/logs/execution.log"
RESPONSE_LOG="$(dirname "$0")/logs/response.log"
VARIABLES_LOG="$(dirname "$0")/logs/created_resourses.log"

#Data files
DATA_DIR="$(dirname "$0")/env/data/data.sql"
DB_DR="$(dirname "$0")/env/data/"
USER_DATA_FILE_V1="$(dirname "$0")/env/data/ec2_v1_userdata.sh"
USER_DATA_FILE_V2="$(dirname "$0")/env/data/ec2_v2_userdata.sh"

#Cleaner files - Testing
mkdir -p $(dirname "$0")/env/core/cleaners
CLEANER_DIR="$(dirname "$0")/env/core/cleaners"
CALLER="$(dirname "$0")/env/core/caller.sh"
MAP_BUILD="$(dirname "$0")/env/core/map_build.sh"

# ASG Configuration file
ASG_CONFIG="$(dirname "$0")/env/asg_config/config.json"

# Phase scripts
PHASE_1_SCRIPT="$(dirname "$0")/env/phase_files/phase1.sh"
PHASE_2_SCRIPT="$(dirname "$0")/env/phase_files/phase2.sh"
PHASE_3_SCRIPT="$(dirname "$0")/env/phase_files/phase3.sh"
PHASE_4_SCRIPT="$(dirname "$0")/env/phase_files/phase4.sh"
PHASE_5_SCRIPT="$(dirname "$0")/env/phase_files/phase5.sh"

####################################################################################################
# Loader
####################################################################################################
source "$(dirname "$0")/env/core/root.sh"
####################################################################################################
# End of Program Launcher
####################################################################################################