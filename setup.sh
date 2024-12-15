#!/bin/bash

# Description: This script is used to create the necessary resources for the Inventory application.

############################################################################################################
# User Inputs
############################################################################################################
# User Public IP, Cloud9 Private IP
USER_PUBLIC_IP_INPUT="68.50.23.166" # Change this to your public IP for local SSH access to instances
CLOUD9_INSTANCE_ID="i-09148fc063df1a9c6" # Change this to your Cloud9 instance ARN
# Availability Zones 
AVAILABILITY_ZONE1="us-east-1a" # Change this to your preferred availability zone
AVAILABILITY_ZONE2="us-east-1b" # Change this to your preferred availability zone
# Select whether to use a sample database or the 
DEFAULT_DB_FILE="sample_entries.sql" # Modify this file's entries if you want to use it.
# DEFAULT_DB_FILE="data.sql"
############################################################################################################

#Using CLOUD9_PRIVATE_IP_INPUT to get the Cloud9 Details
CLOUD9_PRIVATE_IP_INPUT=$(aws ec2 describe-instances \
    --instance-ids $CLOUD9_INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)
CLOUD9_SG=$(aws ec2 describe-instances \
    --instance-ids $CLOUD9_INSTANCE_ID \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text)



# Defining variables for IPs
USER_IP=$USER_PUBLIC_IP_INPUT
CLOUD9_IP=$CLOUD9_PRIVATE_IP_INPUT

######################################
# Predefined Static Variables for All Resources
######################################

# VPC and Subnet Names
VPC_NAME="Inventory-VPC"
PUB_SUBNET1_NAME="Inventory-Public-Subnet1"
PUB_SUBNET2_NAME="Inventory-Public-Subnet2"
PRIV_SUBNET1_NAME="Inventory-Private-Subnet1"
PRIV_SUBNET2_NAME="Inventory-Private-Subnet2"
DB_SUBNET1_NAME="Inventory-DB-Subnet1"
DB_SUBNET2_NAME="Inventory-DB-Subnet2"
# CIDR Blocks
VPC_CIDR="192.168.0.0/16"
PUB_SUBNET1_CIDR="192.168.1.0/24"
PUB_SUBNET2_CIDR="192.168.2.0/24"
PRIV_SUBNET1_CIDR="192.168.3.0/24"
PRIV_SUBNET2_CIDR="192.168.4.0/24"
DB_SUBNET1_CIDR="192.168.5.0/24"
DB_SUBNET2_CIDR="192.168.6.0/24"
INTERNET_CIDR="0.0.0.0/0"
aws configure set region us-east-1

# Security Group Names
EC2_SG_NAME="Inventory-Server-SG"
RDS_SG_NAME="Inventory-DB-SG"
LB_SG_NAME="Inventory-LB-SG"
# Route Table Names
PUB_ROUTE_TABLE_NAME="Inventory-Public-Route-Table"
PRIV_ROUTE_TABLE_NAME="Inventory-Private-Route-Table"
DB_ROUTE_TABLE_NAME="Inventory-DB-Route-Table"
# Gateway Tags
IGW_TAG="Inventory-IGW"
NAT_GW_TAG="Inventory-NAT"
EIP_TAG="Inventory-EIP"
# RDS Subnet Group Name
DBSubnetGroup="Inventory-DB-Subnet-Group"

# Instance Profile
INVENTORY_SERVER_ROLE="LabInstanceProfile"
# Ubuntu AMI ID
AMI_ID="ami-0e2c8caa4b6378d8c"
# Key Pairs
PUB_KEY="Public-EC2-KeyPair"
PRIV_KEY="Private-EC2-KeyPair"
# User Data Files
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
USER_DATA_FILE_V1="phase1_userdata.sh"
USER_DATA_FILE_V2="phase2_userdata.sh"
ASG_config="ASG_config.json"  
# EC2 Instance and Image Names
EC2_V1_NAME="Inventory-Server-v1"
EC2_V2_NAME="Inventory-Server-v2"
EC2_IMAGE1_NAME="Inventory-Server-v1-Image"
EC2_IMAGE2_NAME="Inventory-Server-v2-Image"

# Secrets Manager Name
SECRET_NAME="Test-Secret-v7"
SECRET_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12)
SECRET_USERNAME="admin"
# RDS Identifier and Tags
RDS_IDENTIFIER="Inventory-DB"
RDS_NAME_TAG="Inventory-DB"
ENVIRONMENT="Dev"

# Load Balancer and Target Group
LB_NAME="Inventory-Server-LB"
TG_NAME="Inventory-Server-TG"
# Auto Scaling
EC2_ASG_NAME="Inventory-Server-v3-ASG"
ASG_POLICY_NAME="CPU50PercentPolicy"
LAUNCH_TEMPLATE_NAME="ASG-Launch-Template"

######################################
# Variables that will be set dynamically
######################################
# VPC_ID=""
# MAIN_ROUTE_TABLE_ID=""
# PUB_SUBNET1=""
# PUB_SUBNET2=""
# PRIV_SUBNET1=""
# PRIV_SUBNET2=""
# DB_SUBNET1=""
# DB_SUBNET2=""
# PRIV_ROUTE_TABLE=""
# DB_ROUTE_TABLE=""
# IGW_ID=""
# EIP_ALLOC=""
# NAT_GW_ID=""
# LAB_SG=""
# RDS_SG=""
# LB_SG=""
# LB_ARN=""
# LB_DNS=""
# TG_ARN=""
# INSTANCE_ID=""
# NEW_INSTANCE_ID=""
# SERVER_V2_IMAGE_ID=""
# SECRET_ARN=""
# RDS_INSTANCE=""
# RDS_ENDPOINT=""
# TERMINATED_INSTANCE=""
# PEERING_CONNECTION_ID=""
# DEFAULT_VPC_ID="" 
# DEFAULT_VPC_CIDR=""
# DEFAULT_ROUTE_TABLE_ID=""
# DBSubnetGroup=""
# DB_SUBNET_GROUP_DETAILS=""

######################################
# Phase 1: VPC, Subnets, and EC2 with In-Memory Database
######################################

phase1() {

    # Initialize status variable to track failures
    local status=0

    if [[ $status -eq 0 ]]; then
        execute_command "VPC_ID=\$(aws ec2 create-vpc \
            --cidr-block \"$VPC_CIDR\" \
            --query 'Vpc.VpcId' \
            --output text)" \
            "Failed to create VPC."
        status=$?
    fi


    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-tags \
            --resources \"$VPC_ID\" \
            --tags Key=Name,Value=\"$VPC_NAME\"" \
            "Failed to tag VPC."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 wait vpc-available \
            --vpc-ids \"$VPC_ID\"" \
            "VPC did not become available in time."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        echo "Creating Subnets"
        execute_command "PUB_SUBNET1=\$(aws ec2 create-subnet \
            --vpc-id \"$VPC_ID\" \
            --cidr-block \"$PUB_SUBNET1_CIDR\" \
            --availability-zone $AVAILABILITY_ZONE1 \
            --query 'Subnet.SubnetId' \
            --output text)" \
            "Failed to create Public Subnet 1."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-tags \
            --resources \"$PUB_SUBNET1\" \
            --tags Key=Name,Value=\"$PUB_SUBNET1_NAME\"" \
            "Failed to tag Public Subnet 1."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "PUB_SUBNET2=\$(aws ec2 create-subnet \
            --vpc-id \"$VPC_ID\" \
            --cidr-block \"$PUB_SUBNET2_CIDR\" \
            --availability-zone $AVAILABILITY_ZONE2 \
            --query 'Subnet.SubnetId' \
            --output text)" \
            "Failed to create Public Subnet 2."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-tags \
            --resources \"$PUB_SUBNET2\" \
            --tags Key=Name,Value=\"$PUB_SUBNET2_NAME\"" \
            "Failed to tag Public Subnet 2."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "PRIV_SUBNET1=\$(aws ec2 create-subnet \
            --vpc-id \"$VPC_ID\" \
            --cidr-block \"$PRIV_SUBNET1_CIDR\" \
            --availability-zone $AVAILABILITY_ZONE1 \
            --query 'Subnet.SubnetId' \
            --output text)" \
            "Failed to create Private Subnet 1."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-tags \
            --resources \"$PRIV_SUBNET1\" \
            --tags Key=Name,Value=\"$PRIV_SUBNET1_NAME\"" \
            "Failed to tag Private Subnet 1."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "PRIV_SUBNET2=\$(aws ec2 create-subnet \
            --vpc-id \"$VPC_ID\" \
            --cidr-block \"$PRIV_SUBNET2_CIDR\" \
            --availability-zone $AVAILABILITY_ZONE2 \
            --query 'Subnet.SubnetId' \
            --output text)" \
            "Failed to create Private Subnet 2."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-tags \
            --resources \"$PRIV_SUBNET2\" \
            --tags Key=Name,Value=\"$PRIV_SUBNET2_NAME\"" \
            "Failed to tag Private Subnet 2."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "DB_SUBNET1=\$(aws ec2 create-subnet \
            --vpc-id \"$VPC_ID\" \
            --cidr-block \"$DB_SUBNET1_CIDR\" \
            --availability-zone $AVAILABILITY_ZONE1 \
            --query 'Subnet.SubnetId' \
            --output text)" \
            "Failed to create DB Subnet 1."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-tags \
            --resources \"$DB_SUBNET1\" \
            --tags Key=Name,Value=\"$DB_SUBNET1_NAME\"" \
            "Failed to tag DB Subnet 1."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "DB_SUBNET2=\$(aws ec2 create-subnet \
            --vpc-id \"$VPC_ID\" \
            --cidr-block \"$DB_SUBNET2_CIDR\" \
            --availability-zone $AVAILABILITY_ZONE2 \
            --query 'Subnet.SubnetId' \
            --output text)" \
            "Failed to create DB Subnet 2."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-tags \
            --resources \"$DB_SUBNET2\" \
            --tags Key=Name,Value=\"$DB_SUBNET2_NAME\"" \
            "Failed to tag DB Subnet 2."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 wait subnet-available \
            --subnet-ids \"$PUB_SUBNET1\" \"$PUB_SUBNET2\" \"$PRIV_SUBNET1\" \"$PRIV_SUBNET2\" \"$DB_SUBNET1\" \"$DB_SUBNET2\"" \
            "Subnets did not become available in time."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 modify-subnet-attribute \
            --subnet-id \"$PUB_SUBNET1\" \
            --map-public-ip-on-launch || true" \
            "Failed to modify subnet attribute for Public Subnet 1."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 modify-subnet-attribute \
            --subnet-id \"$PUB_SUBNET2\" \
            --map-public-ip-on-launch || true" \
            "Failed to modify subnet attribute for Public Subnet 2."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        echo "Creating Public Route Table and attaching with Private Subnets"
        execute_command "MAIN_ROUTE_TABLE_ID=\$(aws ec2 describe-route-tables \
            --filters \"Name=vpc-id,Values=$VPC_ID\" \
            \"Name=association.main,Values=true\" \
            --query \"RouteTables[0].RouteTableId\" \
            --output text)" \
            "Failed to describe main route table."
        status=$?
    fi
    # Rename the main route table
    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-tags \
            --resources \"$MAIN_ROUTE_TABLE_ID\" \
            --tags Key=Name,Value=\"$PUB_ROUTE_TABLE_NAME\"" \
            "Failed to tag main route table."
        status=$?
    fi
    if [[ $status -eq 0 ]]; then
        echo "Associating Public Subnet 1 with route table..."
        execute_command "result=\$(aws ec2 associate-route-table \
            --route-table-id \"$MAIN_ROUTE_TABLE_ID\" \
            --subnet-id \"$PUB_SUBNET1\" 2>&1)" \
            "Failed to associate Public Subnet 1 with route table."
        if [[ $? -ne 0 ]]; then
            status=1 # Mark failure
        else
            echo "Successfully associated Public Subnet 1 with route table."
            echo "Details: $result"
        fi
    fi

    if [[ $status -eq 0 ]]; then
        echo "Associating Public Subnet 2 with route table..."
        execute_command "result=\$(aws ec2 associate-route-table \
            --route-table-id \"$MAIN_ROUTE_TABLE_ID\" \
            --subnet-id \"$PUB_SUBNET2\" 2>&1)" \
            "Failed to associate Public Subnet 2 with route table."
        if [[ $? -ne 0 ]]; then
            status=1 # Mark failure
        else
            echo "Successfully associated Public Subnet 2 with route table."
            echo "Details: $result"
        fi
    fi

    if [[ $status -eq 0 ]]; then
        echo "Creating Private Route Table and attaching to Public Subnets"
        execute_command "PRIV_ROUTE_TABLE=\$(aws ec2 create-route-table \
            --vpc-id \"$VPC_ID\" \
            --query 'RouteTable.RouteTableId' \
            --output text)" \
            "Failed to create Public Route Table."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-tags \
            --resources \"$PRIV_ROUTE_TABLE\" \
            --tags Key=Name,Value=\"$PRIV_ROUTE_TABLE_NAME\"" \
            "Failed to tag Public Route Table."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "result=\$(aws ec2 associate-route-table \
            --route-table-id "$PRIV_ROUTE_TABLE" \
            --subnet-id "$PRIV_SUBNET1" 2>&1)" \
            "Failed to associate Private Subnet 1 with route table."

        if [[ $? -ne 0 ]]; then
            status=1 # Mark failure
        else
            echo "Successfully associated Private Subnet 1 with route table."
            echo "Details: $result"
        fi
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "result=\$(aws ec2 associate-route-table \
            --route-table-id "$PRIV_ROUTE_TABLE" \
            --subnet-id "$PRIV_SUBNET2" 2>&1)" \
            "Failed to associate Private Subnet 2 with route table."

        if [[ $? -ne 0 ]]; then
            status=1 # Mark failure
        else
            echo "Successfully associated Private Subnet 2 with route table."
            echo "Details: $result"
        fi
    fi

    if [[ $status -eq 0 ]]; then
        echo "Creating DB Route Table and attaching to DB Subnets"
        execute_command "DB_ROUTE_TABLE=\$(aws ec2 create-route-table \
            --vpc-id \"$VPC_ID\" \
            --query 'RouteTable.RouteTableId' \
            --output text)" \
            "Failed to create DB Route Table."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-tags \
            --resources \"$DB_ROUTE_TABLE\" \
            --tags Key=Name,Value=\"$DB_ROUTE_TABLE_NAME\"" \
            "Failed to tag DB Route Table."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        result=$(aws ec2 associate-route-table \
            --route-table-id "$DB_ROUTE_TABLE" \
            --subnet-id "$DB_SUBNET1" 2>&1)
        if [[ $? -ne 0 ]]; then
            status=1 # Mark failure
        else
            echo "Successfully associated DB Subnet 1 with DB Route Table."
            echo "Details: $result"
        fi
    fi

    if [[ $status -eq 0 ]]; then
        result=$(aws ec2 associate-route-table \
            --route-table-id "$DB_ROUTE_TABLE" \
            --subnet-id "$DB_SUBNET2" 2>&1)
        if [[ $? -ne 0 ]]; then
            status=1 # Mark failure
        else
            echo "Successfully associated DB Subnet 2 with DB Route Table."
            echo "Details: $result"
        fi
    fi

    if [[ $status -eq 0 ]]; then
        echo "Creating Internet Gateway, attaching and creating routes"
        execute_command "IGW_ID=\$(aws ec2 create-internet-gateway \
            --query 'InternetGateway.InternetGatewayId' \
            --output text)" \
            "Failed to create Internet Gateway."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-tags \
            --resources \"$IGW_ID\" \
            --tags Key=Name,Value=\"$IGW_TAG\"" \
            "Failed to tag Internet Gateway."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 attach-internet-gateway \
            --vpc-id \"$VPC_ID\" \
            --internet-gateway-id \"$IGW_ID\"" \
            "Failed to attach Internet Gateway."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-route \
            --route-table-id \"$MAIN_ROUTE_TABLE_ID\" \
            --destination-cidr-block \"$INTERNET_CIDR\" \
            --gateway-id \"$IGW_ID\"" \
            "Failed to create route for Internet Gateway."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        echo "Creating Elastic IP"
        execute_command "EIP_ALLOC=\$(aws ec2 allocate-address \
            --query 'AllocationId' \
            --output text)" \
            "Failed to allocate Elastic IP."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-tags \
            --resources \"$EIP_ALLOC\" \
            --tags Key=Name,Value=\"$EIP_TAG\"" \
            "Failed to tag Elastic IP."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        echo "Creating NAT Gateway"
        execute_command "NAT_GW_ID=\$(aws ec2 create-nat-gateway \
            --subnet-id \"$PUB_SUBNET1\" \
            --allocation-id \"$EIP_ALLOC\" \
            --query 'NatGateway.NatGatewayId' \
            --output text)" \
            "Failed to create NAT Gateway."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-tags \
            --resources \"$NAT_GW_ID\" \
            --tags Key=Name,Value=\"$NAT_GW_TAG\"" \
            "Failed to tag NAT Gateway."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 wait nat-gateway-available \
            --nat-gateway-ids \"$NAT_GW_ID\"" \
            "NAT Gateway did not become available in time."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-route \
            --route-table-id \"$PRIV_ROUTE_TABLE\" \
            --destination-cidr-block \"$INTERNET_CIDR\" \
            --nat-gateway-id \"$NAT_GW_ID\"" \
            "Failed to create route for NAT Gateway."
        status=$?
    fi

    # Retrieve the Default VPC ID
    if [[ $status -eq 0 ]]; then
        echo "Creating VPC Peering Connection between Default VPC and Inventory VPC"
        execute_command "DEFAULT_VPC_ID=\$(aws ec2 describe-vpcs \
            --filters \"Name=isDefault,Values=true\" \
            --query 'Vpcs[0].VpcId' \
            --output text)" \
            "Failed to retrieve default VPC ID."
        status=$?
    fi
    #Retrieve the Default VPC CIDR
    if [[ $status -eq 0 ]]; then
        execute_command "DEFAULT_VPC_CIDR=\$(aws ec2 describe-vpcs \
            --filters \"Name=isDefault,Values=true\" \
            --query 'Vpcs[0].CidrBlock' \
            --output text)" \
            "Failed to retrieve default VPC CIDR."
        status=$?
    fi
    #Retrieve the DEFAULT VPC Route Table ID
    if [[ $status -eq 0 ]]; then
        execute_command "DEFAULT_ROUTE_TABLE_ID=\$(aws ec2 describe-route-tables \
            --filters \"Name=vpc-id,Values=$DEFAULT_VPC_ID\" \
            --query 'RouteTables[?Associations[0].Main].RouteTableId' \
            --output text)" \
            "Failed to retrieve default VPC route table ID."
        status=$?
    fi
    if [[ $status -eq 0 ]]; then
        # Create a VPC peering connection and capture any errors
        echo "Creating VPC Peering Connection"
        execute_command "PEERING_CONNECTION_ID=\$(aws ec2 create-vpc-peering-connection \
            --vpc-id \"$DEFAULT_VPC_ID\" \
            --peer-vpc-id \"$VPC_ID\" \
            --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
            --output text)" \
            "Failed to create VPC peering connection."
    fi

    if [[ $status -eq 0 ]]; then
        # Accept the VPC peering connection and capture any errors
        echo "Accepting VPC Peering Connection"
        execute_command "VCP_DETAILS=\$(aws ec2 accept-vpc-peering-connection \
            --vpc-peering-connection-id "$PEERING_CONNECTION_ID" 2>&1)" \
            "Failed to accept VPC peering connection."
        status=$?

        # Check if the command was successful
        if [[ $status -ne 0 ]]; then
            status=1 # Mark failure
        else
            echo "VPC peering connection accepted successfully."
        fi
    fi

    echo "Updating Route Tables for VPC Peering Connection"

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-route \
            --route-table-id \"$MAIN_ROUTE_TABLE_ID\" \
            --destination-cidr-block \"$DEFAULT_VPC_CIDR\" \
            --vpc-peering-connection-id \"$PEERING_CONNECTION_ID\"" \
            "Failed to update Inventory VPC route table for peering connection."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-route \
            --route-table-id \"$DEFAULT_ROUTE_TABLE_ID\" \
            --destination-cidr-block \"$VPC_CIDR\" \
            --vpc-peering-connection-id \"$PEERING_CONNECTION_ID\"" \
            "Failed to update Default VPC route table for peering connection."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        echo "Creating Security Groups"
        execute_command "LAB_SG=\$(aws ec2 create-security-group \
            --group-name \"$EC2_SG_NAME\" \
            --description \"Inventory Server Security Group\" \
            --vpc-id \"$VPC_ID\" \
            --query 'GroupId' \
            --output text)" \
            "Failed to create EC2 Security Group."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        AUTH_SECURITY_GROUP=$(aws ec2 authorize-security-group-ingress \
            --group-id "$LAB_SG" \
            --protocol tcp \
            --port 80 \
            --cidr "$INTERNET_CIDR" 2>&1)
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        AUTH_SECURITY_GROUP=$(aws ec2 authorize-security-group-ingress \
            --group-id "$LAB_SG" \
            --protocol tcp \
            --port 22 \
            --cidr "$USER_IP/32" 2>&1)
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        AUTH_SECURITY_GROUP=$(aws ec2 authorize-security-group-ingress \
            --group-id "$LAB_SG" \
            --protocol tcp \
            --port 22 \
            --cidr "$CLOUD9_IP/32" 2>&1)
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        AUTH_SECURITY_GROUP=$(aws ec2 authorize-security-group-ingress \
            --group-id "$CLOUD9_SG" \
            --protocol tcp \
            --port 22 \
            --source-group "$LAB_SG")
        status=$?
    fi


    if [[ $status -eq 0 ]]; then
        echo "Creating and saving EC2-v1 key pair..."
        execute_command "aws ec2 create-key-pair \
            --key-name \"$PUB_KEY\" \
            --query 'KeyMaterial' \
            --output text > \"$PUB_KEY.pem\"" \
            "Failed to create EC2 key pair."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "chmod 400 \"$PUB_KEY.pem\"" \
            "Failed to set correct permissions for the EC2 key pair."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        echo "Launching EC2-v1 instance..."
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
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 wait instance-running \
            --instance-ids \"$INSTANCE_ID\"" \
            "EC2 instance did not start within the expected time."
            execute_command "aws ec2 wait instance-status-ok \
            --instance-ids \"$INSTANCE_ID\" \
            --cli-read-timeout 0" \
            "EC2 instance did not pass status checks within the expected time."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)" \
            "Failed to retrieve EC2 instance public IP."
        # obtain the private IP address of the EC2 instance
        execute_command "INSTANCE_PRIVATE_IP=$(aws ec2 describe-instances \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PrivateIpAddress' \
            --output text)" \
            "Failed to retrieve EC2 instance private IP." 
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        echo -e "\n\n\n"
        echo "######################################"
        echo "# Phase 1 Completed Successfully."
        echo "# You can access the application at http://$INSTANCE_PUBLIC_IP"
        echo "# Please wait for the instance to be ready."
        echo "# Insert data into the application DB on the web page"
        echo "######################################"
    else
        echo -e "\n\n\n"
        echo "######################################"
        echo "# Phase 1 Failed: Please check the last error message above."
        echo "# Please check log files dumped in the Cloud9 directory for more information."
        echo "######################################"
    fi

}

######################################
# Phase 2: Database Migration to RDS, EC2 Image Creation, and v2 Launch
######################################

phase2() {    
    echo -e "\n\n\n"
    echo "######################################"
    echo "# Starting Phase 2: Migration to RDS"
    echo "# version #2 Application Launch for communication with RDS"
    echo "# Server v1 image backup and termination"
    echo "######################################"

    # Initialize status variable to track failures
    local status=0

    if [[ $status -eq 0 ]]; then
        echo "Creating RDS Subnet Group..."
        execute_command "DB_SUBNET_GROUP_DETAILS=\$(aws rds create-db-subnet-group \
            --db-subnet-group-name \"$DBSubnetGroup\" \
            --db-subnet-group-description \"Inventory RDS Subnet Group\" \
            --subnet-ids \"$DB_SUBNET1\" \"$DB_SUBNET2\" \
            --output text)" \
            "Failed to create RDS DB Subnet Group." 
        status=$?
    fi

    echo "Creating RDS secret for MySQL credentials"
    if [[ $status -eq 0 ]]; then
        echo "Creating RDS secret in Secrets Manager..."
        execute_command "SECRET_ARN=\$(aws secretsmanager create-secret \
            --name \"$SECRET_NAME\" \
            --description \"RDS credentials for $RDS_NAME_TAG\" \
            --secret-string '{\"username\":\"$SECRET_USERNAME\",\"password\":\"$SECRET_PASSWORD\"}' \
            --force-overwrite-replica-secret \
            --query 'ARN' \
            --output text)" \
            "Failed to create RDS secret."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "RDS_SG=\$(aws ec2 create-security-group \
            --group-name \"$RDS_SG_NAME\" \
            --description \"RDS Security Group\" \
            --vpc-id \"$VPC_ID\" \
            --query 'GroupId' \
            --output text)" \
            "Failed to create RDS Security Group."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        AUTH_SECURITY_GROUP=$(aws ec2 authorize-security-group-ingress \
            --group-id "$LAB_SG" \
            --protocol tcp \
            --port 3306 \
            --source-group "$RDS_SG" 2>&1)
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        AUTH_SECURITY_GROUP=$(aws ec2 authorize-security-group-ingress \
            --group-id "$RDS_SG" \
            --protocol tcp \
            --port 3306 \
            --source-group "$LAB_SG" 2>&1)
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws ec2 create-key-pair \
            --key-name \"$PRIV_KEY\" \
            --query 'KeyMaterial' \
            --output text > \"$PRIV_KEY.pem\"" \
            "Failed to create EC2 private key pair."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        echo "Saving EC2-v2 Key Pair..."
        execute_command "chmod 400 \"$PRIV_KEY.pem\"" \
            "Failed to set correct permissions for the EC2 private key."
        status=$?
    fi

    echo "Creating an EC2-v1 image..."
    if [[ $status -eq 0 ]]; then
        execute_command "SERVER_V1_IMAGE_ID=\$(aws ec2 create-image \
            --instance-id \"$INSTANCE_ID\" \
            --name \"$EC2_IMAGE1_NAME\" \
            --query 'ImageId' \
            --output text)" \
            "Failed to create EC2-v1 image."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        echo "Launching EC2-v2 instance..."
        execute_command "NEW_INSTANCE_ID=\$(aws ec2 run-instances \
            --image-id \"$AMI_ID\" \
            --count 1 \
            --instance-type t2.micro \
            --key-name \"$PRIV_KEY\" \
            --security-group-ids \"$LAB_SG\" \
            --subnet-id \"$PUB_SUBNET1\" \
            --user-data file://\"$USER_DATA_FILE_V2\" \
            --iam-instance-profile Name=$INVENTORY_SERVER_ROLE \
            --tag-specifications \"ResourceType=instance,Tags=[{Key=Name,Value=$EC2_V1_NAME}]\" \
            --query 'Instances[0].InstanceId' \
            --output text)" \
            "Failed to launch EC2-v2 instance."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        echo "Creating RDS MySQL instance with secret..."
        execute_command "RDS_INSTANCE=\$(aws rds create-db-instance \
            --db-instance-identifier "$RDS_IDENTIFIER" \
            --db-instance-class db.t3.micro \
            --storage-type gp3 \
            --allocated-storage 20 \
            --engine mysql \
            --availability-zone $AVAILABILITY_ZONE1 \
            --master-username $SECRET_USERNAME \
            --master-user-password $SECRET_PASSWORD \
            --vpc-security-group-ids "$RDS_SG" \
            --backup-retention-period 1 \
            --no-enable-performance-insights \
            --query 'DBInstance.DBInstanceIdentifier' \
            --output text)" \
            "Failed to create RDS MySQL instance."
        status=$?
    fi



    if [[ $status -eq 0 ]]; then
        execute_command "aws rds wait db-instance-available \
            --db-instance-identifier "$RDS_INSTANCE" \
            --cli-read-timeout 0" \
            "RDS MySQL instance did not become available in time."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "RDS_ENDPOINT=\$(aws rds describe-db-instances \
            --db-instance-identifier \"$RDS_INSTANCE\" \
            --query 'DBInstances[0].Endpoint.Address' \
            --output text)" \
            "Failed to retrieve RDS MySQL endpoint."
        status=$?
    fi

# Step 1: Login, export a database instance, and copy the dump to the Cloud9 instance
echo '############################################################################################################'
ssh -i $SCRIPT_DIR/$PUB_KEY.pem -o StrictHostKeyChecking=no ubuntu@$INSTANCE_PRIVATE_IP << 'EOF' # Login to instance 1
echo '----------------------------------------------------------------------------------------------------------------'
mysqldump -u nodeapp -pstudent12 --databases STUDENTS > /tmp/data.sql # Export the database
echo '----------------------------------------------------------------------------------------------------------------'
EOF
scp -i $SCRIPT_DIR/$PUB_KEY.pem -o StrictHostKeyChecking=no ubuntu@$INSTANCE_PRIVATE_IP:/tmp/data.sql $SCRIPT_DIR/data.sql # Copy the dump to the Cloud9 instance
echo '############################################################################################################'


# Step 2: Login, copy the dump to the new instance, and import the dump into the database
ssh -i $SCRIPT_DIR/$PRIV_KEY.pem -o StrictHostKeyChecking=no ubuntu@$NEW_INSTANCE_PRIVATE_IP << 'EOF' # Login to instance 2
echo '----------------------------------------------------------------------------------------------------------------'
mysql -h $RDS_ENDPOINT -u $SECRET_USERNAME -p$SECRET_PASSWORD -e 'CREATE DATABASE STUDENTS' # Create the database
echo '----------------------------------------------------------------------------------------------------------------'
mysql -h $RDS_ENDPOINT -u $SECRET_USERNAME -p$SECRET_PASSWORD STUDENTS < $SCRIPT_DIR/$DEFAULT_DB_FILE
echo '############################################################################################################'
EOF

# Step 2: Copy the SQL dump from instance 1 to the source directory on Cloud9
scp -i ./Public-EC2-KeyPair.pem -o StrictHostKeyChecking=no ubuntu@<REMOTE_INSTANCE_1_PUBLIC_IP>:/tmp/data.sql ./data.sql

# Step 3: Create the "STUDENTS" database on RDS via remote instance 2
ssh -i ./Private-EC2-KeyPair.pem -o StrictHostKeyChecking=no ubuntu@192.168.1.230 << 'EOF'
echo 'Creating STUDENTS database on the RDS instance...'
mysql -h inventory-db.choq2jj89uyi.us-east-1.rds.amazonaws.com -u admin -p0yNjVaYA0DLU -e 'CREATE DATABASE STUDENTS;'
echo 'Database STUDENTS created successfully.'
EOF

# Step 4: Copy the dump from Cloud9 to remote instance 2
scp -i ./Private-EC2-KeyPair.pem -o StrictHostKeyChecking=no ./data.sql ubuntu@192.168.1.230:/tmp/data.sql

# Step 5: Push the dump from remote instance 2 to the RDS database
ssh -i ./Private-EC2-KeyPair.pem -o StrictHostKeyChecking=no ubuntu@192.168.1.230 << 'EOF'
echo 'Importing the SQL dump into the STUDENTS database...'
mysql -h inventory-db.choq2jj89uyi.us-east-1.rds.amazonaws.com -u admin -p0yNjVaYA0DLU STUDENTS < /tmp/data.sql
echo 'Data successfully imported into the STUDENTS database.'
EOF

    if [[ $status -eq 0 ]]; then
        echo "Creating EC2-v2 image..."
        execute_command "SERVER_V2_IMAGE_ID=\$(aws ec2 create-image \
            --instance-id \"$NEW_INSTANCE_ID\" \
            --name \"$EC2_IMAGE2_NAME\" \
            --query 'ImageId' \
            --output text)" \
            "Failed to create EC2-v2 image."
        status=$?
    fi

    RDS_MODIFY=$(aws rds modify-db-instance \
        --db-instance-identifier "$RDS_INSTANCE" \
        --multi-az \
        --db-subnet-group "$DBSubnetGroup" \
        --apply-immediately \
        --backup-retention-period 1 \
        --output text)

    if [[ $status -eq 0 ]]; then
        echo "Image created with ID: $SERVER_V1_IMAGE_ID"
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "TERMINATED_INSTANCE=/$(aws ec2 terminate-instances \
            --instance-ids \"$INSTANCE_ID\" \
            --output text)" \
            "Failed to terminate EC2-v1 instance."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "NEW_INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances \
            --instance-ids "$NEW_INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)" \
            "Failed to retrieve new EC2 instance public IP."
    fi

    if [[ $status -eq 0 ]]; then
        echo -e "\n\n\n"
        echo "######################################"
        echo "# Phase 2 Complete: EC2-v2 Public IP - $NEW_INSTANCE_PUBLIC_IP"
        echo "# Please wait 5 minutes for the web application to be fully operational."
        echo "# You can access the application at http://$NEW_INSTANCE_PUBLIC_IP"
        echo "# The instance needs to be fully operational before proceeding to Phase 3."
        # echo "RDS Endpoint - $RDS_ENDPOINT"
        # echo "# EC2-v2 Image ID - $SERVER_V2_IMAGE_ID"
        echo "######################################"
    else
        echo -e "\n\n\n"
        echo "######################################"
        echo "# Phase 2 Failed: Please check the last error message above."
        echo "# Please check log files dumped in the Cloud9 directory for more information."
        echo "######################################"
    fi
}

######################################
# Phase 3: Load Balancer and Auto Scaling Setup
######################################

phase3() {
    echo -e "\n\n\n"
    echo "######################################"
    echo "# Starting Phase 3: Load Balancer and Auto Scaling Setup"
    echo "######################################"
    # Initialize status variable to track failures
    local status=0

    if [[ $status -eq 0 ]]; then
        echo "Creating EC2-v3 Launch Template..."
        execute_command "LAUNCH_TEMPLATE_ID=\$(aws ec2 create-launch-template \
            --launch-template-name "$LAUNCH_TEMPLATE_NAME" \
            --version-description "Initial version" \
            --launch-template-data '{"ImageId":"$SERVER_V2_IMAGE_ID","InstanceType":"t2.micro","KeyName":"$PRIV_KEY","SecurityGroupIds":["$LAB_SG"]}' \
            --query 'LaunchTemplate.LaunchTemplateId' \
            --output text)" \
            "Failed to create EC2-v3 Launch Template."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "LB_SG=\$(aws ec2 create-security-group \
            --group-name \"$LB_SG_NAME\" \
            --description \"Load Balancer Security Group\" \
            --vpc-id \"$VPC_ID\" \
            --query 'GroupId' \
            --output text)" \
            "Failed to create Load Balancer Security Group."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        AUTH_SECURITY_GROUP=$(aws ec2 authorize-security-group-ingress \
            --group-id "$LB_SG" \
            --protocol tcp \
            --port 80 \
            --cidr "$INTERNET_CIDR")
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        AUTH_SECURITY_GROUP=$(aws ec2 authorize-security-group-ingress \
            --group-id ="$LB_SG" \
            --protocol tcp \
            --port 80 \
            --source-group "$LAB_SG")
        status=$?
    fi
    # remove the rule that allows all traffic from the internet
    if [[ $status -eq 0 ]]; then
        AUTH_SECURITY_GROUP=$(aws ec2 revoke-security-group-ingress \
            --group-id "$LAB_SG" \
            --protocol tcp \
            --port 80 \
            --cidr "$INTERNET_CIDR")
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        echo "Creating Target Group..."
        execute_command "TG_ARN=\$(aws elbv2 create-target-group \
            --name "$TG_NAME" \
            --protocol HTTP \
            --port 80 \
            --vpc-id "$VPC_ID" \
            --tags Key=Name,Value="$TG_NAME" \
            --query 'TargetGroups[0].TargetGroupArn' \
            --output text)" \
            "Failed to create Target Group."
        status=$?
    fi
    if [[ $status -eq 0 ]]; then
        sleep 60
        echo "Creating Load Balancer, Listener, and attaching Target Group..."
        execute_command "LB_ARN=\$(aws elbv2 create-load-balancer \
            --name "$LB_NAME" \
            --subnets "$PUB_SUBNET1" "$PUB_SUBNET2" \
            --security-groups "$LB_SG" \
            --ip-address-type ipv4 \
            --query 'LoadBalancers[0].LoadBalancerArn' \
            --output text)" \
            "Failed to create Load Balancer."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "aws elbv2 wait load-balancer-available \
            --load-balancer-arns "$LB_ARN" \
            --cli-read-timeout 0 \
            --output text" \
            "Load Balancer did not become available in time."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        echo " Creating Auto Scaling Group..."
        execute_command "ASG_GROUP=\$(aws autoscaling create-auto-scaling-group \
            --auto-scaling-group-name "$EC2_ASG_NAME" \
            --launch-template "$LAUNCH_TEMPLATE_ID" \
            --min-size 2 \
            --max-size 6 \
            --desired-capacity 2 \
            --target-group-arns "$TG_ARN" \
            --vpc-zone-identifier "$PRIV_SUBNET1,$PRIV_SUBNET2" \
            --load-balancer-names "$LB_NAME" \
              --target-tracking-configuration file://config.json)" \
            "Failed to create Auto Scaling Group."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        execute_command "LB_DNS=\$(aws elbv2 describe-load-balancers \
            --names "$LB_NAME" \
            --query 'LoadBalancers[0].DNSName' \
            --output text)" \
            "Failed to retrieve Load Balancer DNS."
        status=$?
    fi

    if [[ $status -eq 0 ]]; then
        echo "Phase 3 Complete: Load Balancer and Auto Scaling setup finished."
        echo "Load Balancer DNS: $LB_DNS"
    else
        echo "Phase 3 encountered errors and did not complete successfully."
    fi
}

######################################
# Phase 4: Load Testing
######################################

phase4() {
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

phase5() {
    echo "Starting Phase 5: Cleanup"

    # Helper function
    check_command_success() {
        if [ $? -eq 0 ]; then
            echo "$1 succeeded."
        else
            echo "$1 failed or resource does not exist. Skipping..."
        fi
    }

    # Delete key pairs
    for key_name in "$PUB_KEY" "$PRIV_KEY"; do
        if [ -n "$key_name" ]; then
            aws ec2 delete-key-pair \
                --key-name "$key_name" || true
            # Reference the current file location
            rm -f "$SCRIPT_DIR/$key_name.pem" || true
            check_command_success "Deleting key pair $key_name"
        fi
    done

    # Scale down ASG before deletion
    if [ -n "$ASG_GROUP" ]; then
        aws autoscaling update-auto-scaling-group \
            --auto-scaling-group-name "$EC2_ASG_NAME" \
            --min-size 0 \
            --desired-capacity 0 || true
        check_command_success "Scaling down Auto Scaling Group"
    fi

    # Terminate EC2 instances
    for instance_id in "$INSTANCE_ID" "$NEW_INSTANCE_ID"; do
        if [ -n "$instance_id" ]; then
            aws ec2 terminate-instances \
                --instance-ids "$instance_id" \
                --output text || true
            check_command_success "Terminating EC2 instance $instance_id"
        fi
    done

    # Delete Launch Template
    echo "Deleting Launch Template..."
    if aws ec2 describe-launch-templates --launch-template-names "$LAUNCH_TEMPLATE_NAME" >/dev/null 2>&1; then
        aws ec2 delete-launch-template \
            --launch-template-name "$LAUNCH_TEMPLATE_NAME"
        check_command_success "Deleting Launch Template"
    fi

    # Deregister AMIs
    if [ -n "$SERVER_V1_IMAGE_ID" ]; then
        aws ec2 deregister-image \
            --image-id "$SERVER_V1_IMAGE_ID"
        check_command_success "Deregistering AMI $SERVER_V1_IMAGE_ID"
    fi
    if [ -n "$SERVER_V2_IMAGE_ID" ]; then
        aws ec2 deregister-image \
            --image-id "$SERVER_V2_IMAGE_ID"
        check_command_success "Deregistering AMI $SERVER_V2_IMAGE_ID"
    fi

    # Delete RDS instance
    if aws rds describe-db-instances --db-instance-identifier "$RDS_IDENTIFIER" >/dev/null 2>&1; then
        aws rds delete-db-instance \
            --db-instance-identifier "$RDS_IDENTIFIER" \
            --skip-final-snapshot > /dev/null 2>&1
        check_command_success "Deleting RDS instance"
    fi

    # Delete RDS Secret
    if [ -n "$SECRET_ARN" ]; then
        aws secretsmanager delete-secret \
            --secret-id "$SECRET_ARN" \
            --force-delete-without-recovery > /dev/null 2>&1
        check_command_success "Deleting RDS secret"
    fi

    # Delete Load Balancer and Target Group
    if [ -n "$LB_ARN" ]; then
        aws elbv2 delete-load-balancer \
            --load-balancer-arn "$LB_ARN"
        check_command_success "Deleting Load Balancer"
        sleep 30
    fi

    if [ -n "$TG_ARN" ]; then
        aws elbv2 delete-target-group \
            --target-group-arn "$TG_ARN"
        check_command_success "Deleting Target Group"
    fi

    # Delete Auto Scaling Group
    if [ -n "$EC2_ASG_NAME" ]; then
        aws autoscaling delete-auto-scaling-group \
            --auto-scaling-group-name "$EC2_ASG_NAME" \
            --force-delete
        check_command_success "Deleting Auto Scaling Group"
    fi

    # List of security group IDs
    for sg_id in "$LAB_SG" "$RDS_SG" "$LB_SG"; do
        if [[ -n "$sg_id" ]]; then
            echo "Processing Security Group: $sg_id"

            # Fetch all ingress rule IDs for the security group
            rule_ids=$(aws ec2 describe-security-group-rules \
                --filters Name="group-id",Values="$sg_id" \
                --query 'SecurityGroupRules[?(IsEgress=="false")].SecurityGroupRuleId' \
                --output text)

            if [[ -n "$rule_ids" ]]; then
                for rule in $rule_ids; do
                    # Revoke each rule and log the result
                    if aws ec2 revoke-security-group-ingress \
                        --group-id "$sg_id" \
                        --security-group-rule-ids "$rule" \
                        --output text; then
                        echo "Successfully revoked rule $rule from $sg_id"
                    else
                        echo "Failed to revoke rule $rule from $sg_id" >&2
                    fi
                done
            else
                echo "No ingress rules found for Security Group: $sg_id"
            fi
        else
            echo "Security Group ID is empty, skipping."
        fi
    done
    
    for sg_id in "$LAB_SG" "$RDS_SG" "$LB_SG"; do
        echo "Deleting Security Groups..."
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
    fi

    echo "Releasing Elastic IP..."
    if [ -n "$EIP_ALLOC" ]; then
        aws ec2 release-address \
            --allocation-id "$EIP_ALLOC" || true
        check_command_success "Releasing Elastic IP"
    fi

    echo "Detaching and deleting Internet Gateway..."
    if [ -n "$IGW_ID" ] && [ -n "$VPC_ID" ]; then
        sleep 10
        aws ec2 detach-internet-gateway \
            --internet-gateway-id "$IGW_ID" \
            --vpc-id "$VPC_ID" || true
        sleep 10
        aws ec2 delete-internet-gateway \
            --internet-gateway-id "$IGW_ID" || true
        check_command_success "Deleting Internet Gateway"
    fi
    # Delete VPC Peering Connection and Routes
    echo "Deleting Route Tables for VPC Peering Connection..."
    if [ -n "$DEFAULT_ROUTE_TABLE_ID" ]; then
        aws ec2 delete-route \
            --route-table-id "$DEFAULT_ROUTE_TABLE_ID" \
            --destination-cidr-block "$VPC_CIDR" || true
        check_command_success "Deleting Route Table $DEFAULT_ROUTE_TABLE_ID"
    fi

    echo "Deleting VPC Peering Connection..."
    if [ -n "$PEERING_CONNECTION_ID" ]; then
        aws ec2 delete-vpc-peering-connection \
            --vpc-peering-connection-id "$PEERING_CONNECTION_ID" || true
        check_command_success "Deleting VPC Peering Connection"
    fi

    # Delete Subnets
    echo "Deleting Subnets..."
    for subnet_id in "$PUB_SUBNET1" "$PUB_SUBNET2" "$PRIV_SUBNET1" "$PRIV_SUBNET2" "$DB_SUBNET1" "$DB_SUBNET2"; do
        if [ -n "$subnet_id" ]; then
            aws ec2 delete-subnet \
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

    if [ -n "$PRIV_ROUTE_TABLE" ]; then
        aws ec2 delete-route-table \
            --route-table-id "$PRIV_ROUTE_TABLE" || true
        check_command_success "Deleting Route Table $PRIV_ROUTE_TABLE"
    fi

    if [ -n "$DB_ROUTE_TABLE" ]; then
        aws ec2 delete-route-table \
            --route-table-id "$DB_ROUTE_TABLE" || true
        check_command_success "Deleting Route Table $DB_ROUTE_TABLE"
    fi

    # Wait one minute and Delete VPC
    echo "Deleting VPC..."
    if [ -n "$VPC_ID" ]; then
        sleep 10
        aws ec2 delete-vpc \
            --vpc-id "$VPC_ID" || true
        check_command_success "Deleting VPC"
    fi
    echo "Phase 5 Complete: All resources checked and deleted as necessary."
}

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