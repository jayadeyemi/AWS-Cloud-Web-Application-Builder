#!/bin/bash

######################################
# Predefined Static Variables for All Resources
######################################

# Prompting for user IPs and storing them in predefined variables
read -p "Enter your current IP address (e.g., 203.0.113.25): " USER_IP_INPUT
read -p "Enter your Cloud9 IP address (e.g., 203.0.113.30): " CLOUD9_IP_INPUT

# Defining variables for IPs
USER_IP="$USER_IP_INPUT"
CLOUD9_IP="$CLOUD9_IP_INPUT"
# VPC and Subnet Names
VPC_NAME="Lab-VPC"
PUB_SUBNET1_NAME="Lab-Public-Subnet1"
PUB_SUBNET2_NAME="Lab-Public-Subnet2"
PRIV_SUBNET1_NAME="Lab-Private-Subnet1"
PRIV_SUBNET2_NAME="Lab-Private-Subnet2"
DB_SUBNET1_NAME="Lab-DB-Subnet1"
DB_SUBNET2_NAME="Lab-DB-Subnet2"
# CIDR Blocks
VPC_CIDR="192.168.0.0/16"
PUB_SUBNET1_CIDR="192.168.1.0/24"
PUB_SUBNET2_CIDR="192.168.2.0/24"
PRIV_SUBNET1_CIDR="192.168.3.0/24"
PRIV_SUBNET2_CIDR="192.168.4.0/24"
DB_SUBNET1_CIDR="192.168.5.0/24"
DB_SUBNET2_CIDR="192.168.6.0/24"
INTERNET_CIDR="0.0.0.0/0"
# Security Group Names
EC2_SG_NAME="Lab-Server-SG"
RDS_SG_NAME="Lab-DB-SG"
LB_SG_NAME="Lab-LB-SG"
# Route Table Names
PUB_ROUTE_TABLE_NAME="Lab-Public-Route-Table"
DB_ROUTE_TABLE_NAME="Lab-DB-Route-Table"
# Gateway Tags
IGW_TAG="Lab-IGW"
NAT_GW_TAG="Lab-NAT"
EIP_TAG="Lab-EIP"
# RDS Subnet Group Name
DBSubnetGroup="Lab-DB-Subnet-Group"

# Instance Profile
INSTANCE_PROFILE_NAME="LabInstanceProfile"
# Ubuntu AMI ID
AMI_ID="ami-0e2c8caa4b6378d8c"
# Key Pairs
PUB_KEY="Public-EC2-KeyPair"
PRIV_KEY="Private-EC2-KeyPair"
# User Data Files
USER_DATA_FILE_V1="phase1_userdata.sh"
USER_DATA_FILE_V2="phase2_userdata.sh"
# EC2 Instance and Image Names
EC2_V1_NAME="Lab-Server-v1"
EC2_V2_NAME="Lab-Server-v2"
EC2_IMAGE1_NAME="Lab-Server-v1-Image"
EC2_IMAGE2_NAME="Lab-Server-v2-Image"

# Secrets Manager Name
SECRET_NAME="Lab-DB-Secret"
# RDS Identifier and Tags
RDS_IDENTIFIER="Lab-DB"
RDS_NAME_TAG="Lab-DB"
ENVIRONMENT="Dev"

# Load Balancer and Target Group
LB_NAME="Lab-Server-LB"
TG_NAME="Lab-Server-TG"
# Auto Scaling
EC2_ASG_NAME="Lab-Server-v3-ASG"
ASG_POLICY_NAME="CPU50PercentPolicy"
LAUNCH_TEMPLATE_NAME="ASG-Launch-Template"

######################################
# Variables that will be set dynamically
######################################
VPC_ID=""
MAIN_ROUTE_TABLE_ID=""
PUB_SUBNET1=""
PUB_SUBNET2=""
PRIV_SUBNET1=""
PRIV_SUBNET2=""
DB_SUBNET1=""
DB_SUBNET2=""
PUB_ROUTE_TABLE=""
DB_ROUTE_TABLE=""
IGW_ID=""
EIP_ALLOC=""
NAT_GW_ID=""
LAB_SG=""
RDS_SG=""
LB_SG=""
LB_ARN=""
LB_DNS=""
TG_ARN=""
INSTANCE_ID=""
NEW_INSTANCE_ID=""
SERVER_V2_IMAGE_ID=""
SECRET_ARN=""

######################################
# Function to handle each phase
######################################

prompt_phase() {
    local phase_num=$1
    local phase_cmd=$2
    local phase_name=$3

    while true; do
        read -t 120 -p "Proceed to Phase ${phase_num} (${phase_name})? (yes/exit/[Press Enter to skip]): " cont
        cont="${cont,,}"  # Convert input to lowercase for case-insensitive comparison

        if [[ "$cont" == "yes" ]]; then
            echo "Executing Phase ${phase_num}..."
            $phase_cmd
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
# Function to execute a command and handle failures
######################################

execute_command() {
    local command=$1
    local error_message=$2

    echo "Executing: $command"
    eval "$command"
    if [ $? -ne 0 ]; then
        echo "ERROR: $error_message"
        echo "Command: $command"
        exit 1
    fi
}

######################################
######################################
# Phase 1: VPC, Subnets, and EC2 with In-Memory Database
############################################################################

function phase1() {
    echo "Creating VPC"
    execute_command "VPC_ID=\$(aws ec2 create-vpc \
        --cidr-block \"$VPC_CIDR\" \
        --query 'Vpc.VpcId' \
        --output text)" \
        "Failed to create VPC."
    
    execute_command "aws ec2 create-tags \
        --resources \"$VPC_ID\" \
        --tags Key=Name,Value=\"$VPC_NAME\"" \
        "Failed to tag VPC."
    
    execute_command "aws ec2 wait vpc-available \
        --vpc-ids \"$VPC_ID\"" \
        "VPC did not become available in time."

    echo "Creating Subnets"
    execute_command "PUB_SUBNET1=\$(aws ec2 create-subnet \
        --vpc-id \"$VPC_ID\" \
        --cidr-block \"$PUB_SUBNET1_CIDR\" \
        --availability-zone us-east-1a \
        --query 'Subnet.SubnetId' \
        --output text)" \
        "Failed to create Public Subnet 1."
    
    execute_command "aws ec2 create-tags \
        --resources \"$PUB_SUBNET1\" \
        --tags Key=Name,Value=\"$PUB_SUBNET1_NAME\"" \
        "Failed to tag Public Subnet 1."

    execute_command "PUB_SUBNET2=\$(aws ec2 create-subnet \
        --vpc-id \"$VPC_ID\" \
        --cidr-block \"$PUB_SUBNET2_CIDR\" \
        --availability-zone us-east-1b \
        --query 'Subnet.SubnetId' \
        --output text)" \
        "Failed to create Public Subnet 2."
    
    execute_command "aws ec2 create-tags \
        --resources \"$PUB_SUBNET2\" \
        --tags Key=Name,Value=\"$PUB_SUBNET2_NAME\"" \
        "Failed to tag Public Subnet 2."

    execute_command "PRIV_SUBNET1=\$(aws ec2 create-subnet \
        --vpc-id \"$VPC_ID\" \
        --cidr-block \"$PRIV_SUBNET1_CIDR\" \
        --availability-zone us-east-1a \
        --query 'Subnet.SubnetId' \
        --output text)" \
        "Failed to create Private Subnet 1."
    
    execute_command "aws ec2 create-tags \
        --resources \"$PRIV_SUBNET1\" \
        --tags Key=Name,Value=\"$PRIV_SUBNET1_NAME\"" \
        "Failed to tag Private Subnet 1."

    execute_command "PRIV_SUBNET2=\$(aws ec2 create-subnet \
        --vpc-id \"$VPC_ID\" \
        --cidr-block \"$PRIV_SUBNET2_CIDR\" \
        --availability-zone us-east-1b \
        --query 'Subnet.SubnetId' \
        --output text)" \
        "Failed to create Private Subnet 2."
    
    execute_command "aws ec2 create-tags \
        --resources \"$PRIV_SUBNET2\" \
        --tags Key=Name,Value=\"$PRIV_SUBNET2_NAME\"" \
        "Failed to tag Private Subnet 2."

    execute_command "DB_SUBNET1=\$(aws ec2 create-subnet \
        --vpc-id \"$VPC_ID\" \
        --cidr-block \"$DB_SUBNET1_CIDR\" \
        --availability-zone us-east-1a \
        --query 'Subnet.SubnetId' \
        --output text)" \
        "Failed to create DB Subnet 1."
    
    execute_command "aws ec2 create-tags \
        --resources \"$DB_SUBNET1\" \
        --tags Key=Name,Value=\"$DB_SUBNET1_NAME\"" \
        "Failed to tag DB Subnet 1."

    execute_command "DB_SUBNET2=\$(aws ec2 create-subnet \
        --vpc-id \"$VPC_ID\" \
        --cidr-block \"$DB_SUBNET2_CIDR\" \
        --availability-zone us-east-1b \
        --query 'Subnet.SubnetId' \
        --output text)" \
        "Failed to create DB Subnet 2."
    
    execute_command "aws ec2 create-tags \
        --resources \"$DB_SUBNET2\" \
        --tags Key=Name,Value=\"$DB_SUBNET2_NAME\"" \
        "Failed to tag DB Subnet 2."

    execute_command "aws ec2 wait subnet-available \
        --subnet-ids \"$PUB_SUBNET1\" \"$PUB_SUBNET2\" \"$PRIV_SUBNET1\" \"$PRIV_SUBNET2\" \"$DB_SUBNET1\" \"$DB_SUBNET2\"" \
        "Subnets did not become available in time."
    
    execute_command "aws ec2 modify-subnet-attribute \
        --subnet-id \"$PUB_SUBNET1\" \
        --map-public-ip-on-launch || true" \
        "Failed to modify subnet attribute for Public Subnet 1."

    execute_command "aws ec2 modify-subnet-attribute \
        --subnet-id \"$PUB_SUBNET2\" \
        --map-public-ip-on-launch || true" \
        "Failed to modify subnet attribute for Public Subnet 2."

    echo "Creating Private Route Table and attaching with Private Subnets"
    execute_command "MAIN_ROUTE_TABLE_ID=\$(aws ec2 describe-route-tables \
        --filters \"Name=vpc-id,Values=$VPC_ID\" 
        \"Name=association.main,Values=true\" \
        --query \"RouteTables[0].RouteTableId\" \
        --output text)" \
        "Failed to describe main route table."
    
    execute_command "aws ec2 associate-route-table \
        --route-table-id \"$MAIN_ROUTE_TABLE_ID\" \
        --subnet-id \"$PRIV_SUBNET1\"" \
        "Failed to associate Private Subnet 1 with route table."
    
    execute_command "aws ec2 associate-route-table \
        --route-table-id \"$MAIN_ROUTE_TABLE_ID\" \
        --subnet-id \"$PRIV_SUBNET2\"" \
        "Failed to associate Private Subnet 2 with route table."

    echo "Creating Public Route Table and attaching to Public Subnets"
    execute_command "PUB_ROUTE_TABLE=\$(aws ec2 create-route-table \
        --vpc-id \"$VPC_ID\" \
        --query 'RouteTable.RouteTableId' \
        --output text)" \
        "Failed to create Public Route Table."
    
    execute_command "aws ec2 create-tags \
        --resources \"$PUB_ROUTE_TABLE\" \
        --tags Key=Name,Value=\"$PUB_ROUTE_TABLE_NAME\"" \
        "Failed to tag Public Route Table."

    execute_command "aws ec2 associate-route-table \
        --route-table-id \"$PUB_ROUTE_TABLE\" \
        --subnet-id \"$PUB_SUBNET1\"" \
        "Failed to associate Public Subnet 1 with Public Route Table."
    
    execute_command "aws ec2 associate-route-table \
        --route-table-id \"$PUB_ROUTE_TABLE\" \
        --subnet-id \"$PUB_SUBNET2\"" \
        "Failed to associate Public Subnet 2 with Public Route Table."

    echo "Creating DB Route Table and attaching to DB Subnets"
    execute_command "DB_ROUTE_TABLE=\$(aws ec2 create-route-table \
        --vpc-id \"$VPC_ID\" \
        --query 'RouteTable.RouteTableId' \
        --output text)" \
        "Failed to create DB Route Table."
    
    execute_command "aws ec2 create-tags \
        --resources \"$DB_ROUTE_TABLE\" \
        --tags Key=Name,Value=\"$DB_ROUTE_TABLE_NAME\"" \
        "Failed to tag DB Route Table."
    
    execute_command "aws ec2 associate-route-table \
        --route-table-id \"$DB_ROUTE_TABLE\" \
        --subnet-id \"$DB_SUBNET1\"" \
        "Failed to associate DB Subnet 1 with DB Route Table."
    
    execute_command "aws ec2 associate-route-table \
        --route-table-id \"$DB_ROUTE_TABLE\" \
        --subnet-id \"$DB_SUBNET2\"" \
        "Failed to associate DB Subnet 2 with DB Route Table."

    echo "Creating Internet Gateway, attaching and creating routes"
    execute_command "IGW_ID=\$(aws ec2 create-internet-gateway \
        --query 'InternetGateway.InternetGatewayId' \
        --output text)" \
        "Failed to create Internet Gateway."
    
    execute_command "aws ec2 create-tags \
        --resources \"$IGW_ID\" \
        --tags Key=Name,Value=\"$IGW_TAG\"" \
        "Failed to tag Internet Gateway."
    
    execute_command "aws ec2 attach-internet-gateway \
        --vpc-id \"$VPC_ID\" \
        --internet-gateway-id \"$IGW_ID\"" \
        "Failed to attach Internet Gateway."
    
    execute_command "aws ec2 create-route \
        --route-table-id \"$PUB_ROUTE_TABLE\" \
        --destination-cidr-block \"$INTERNET_CIDR\" \
        --gateway-id \"$IGW_ID\"" \
        "Failed to create route for Internet Gateway."

    echo "Creating NAT Gateway and Elastic IP, attaching and creating routes"
    execute_command "EIP_ALLOC=\$(aws ec2 allocate-address \
        --query 'AllocationId' \
        --output text)" \
        "Failed to allocate Elastic IP."
    
    execute_command "aws ec2 create-tags \
        --resources \"$EIP_ALLOC\" \
        --tags Key=Name,Value=\"$EIP_TAG\"" \
        "Failed to tag Elastic IP."
    
    execute_command "NAT_GW_ID=\$(aws ec2 create-nat-gateway \
        --subnet-id \"$PUB_SUBNET1\" \
        --allocation-id \"$EIP_ALLOC\" \
        --query 'NatGateway.NatGatewayId' \
        --output text)" \
        "Failed to create NAT Gateway."
    
    execute_command "aws ec2 create-tags \
        --resources \"$NAT_GW_ID\" \
        --tags Key=Name,Value=\"$NAT_GW_TAG\"" \
        "Failed to tag NAT Gateway."
    
    execute_command "aws ec2 wait nat-gateway-available \
        --nat-gateway-ids \"$NAT_GW_ID\"" \
        "NAT Gateway did not become available in time."
    
    execute_command "aws ec2 create-route \
        --route-table-id \"$MAIN_ROUTE_TABLE_ID\" \
        --destination-cidr-block \"$INTERNET_CIDR\" \
        --nat-gateway-id \"$NAT_GW_ID\"" \
        "Failed to create route for NAT Gateway."
    execute_command  "DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=isDefault,Values=true" \
        --query "Vpcs[0].VpcId" \
        --output text)" \
        "Failed to retrieve default VPC ID."
        echo "Creating VPC Peering Connection between Default VPC and Lab VPC"

    # Create a VPC peering connection
    execute_command "PEERING_CONNECTION_ID=\$(aws ec2 create-vpc-peering-connection \
        --vpc-id \"$DEFAULT_VPC_ID\" \
        --peer-vpc-id \"$VPC_ID\" \
        --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
        --output text)" \
        "Failed to create VPC peering connection."

    # Accept the peering connection
    execute_command "aws ec2 accept-vpc-peering-connection \
        --vpc-peering-connection-id \"$PEERING_CONNECTION_ID\"" \
        "Failed to accept VPC peering connection."

    echo "VPC Peering Connection created: $PEERING_CONNECTION_ID"

    echo "Updating Route Tables for VPC Peering Connection"

    # Add a route in the Lab VPC's route table for traffic destined to the default VPC
    execute_command "aws ec2 create-route \
        --route-table-id \"$MAIN_ROUTE_TABLE_ID\" \
        --destination-cidr-block \"$DEFAULT_VPC_CIDR\" \
        --vpc-peering-connection-id \"$PEERING_CONNECTION_ID\"" \
        "Failed to update Lab VPC route table for peering connection."

    # Add a route in the default VPC's route table for traffic destined to the Lab VPC
    execute_command "DEFAULT_ROUTE_TABLE_ID=\$(aws ec2 describe-route-tables \
        --filters \"Name=vpc-id,Values=$DEFAULT_VPC_ID\" \
        --query 'RouteTables[?Associations[0].Main].RouteTableId' \
        --output text)" \
        "Failed to retrieve default VPC route table ID."

    execute_command "aws ec2 create-route \
        --route-table-id \"$DEFAULT_ROUTE_TABLE_ID\" \
        --destination-cidr-block \"$VPC_CIDR\" \
        --vpc-peering-connection-id \"$PEERING_CONNECTION_ID\"" \
        "Failed to update Default VPC route table for peering connection."

    echo "Route Tables updated for VPC Peering Connection."

    echo "Creating Security Groups"
    execute_command "LAB_SG=\$(aws ec2 create-security-group \
        --group-name \"$EC2_SG_NAME\" \
        --description \"Lab Server Security Group\" \
        --vpc-id \"$VPC_ID\" \
        --query 'GroupId' \
        --output text)" \
        "Failed to create EC2 Security Group."

    execute_command "aws ec2 authorize-security-group-ingress \
        --group-id \"$LAB_SG\" \
        --protocol tcp \
        --port 80 \
        --cidr \"$INTERNET_CIDR\"" \
        "Failed to allow HTTP ingress on EC2 Security Group."
    
    execute_command "aws ec2 authorize-security-group-ingress \
        --group-id \"$LAB_SG\" \
        --protocol tcp \
        --port 22 \
        --cidr \"$USER_IP/32\"" \
        "Failed to allow SSH ingress from user IP on EC2 Security Group."
    
    execute_command "aws ec2 authorize-security-group-ingress \
        --group-id \"$LAB_SG\" \
        --protocol tcp \
        --port 22 \
        --cidr \"$CLOUD9_IP/32\"" \
        "Failed to allow SSH ingress from Cloud9 IP on EC2 Security Group."

    echo "Creating EC2-v1"
    execute_command "aws ec2 create-key-pair \
        --key-name \"$PUB_KEY\" \
        --query 'KeyMaterial' \
        --output text > \"$PUB_KEY.pem\"" \
        "Failed to create EC2 key pair."
    
    execute_command "chmod 400 \"$PUB_KEY.pem\"" \
        "Failed to set correct permissions for the EC2 key pair."

    execute_command "INSTANCE_ID=\$(aws ec2 run-instances \
        --image-id \"$AMI_ID\" \
        --count 1 \
        --instance-type t2.micro \
        --key-name \"$PUB_KEY\" \
        --security-group-ids \"$LAB_SG\" \
        --subnet-id \"$PUB_SUBNET1\" \
        --user-data file://\"$USER_DATA_FILE_V1\" \
        --tag-specifications \"ResourceType=instance,Tags=[{Key=Name,Value=$EC2_V1_NAME}]\" \
        --query 'Instances[0].InstanceId' \
        --output text)" \
        "Failed to launch EC2-v1 instance."

    execute_command "aws ec2 wait instance-running \
        --instance-ids \"$INSTANCE_ID\"" \
        "EC2 instance did not start within the expected time."

    INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)

    echo "$EC2_V1_NAME Public IP: $INSTANCE_PUBLIC_IP"
}

######################################
# Phase 2: Database Migration to RDS, EC2 Image Creation, and v2 Launch
######################################

function phase2() {
    echo "Starting Phase 2: Setting up RDS Security Group"

    execute_command "RDS_SG=\$(aws ec2 create-security-group \
        --group-name \"$RDS_SG_NAME\" \
        --description \"RDS Security Group\" \
        --vpc-id \"$VPC_ID\" \
        --query 'GroupId' \
        --output text)" \
        "Failed to create RDS Security Group."

    execute_command "aws ec2 authorize-security-group-ingress \
        --group-id \"$RDS_SG\" \
        --protocol tcp \
        --port 3306 \
        --source-group \"$LAB_SG\"" \
        "Failed to allow MySQL ingress from EC2 Security Group to RDS Security Group."
    
    execute_command "aws ec2 authorize-security-group-ingress \
        --group-id \"$LAB_SG\" \
        --protocol tcp \
        --port 3306 \
        --source-group \"$RDS_SG\"" \
        "Failed to allow MySQL ingress from RDS Security Group to EC2 Security Group."

    echo "Creating RDS Subnet Group"
    execute_command "aws rds create-db-subnet-group \
        --db-subnet-group-name \"$DBSubnetGroup\" \
        --db-subnet-group-description \"Lab RDS Subnet Group\" \
        --subnet-ids \"$DB_SUBNET1\" \"$DB_SUBNET2\"" \
        "Failed to create RDS DB Subnet Group."

    echo "Creating RDS MySQL instance..."
    execute_command "RDS_INSTANCE=\$(aws rds create-db-instance \
        --db-instance-identifier \"$RDS_IDENTIFIER\" \
        --db-instance-class db.t3.micro \
        --storage-type gp3 \
        --allocated-storage 20 \
        --engine mysql \
        --vpc-security-group-ids \"$RDS_SG\" \
        --availability-zone us-east-1b \
        --db-subnet-group \"$DBSubnetGroup\" \
        --backup-retention-period 1 \
        --multi-az \
        --manage-master-user-password \
        --no-enable-performance-insights \
        --tags Key=Name,Value=\"$RDS_NAME_TAG\" Key=Environment,Value=\"$ENVIRONMENT\" \
        --query 'DBInstance.DBInstanceIdentifier' \
        --output text)" \
        "Failed to create RDS MySQL instance."

    execute_command "aws rds wait db-instance-available \
        --db-instance-identifier \"$RDS_INSTANCE\"" \
        "RDS MySQL instance did not become available in time."

    execute_command "RDS_ENDPOINT=\$(aws rds describe-db-instances \
        --db-instance-identifier \"$RDS_INSTANCE\" \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text)" \
        "Failed to retrieve RDS MySQL endpoint."

    echo "Creating RDS secret for MySQL credentials"
    execute_command "SECRET_ARN=\$(aws secretsmanager create-secret \
        --name \"$SECRET_NAME\" \
        --description \"RDS credentials for $RDS_NAME_TAG\" \
        --secret-string '{\"username\":\"admin\",\"password\":\"beautiful_learning\"}' \
        --force-overwrite-replica-secret \
        --query 'ARN' \
        --output text)" \
        "Failed to create RDS secret."

    echo "Migrating data to RDS..."
    execute_command "mysqldump -h \"$INSTANCE_PUBLIC_IP\" \
        -u nodeapp \
        -pstudent12 \
        --databases STUDENTS > data.sql" \
        "Failed to dump data from EC2 instance."

    execute_command "mysql -h \"$RDS_ENDPOINT\" \
        -u admin \
        -pstudent12 STUDENTS < data.sql" \
        "Failed to migrate data to RDS MySQL instance."

    echo "Creating an EC2-v1 image..."
    execute_command "SERVER_V1_IMAGE_ID=\$(aws ec2 create-image \
        --instance-id \"$INSTANCE_ID\" \
        --name \"$EC2_IMAGE1_NAME\" \
        --query 'ImageId' \
        --output text)" \
        "Failed to create EC2-v1 image."

    execute_command "aws ec2 wait image-available \
        --image-ids \"$SERVER_V1_IMAGE_ID\"" \
        "EC2-v1 image did not become available in time."

    echo "Image created with ID: $SERVER_V1_IMAGE_ID"

    echo "Terminating original EC2-v1"
    execute_command "aws ec2 terminate-instances \
        --instance-ids \"$INSTANCE_ID\"" \
        "Failed to terminate EC2-v1 instance."

    execute_command "aws ec2 wait instance-terminated \
        --instance-ids \"$INSTANCE_ID\"" \
        "EC2-v1 instance was not terminated in time."

    echo "Original EC2-v1 terminated."

    execute_command "aws ec2 create-key-pair \
        --key-name \"$PRIV_KEY\" \
        --query 'KeyMaterial' \
        --output text > \"$PRIV_KEY.pem\"" \
        "Failed to create EC2 private key pair."

    execute_command "chmod 400 \"$PRIV_KEY.pem\"" \
        "Failed to set correct permissions for the EC2 private key."

    echo "Launching EC2-v2 instance..."
    execute_command "NEW_INSTANCE_ID=\$(aws ec2 run-instances \
        --image-id \"$SERVER_V1_IMAGE_ID\" \
        --count 1 \
        --instance-type t2.micro \
        --key-name \"$PRIV_KEY\" \
        --security-group-ids \"$LAB_SG\" \
        --subnet-id \"$PUB_SUBNET1\" \
        --user-data file://\"$USER_DATA_FILE_V2\" \
        --query 'Instances[0].InstanceId' \
        --output text)" \
        "Failed to launch EC2-v2 instance."

    execute_command "aws ec2 wait instance-status-ok \
        --instance-ids \"$NEW_INSTANCE_ID\"" \
        "New EC2 instance did not become status OK in time."

    NEW_INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$NEW_INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)

    echo "New EC2 instance ($EC2_V2_NAME) launched with Public IP: $NEW_INSTANCE_PUBLIC_IP"

    echo "Creating an EC2-v2 image..."
    execute_command "SERVER_V2_IMAGE_ID=\$(aws ec2 create-image \
        --instance-id \"$NEW_INSTANCE_ID\" \
        --name \"$EC2_IMAGE2_NAME\" \
        --query 'ImageId' \
        --output text)" \
        "Failed to create EC2-v2 image."

    execute_command "aws ec2 wait image-available \
        --image-ids \"$SERVER_V2_IMAGE_ID\"" \
        "EC2-v2 image did not become available in time."

    echo "Image created with ID: $SERVER_V2_IMAGE_ID"

    echo "Phase 2 Complete: RDS Endpoint - $RDS_ENDPOINT"

    # Reassign INSTANCE_ID to NEW_INSTANCE_ID for future references
    INSTANCE_ID=$NEW_INSTANCE_ID
}

######################################
# Phase 3: Load Balancer and Auto Scaling Setup
######################################

function phase3() {
    echo "Starting Phase 3: Setting up Load Balancer and Auto Scaling"

    echo "Creating a Launch Template for EC2-v3 instance..."
    execute_command "aws ec2 create-launch-template \
        --launch-template-name \"$LAUNCH_TEMPLATE_NAME\" \
        --launch-template-data \"{
            \\\"ImageId\\\": \\\"$SERVER_V2_IMAGE_ID\\\",
            \\\"InstanceType\\\": \\\"t2.micro\\\",
            \\\"KeyName\\\": \\\"$PRIV_KEY\\\",
            \\\"TagSpecifications\\\": [
                {
                    \\\"ResourceType\\\": \\\"instance\\\",
                    \\\"Tags\\\": [
                        {\\\"Key\\\": \\\"Name\\\", \\\"Value\\\": \\\"$EC2_V2_NAME\\\"}
                    ]
                }
            ]
        }\"" \
        "Failed to create EC2-v3 Launch Template."

    echo "Creating Load Balancer Security Group"
    execute_command "LB_SG=\$(aws ec2 create-security-group \
        --group-name \"$LB_SG_NAME\" \
        --description \"Load Balancer Security Group\" \
        --vpc-id \"$VPC_ID\" \
        --query 'GroupId' \
        --output text)" \
        "Failed to create Load Balancer Security Group."

    execute_command "aws ec2 authorize-security-group-ingress \
        --group-id \"$LB_SG\" \
        --protocol tcp \
        --port 80 \
        --cidr \"$INTERNET_CIDR\"" \
        "Failed to allow HTTP ingress on Load Balancer Security Group."

    echo "Creating Load Balancer"
    execute_command "LB_ARN=\$(aws elbv2 create-load-balancer \
        --name \"$LB_NAME\" \
        --subnets \"$PUB_SUBNET1\" \"$PUB_SUBNET2\" \
        --security-groups \"$LB_SG\" \
        --tags Key=Name,Value=\"$LB_NAME\" \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text)" \
        "Failed to create Load Balancer."

    execute_command "aws elbv2 wait load-balancer-available \
        --load-balancer-arns \"$LB_ARN\"" \
        "Load Balancer did not become available in time."

    echo "Creating Target Group"
    execute_command "TG_ARN=\$(aws elbv2 create-target-group \
        --name \"$TG_NAME\" \
        --protocol HTTP \
        --port 80 \
        --vpc-id \"$VPC_ID\" \
        --tags Key=Name,Value=\"$TG_NAME\" \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text)" \
        "Failed to create Target Group."

    echo "Creating Auto Scaling Group"
    execute_command "aws autoscaling create-auto-scaling-group \
        --auto-scaling-group-name \"$EC2_ASG_NAME\" \
        --min-size 2 \
        --max-size 6 \
        --desired-capacity 2 \
        --vpc-zone-identifier \"$PRIV_SUBNET1,$PRIV_SUBNET2\" \
        --target-group-arns \"$TG_ARN\" \
        --health-check-type ELB \
        --tags Key=Name,Value=\"$EC2_ASG_NAME\" \
        --health-check-grace-period 300 \
        --launch-template \"LaunchTemplateName=$LAUNCH_TEMPLATE_NAME\"" \
        "Failed to create Auto Scaling Group."
    execute_command "LB_DNS=\$(aws elbv2 describe-load-balancers \
        --names \"$LB_NAME\" \
        --query 'LoadBalancers[0].DNSName' \
        --output text)" \
        "Failed to retrieve Load Balancer DNS."

    echo "Phase 3 Complete: Load Balancer and Auto Scaling setup finished."
    echo "Load Balancer DNS: $LB_DNS"
}

######################################
# Phase 4: Load Testing
######################################

function phase4() {
    echo "Starting Phase 4: Load Testing"
    npm install -g loadtest || true

    echo "Running loadtest on the application"
    ELB_URL=$(aws elbv2 describe-load-balancers \
        --names "$LB_NAME" \
        --query 'LoadBalancers[0].DNSName' \
        --output text)

    loadtest \
        --rps 1000 \
        -c 500 \
        -k "$ELB_URL" || true

    echo "Load Testing executed"
}

######################################
# Phase 5: Cleanup
######################################

function Cleaner_helper() {
    echo "Starting Phase 5: Cleanup"

    # Helper function
    check_command_success() {
        if [ $? -eq 0 ]; then
            echo "$1 succeeded."
        else
            echo "$1 failed or resource does not exist. Skipping..."
        fi
    }

    # Scale down ASG before deletion
    if [ -n "$EC2_ASG_NAME" ]; then
        aws autoscaling update-auto-scaling-group \
            --auto-scaling-group-name "$EC2_ASG_NAME" \
            --min-size 0 \
            --desired-capacity 0 || true
        sleep 60
    fi

    # Terminate EC2 instances
    for instance_id in "$INSTANCE_ID" "$NEW_INSTANCE_ID"; do
        if [ -n "$instance_id" ]; then
            echo "Terminating EC2 instance: $instance_id"
            aws ec2 terminate-instances \
                --instance-ids "$instance_id" || true
            aws ec2 wait instance-terminated \
                --instance-ids "$instance_id" || true
            check_command_success "Terminating EC2 instance $instance_id"
        fi
    done

    # Delete Launch Template
    echo "Deleting Launch Template..."
    if aws ec2 describe-launch-templates --launch-template-names "$LAUNCH_TEMPLATE_NAME" > /dev/null 2>&1; then
        aws ec2 delete-launch-template \
            --launch-template-name "$LAUNCH_TEMPLATE_NAME"
        check_command_success "Deleting Launch Template"
    fi

    # Deregister AMI
    if [ -n "$SERVER_V2_IMAGE_ID" ]; then
        aws ec2 deregister-image \
            --image-id "$SERVER_V2_IMAGE_ID"
        echo "AMI deregistered."
    fi

    # Delete associated snapshot if any
    if [ -n "$SNAPSHOT_ID" ]; then
        aws ec2 delete-snapshot \
            --snapshot-id "$SNAPSHOT_ID"
        echo "Snapshot deleted."
    fi

    # Delete RDS instance
    echo "Deleting RDS instance..."
    if aws rds describe-db-instances --db-instance-identifier "$RDS_IDENTIFIER" > /dev/null 2>&1; then
        aws rds delete-db-instance \
            --db-instance-identifier "$RDS_IDENTIFIER" \
            --skip-final-snapshot
        aws rds wait db-instance-deleted \
            --db-instance-identifier "$RDS_IDENTIFIER"
        check_command_success "Deleting RDS instance"
    fi

    # Delete RDS Secret
    echo "Deleting RDS secret..."
    if [ -n "$SECRET_ARN" ]; then
        aws secretsmanager delete-secret \
            --secret-id "$SECRET_ARN" \
            --force-delete-without-recovery
        check_command_success "Deleting RDS secret"
    fi

    # Delete Load Balancer and Target Group
    echo "Deleting Load Balancer..."
    if [ -n "$LB_ARN" ]; then
        aws elbv2 delete-load-balancer \
            --load-balancer-arn "$LB_ARN"
        check_command_success "Deleting Load Balancer"
        sleep 30
    fi

    echo "Deleting Target Group..."
    if [ -n "$TG_ARN" ]; then
        aws elbv2 delete-target-group \
            --target-group-arn "$TG_ARN"
        check_command_success "Deleting Target Group"
    fi

    # Delete Auto Scaling Group
    echo "Deleting Auto Scaling Group..."
    if [ -n "$EC2_ASG_NAME" ]; then
        aws autoscaling delete-auto-scaling-group \
            --auto-scaling-group-name "$EC2_ASG_NAME" \
            --force-delete
        check_command_success "Deleting Auto Scaling Group"
    fi

    # Delete Security Groups
    echo "Deleting Security Groups..."
    for sg_id in "$LAB_SG" "$RDS_SG" "$LB_SG"; do
        if [ -n "$sg_id" ]; then
            aws ec2 delete-security-group \
                --group-id "$sg_id" || true
            check_command_success "Deleting Security Group $sg_id"
        fi
    done

    # Delete NAT Gateway and Elastic IP
    echo "Deleting NAT Gateway..."
    if [ -n "$NAT_GW_ID" ]; then
        aws ec2 delete-nat-gateway \
            --nat-gateway-id "$NAT_GW_ID" || true
        aws ec2 wait nat-gateway-deleted \
            --nat-gateway-ids "$NAT_GW_ID" || true
        check_command_success "Deleting NAT Gateway"
        sleep 60
    fi

    echo "Releasing Elastic IP..."
    if [ -n "$EIP_ALLOC" ]; then
        aws ec2 release-address \
            --allocation-id "$EIP_ALLOC" || true
        check_command_success "Releasing Elastic IP"
    fi

    echo "Detaching and deleting Internet Gateway..."
    if [ -n "$IGW_ID" ] && [ -n "$VPC_ID" ]; then
        aws ec2 detach-internet-gateway \
            --internet-gateway-id "$IGW_ID" \
            --vpc-id "$VPC_ID" || true
        aws ec2 delete-internet-gateway \
            --internet-gateway-id "$IGW_ID" || true
        check_command_success "Deleting Internet Gateway"
    fi

    # Delete Subnets
    echo "Deleting Subnets..."
    for subnet_id in "$PUB_SUBNET1" "$PUB_SUBNET2" "$PRIV_SUBNET1" "$PRIV_SUBNET2" "$DB_SUBNET1" "$DB_SUBNET2"; do
        if [ -n "$subnet_id" ]; then
            aws ec2 delete-subnet \
                --subnet-id "$subnet_id" || true
            aws ec2 wait subnet-deleted \
                --subnet-id "$subnet_id" || true
            check_command_success "Deleting Subnet $subnet_id"
        fi
    done

    # Delete RDS DB Subnet Group
    echo "Deleting DB Subnet Group..."
    aws rds delete-db-subnet-group \
        --db-subnet-group-name "$DBSubnetGroup" || true
    check_command_success "Deleting RDS DB Subnet Group $DBSubnetGroup"

    # Delete Route Tables
    if [ -n "$PUB_ROUTE_TABLE" ]; then
        aws ec2 delete-route-table \
            --route-table-id "$PUB_ROUTE_TABLE" || true
        check_command_success "Deleting Route Table $PUB_ROUTE_TABLE"
    fi

    if [ -n "$DB_ROUTE_TABLE" ]; then
        aws ec2 delete-route-table \
            --route-table-id "$DB_ROUTE_TABLE" || true
        check_command_success "Deleting Route Table $DB_ROUTE_TABLE"
    fi

    # Delete VPC
    echo "Deleting VPC..."
    if [ -n "$VPC_ID" ]; then
        aws ec2 delete-vpc \
            --vpc-id "$VPC_ID" || true
        check_command_success "Deleting VPC"
    fi

    echo "Phase 5 Complete: All resources checked and deleted as necessary."
}

######################################
# Main Script Execution
######################################

while true; do
    echo "######################################"
    echo "# Prompts to Execute Phases 1-5"
    echo "######################################"

    # Prompt for each phase
    prompt_phase 1 phase1 "Phase 1"
    prompt_phase 2 phase2 "Phase 2"
    prompt_phase 3 phase3 "Phase 3"
    prompt_phase 4 phase4 "Phase 4"
    prompt_phase 5 Cleaner_helper "Phase 5"

    echo "All phases have been processed."

    # Optionally, ask the user if they want to run the phases again
    read -p "Do you want to run the phases again? (yes/no): " repeat
    repeat="${repeat,,}"  # Convert input to lowercase

    if [[ "$repeat" != "yes" ]]; then
        echo "Exiting the script."
        exit 0
    fi
done

# End of script