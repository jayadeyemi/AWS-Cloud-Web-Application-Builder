#!/bin/bash

echo "############################################################################################################"
echo "# Starting Phase 1: VPC, Subnets, and EC2-v1 with In-Memory Database"
echo "############################################################################################################"
echo -e "\n\n\n"

# Retrieve the Default VPC ID
if [[ $status -eq 0 ]]; then
    execute_command "DEFAULT_VPC_ID=\$(aws ec2 describe-vpcs --filters 'Name=isDefault,Values=true' --query 'Vpcs[0].VpcId' --output text)"
    status=$?
fi

# Retrieve the Default VPC CIDR
if [[ $status -eq 0 ]]; then
    execute_command "DEFAULT_VPC_CIDR=\$(aws ec2 describe-vpcs --filters \"Name=isDefault,Values=true\" --query 'Vpcs[0].CidrBlock' --output text)"
    status=$?
fi

# Retrieve the DEFAULT VPC Route Table ID
if [[ $status -eq 0 ]]; then
    execute_command "DEFAULT_ROUTE_TABLE_ID=\$(aws ec2 describe-route-tables --filters 'Name=vpc-id,Values=$DEFAULT_VPC_ID' --query 'RouteTables[?Associations[0].Main].RouteTableId' --output text)"
    status=$?
fi



# Create a security group for the Cloud9 instance if not found
if [[ $status -eq 0 ]]; then
    execute_command "CLOUD9_SG_ID=\$(aws ec2 describe-instances --instance-ids \"$CLOUD9_INSTANCE_ID\" --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)"
    status=$?
fi
    if [[ -z "$CLOUD9_SG_ID" || "$CLOUD9_SG_ID" == "None" ]]; then
        # Assign attempt variables
        MAX_ATTEMPTS=5
        attempt=0

        while [[ (-z "$CLOUD9_SG_ID" || "$CLOUD9_SG_ID" == "None") && $attempt -lt $MAX_ATTEMPTS ]]; do
            ((attempt++))
            echo "Attempt $attempt of $MAX_ATTEMPTS"
            read -p "Enter the correct Cloud9 instance ID: " CLOUD9_INSTANCE_ID
            execute_command "CLOUD9_SG_ID=\$(aws ec2 describe-instances --instance-ids \"$CLOUD9_INSTANCE_ID\" --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)"
            status=$?
            if [[ $status -ne 0 ]]; then
                echo "Failed to retrieve security group ID for instance ID: $CLOUD9_INSTANCE_ID. Please try again."
            fi
        done
    fi
else
    echo "Error retrieving security group ID for instance ID: $CLOUD9_INSTANCE_ID. Exiting."
    exit 1
fi

# Create a VPC
if [[ $status -eq 0 ]]; then
    execute_command "MAIN_VPC_ID=\$(aws ec2 create-vpc --cidr-block \"$VPC_CIDR\" --query 'Vpc.VpcId' --output text)"
    status=$?
fi

# Name the VPC
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$MAIN_VPC_ID\" --tags Key=Name,Value=\"$VPC_NAME\""
    status=$?
fi

# Wait for the VPC to be available
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 wait vpc-available --vpc-ids \"$MAIN_VPC_ID\""
    status=$?
fi

# Create the Public Subnet1
if [[ $status -eq 0 ]]; then
    execute_command "PUB_SUBNET1=\$(aws ec2 create-subnet --vpc-id \"$MAIN_VPC_ID\" --cidr-block \"$PUB_SUBNET1_CIDR\" --availability-zone $AVAILABILITY_ZONE1 --query 'Subnet.SubnetId' --output text)"
    status=$?
fi

# Name the Public Subnet1
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$PUB_SUBNET1\" --tags Key=Name,Value=\"$PUB_SUBNET1_NAME\""
    status=$?
fi

# Create the Public Subnet2
if [[ $status -eq 0 ]]; then
    execute_command "PUB_SUBNET2=\$(aws ec2 create-subnet --vpc-id \"$MAIN_VPC_ID\" --cidr-block \"$PUB_SUBNET2_CIDR\" --availability-zone $AVAILABILITY_ZONE2 --query 'Subnet.SubnetId' --output text)"
    status=$?
fi

# Name the Public Subnet2
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$PUB_SUBNET2\" --tags Key=Name,Value=\"$PUB_SUBNET2_NAME\""
    status=$?
fi

# Create the Private Subnet1
if [[ $status -eq 0 ]]; then
    execute_command "PRIV_SUBNET1=\$(aws ec2 create-subnet --vpc-id \"$MAIN_VPC_ID\" --cidr-block \"$PRIV_SUBNET1_CIDR\" --availability-zone $AVAILABILITY_ZONE1 --query 'Subnet.SubnetId' --output text)"
    status=$?
fi

# Name the Private Subnet1
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$PRIV_SUBNET1\" --tags Key=Name,Value=\"$PRIV_SUBNET1_NAME\""
    status=$?
fi

# Create the Private Subnet2
if [[ $status -eq 0 ]]; then
    execute_command "PRIV_SUBNET2=\$(aws ec2 create-subnet --vpc-id \"$MAIN_VPC_ID\" --cidr-block \"$PRIV_SUBNET2_CIDR\" --availability-zone $AVAILABILITY_ZONE2 --query 'Subnet.SubnetId' --output text)"
    status=$?
fi

# Name the Private Subnet2
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$PRIV_SUBNET2\" --tags Key=Name,Value=\"$PRIV_SUBNET2_NAME\""
    status=$?
fi

# Create the Database Subnet1
if [[ $status -eq 0 ]]; then
    execute_command "DB_SUBNET1=\$(aws ec2 create-subnet --vpc-id \"$MAIN_VPC_ID\" --cidr-block \"$DB_SUBNET1_CIDR\" --availability-zone $AVAILABILITY_ZONE1 --query 'Subnet.SubnetId' --output text)"
    status=$?
fi

# Name the Database Subnet1
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$DB_SUBNET1\" --tags Key=Name,Value=\"$DB_SUBNET1_NAME\""
    status=$?
fi

# Create the Database Subnet2
if [[ $status -eq 0 ]]; then
    execute_command "DB_SUBNET2=\$(aws ec2 create-subnet --vpc-id \"$MAIN_VPC_ID\" --cidr-block \"$DB_SUBNET2_CIDR\" --availability-zone $AVAILABILITY_ZONE2 --query 'Subnet.SubnetId' --output text)"
    status=$?
fi

# Name the Database Subnet2
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$DB_SUBNET2\" --tags Key=Name,Value=\"$DB_SUBNET2_NAME\""
    status=$?
fi

# Wait for all subnets to be available
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 wait subnet-available --subnet-ids \"$PUB_SUBNET1\" \"$PUB_SUBNET2\" \"$PRIV_SUBNET1\" \"$PRIV_SUBNET2\" \"$DB_SUBNET1\" \"$DB_SUBNET2\""
    status=$?
fi

# Modify the Public Subnet1 to enable auto-assign public IP on launch
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 modify-subnet-attribute --subnet-id \"$PUB_SUBNET1\" --map-public-ip-on-launch"
    status=$?
fi

# Modify the Public Subnet2 to enable auto-assign public IP on launch
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 modify-subnet-attribute --subnet-id \"$PUB_SUBNET2\" --map-public-ip-on-launch"
    status=$?
fi

# Retrieve the Main Route Table ID
if [[ $status -eq 0 ]]; then
    execute_command "MAIN_ROUTE_TABLE_ID=\$(aws ec2 describe-route-tables --filters \"Name=vpc-id,Values=$MAIN_VPC_ID\" \"Name=association.main,Values=true\" --query \"RouteTables[0].RouteTableId\" --output text)"
    status=$?
fi

# Rename the main route table to public route table
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$MAIN_ROUTE_TABLE_ID\" --tags \"Key=Name,Value=$PUB_ROUTE_TABLE_NAME\""
    status=$?
    # Change the variable name to reflect the new name
    PUB_ROUTE_TABLE_ID=$MAIN_ROUTE_TABLE_ID
fi

# Create a route table for the private subnets
if [[ $status -eq 0 ]]; then
    execute_command "PRIV_ROUTE_TABLE_ID=\$(aws ec2 create-route-table --vpc-id \"$MAIN_VPC_ID\" --query 'RouteTable.RouteTableId' --output text)"
    status=$?
fi

# Name the private route table
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$PRIV_ROUTE_TABLE_ID\" --tags Key=Name,Value=\"$PRIV_ROUTE_TABLE_NAME\""
    status=$?
fi

# Create a route table for the database subnets
if [[ $status -eq 0 ]]; then
    execute_command "DB_ROUTE_TABLE_ID=\$(aws ec2 create-route-table --vpc-id \"$MAIN_VPC_ID\" --query 'RouteTable.RouteTableId' --output text)"
    status=$?
fi

# Name the database route table
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$DB_ROUTE_TABLE_ID\" --tags Key=Name,Value=\"$DB_ROUTE_TABLE_NAME\""
    status=$?
fi

# Associate main route table with public subnet 1
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 associate-route-table --route-table-id \"$PUB_ROUTE_TABLE_ID\" --subnet-id \"$PUB_SUBNET1\" --output text"
    status=$?
fi

# Associate main route table with public subnet 2
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 associate-route-table --route-table-id \"$PUB_ROUTE_TABLE_ID\" --subnet-id \"$PUB_SUBNET2\" --output text"
    status=$?
fi

# Associate private route table with private subnet 1
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 associate-route-table --route-table-id \"$PRIV_ROUTE_TABLE_ID\" --subnet-id \"$PRIV_SUBNET1\" --output text"
    status=$?
fi

# Associate private route table with private subnet 2
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 associate-route-table --route-table-id \"$PRIV_ROUTE_TABLE_ID\" --subnet-id \"$PRIV_SUBNET2\" --output text"
    status=$?
fi

# Associate database route table with database subnet 1
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 associate-route-table --route-table-id \"$DB_ROUTE_TABLE_ID\" --subnet-id \"$DB_SUBNET1\" --output text"
    status=$?
fi

# Associate database route table with database subnet 2
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 associate-route-table --route-table-id \"$DB_ROUTE_TABLE_ID\" --subnet-id \"$DB_SUBNET2\" --output text"
    status=$?
fi

# Create an Internet Gateway
if [[ $status -eq 0 ]]; then
    execute_command "IGW_ID=\$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)"
    status=$?
fi

# Name the Internet Gateway
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$IGW_ID\" --tags Key=Name,Value=\"$IGW_TAG\""
    status=$?
fi

# Attach the Internet Gateway to the VPC
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 attach-internet-gateway --vpc-id \"$MAIN_VPC_ID\" --internet-gateway-id \"$IGW_ID\""
    status=$?
fi

# Allocate an Elastic IP
if [[ $status -eq 0 ]]; then
    execute_command "EIP_ALLOC=\$(aws ec2 allocate-address --query 'AllocationId' --output text)"
    status=$?
fi

# Name the Elastic IP
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$EIP_ALLOC\" --tags \"Key=Name,Value=$EIP_TAG\""
    status=$?
fi

# Create a NAT Gateway in the public subnet 1
if [[ $status -eq 0 ]]; then
    execute_command "NAT_GW_ID=\$(aws ec2 create-nat-gateway --subnet-id \"$PUB_SUBNET1\" --allocation-id \"$EIP_ALLOC\" --query 'NatGateway.NatGatewayId' --output text)"
    status=$?
fi

# Name the NAT Gateway
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$NAT_GW_ID\" --tags Key=Name,Value=\"$NAT_GW_TAG\""
    status=$?
fi

# Request a VPC peering connection
if [[ $status -eq 0 ]]; then
    execute_command "PEERING_CONNECTION_ID=\$(aws ec2 create-vpc-peering-connection --vpc-id \"$DEFAULT_VPC_ID\" --peer-vpc-id \"$MAIN_VPC_ID\" --query 'VpcPeeringConnection.VpcPeeringConnectionId' --output text)"
    status=$?
fi

# Accept the VPC peering connection request
if [[ $status -eq 0 ]]; then
    execute_command "VCP_DETAILS=\$(aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id \"$PEERING_CONNECTION_ID\" --output text)"
    status=$?
fi

# Create a route in the public route table to the Default VPC
if [[ $status -eq 0 ]]; then
    execute_command "ROUTE1=\$(aws ec2 create-route --route-table-id \"$PUB_ROUTE_TABLE_ID\" --destination-cidr-block \"$DEFAULT_VPC_CIDR\" --vpc-peering-connection-id \"$PEERING_CONNECTION_ID\" --output text)"
    status=$?
fi

# Create a route in the Default VPC route table to the Lab VPC
if [[ $status -eq 0 ]]; then
    execute_command "ROUTE2=\$(aws ec2 create-route --route-table-id \"$DEFAULT_ROUTE_TABLE_ID\" --destination-cidr-block \"$VPC_CIDR\" --vpc-peering-connection-id \"$PEERING_CONNECTION_ID\" --output text)"
    status=$?
fi

# Create a route in the main route table to the Internet Gateway
if [[ $status -eq 0 ]]; then
    execute_command "ROUTE3=\$(aws ec2 create-route --route-table-id \"$PUB_ROUTE_TABLE_ID\" --destination-cidr-block \"$INTERNET_CIDR\" --gateway-id \"$IGW_ID\" --output text)"
    status=$?
fi

# Wait for the NAT Gateway to be available before creating a route
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 wait nat-gateway-available --nat-gateway-ids \"$NAT_GW_ID\""
    status=$?
fi

# Create a route in the private route table to the NAT Gateway
if [[ $status -eq 0 ]]; then
    execute_command "ROUTE4=\$(aws ec2 create-route --route-table-id \"$PRIV_ROUTE_TABLE_ID\" --destination-cidr-block \"$INTERNET_CIDR\" --nat-gateway-id \"$NAT_GW_ID\" --output text)"
    status=$?
fi

# Create a security group for EC2-V1 instance in the main VPC
if [[ $status -eq 0 ]]; then
    execute_command "EC2_V1_SG_ID=\$(aws ec2 create-security-group --group-name \"$EC2_V1_SG_NAME\" --description \"Inventory Server Security Group\" --vpc-id \"$MAIN_VPC_ID\" --query 'GroupId' --output text)"
    status=$?
fi

# Authorize SSH access to the EC2-V1 security group from the user's Public IP for Remote Access
if [[ $status -eq 0 ]]; then
    execute_command "EC2_V1_SG_USER_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$EC2_V1_SG_ID\" --protocol tcp --port 22 --cidr \"$USER_CIDR\" --query 'SecurityGroupRules[0].SecurityGroupRuleId' --output text)"
    status=$?
fi

# Authorize SSH access to the EC2-V1 security group from the Cloud9 security group
if [[ $status -eq 0 ]]; then
    execute_command "EC2_V1_SG_CLOUD9_SG_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$EC2_V1_SG_ID\" --protocol tcp --port 22 --source-group \"$CLOUD9_SG_ID\" --query 'SecurityGroupRules[0].SecurityGroupRuleId' --output text)"
    status=$?
fi

# Authorize SSH access to the Cloud9 security group from the EC2-V1 security group
if [[ $status -eq 0 ]]; then
    execute_command "CLOUD9_SG_EC2_V1_SG_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$CLOUD9_SG_ID\" --protocol tcp --port 22 --source-group \"$EC2_V1_SG_ID\" --query 'SecurityGroupRules[0].SecurityGroupRuleId' --output text)"
    status=$?
fi

# Authorize HTTP access to the EC2-V1 security group from the Internet
if [[ $status -eq 0 ]]; then
    execute_command "EC2_V1_SG_INTERNET_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$EC2_V1_SG_ID\" --protocol tcp --port 80 --cidr \"$INTERNET_CIDR\" --query 'SecurityGroupRules[0].SecurityGroupRuleId' --output text)"
    status=$?
fi

# Create a key pair for the EC2 instance
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-key-pair --key-name \"$PUB_KEY\" --key-type rsa --key-format \"$KEY_FORMAT\" --query 'KeyMaterial' --output text > \"$PUB_KEY.$KEY_FORMAT\""
    status=$?
fi

# Set the correct permissions for saving the key pair
if [[ $status -eq 0 ]]; then
    execute_command "chmod 400 \"$PUB_KEY.$KEY_FORMAT\""
    status=$?
fi

# Launch the EC2 instance
if [[ $status -eq 0 ]]; then
    echo "Launching EC2-v1 instance..."
    execute_command "INSTANCE_ID=\$(aws ec2 run-instances --image-id \"$AMI_ID\" --count 1 --instance-type t2.micro --key-name \"$PUB_KEY\" --security-group-ids \"$EC2_V1_SG_ID\" --subnet-id \"$PUB_SUBNET1\" --user-data file://data/\"$USER_DATA_FILE_V1\" --tag-specifications \"ResourceType=instance,Tags=[{Key=Name,Value=\"$EC2_V1_NAME\"}]\" --query 'Instances[0].InstanceId' --output text)"
    status=$?
fi

# Wait for the instance to be running
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 wait instance-running --instance-ids \"$INSTANCE_ID\""
    status=$?
fi

# Wait for the instance to be in a okay status
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 wait instance-status-ok --instance-ids \"$INSTANCE_ID\" --cli-read-timeout 0"
    status=$?
fi

# Obtain the public IP address of the EC2 instance
if [[ $status -eq 0 ]]; then
    execute_command "INSTANCE_PUBLIC_IP=\$(aws ec2 describe-instances --instance-ids \"$INSTANCE_ID\" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
    status=$?
fi

# Obtain the private IP address of the EC2 instance
if [[ $status -eq 0 ]]; then
    execute_command "INSTANCE_PRIVATE_IP=\$(aws ec2 describe-instances --instance-ids \"$INSTANCE_ID\" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)"
    status=$?
fi

if [[ $status -eq 0 ]]; then
    echo -e "\n\n\n"
    echo "############################################################################################################"
    echo "# Phase 1 Completed Successfully."
    echo "# You can access the application at http://$INSTANCE_PUBLIC_IP"
    echo "# Please wait for the instance to be ready."
    echo "# Insert data into the application DB on the web page"
    echo "############################################################################################################"
else
    echo -e "\n\n\n"
    echo "############################################################################################################"
    echo "# Phase 1 Failed: Please check the last error message above."
    echo "# Please check log files dumped in the Cloud9 directory for more information."
    echo "############################################################################################################"
fi
