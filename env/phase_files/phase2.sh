#!/bin/bash

######################################
# Phase 2: Database Migration to RDS, EC2 Image Creation, and v2 Launch
######################################

echo -e "\n\n\n"
echo "############################################################################################################"
echo "# Starting Phase 2: Migration to RDS"
echo "# version #2 Application Launch for communication with RDS"
echo "# Server v1 image backup and termination"
echo "############################################################################################################"
echo -e "\n\n\n"
# echo "############################################################################################################"
# echo "# Database Access Preparation"
# echo "############################################################################################################"

# Create Database Subnet Group and attach DB Private Subnets
if [[ $status -eq 0 ]]; then
    execute_command "DB_SUBNET_GROUP_DETAILS=\$(aws rds create-db-subnet-group --db-subnet-group-name \"$DB_SUBNET_GROUP_NAME\" --db-subnet-group-description \"Inventory RDS Subnet Group\" --subnet-ids \"$DB_SUBNET1\" \"$DB_SUBNET2\" --output text)"
    status=$?
fi

# Create RDS Security Group
if [[ $status -eq 0 ]]; then
    execute_command "RDS_SG_ID=\$(aws ec2 create-security-group --group-name \"$RDS_SG_NAME\" --description \"RDS Security Group\" --vpc-id \"$MAIN_VPC_ID\" --query 'GroupId' --output text)"
    status=$?
fi

# Authorize RDS Security Group access to EC2-v1 Security Group
if [[ $status -eq 0 ]]; then
    execute_command "EC2_V1_SG_RDS_SG_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$EC2_V1_SG_ID\" --protocol tcp --port 3306 --source-group \"$RDS_SG_ID\" --query 'SecurityGroupRules[0].SecurityGroupRuleId' --output text)"
    status=$?
fi

# Authorize EC2-v1 Security Group access to RDS Security Group
if [[ $status -eq 0 ]]; then
    execute_command "RDS_SG_EC2_V1_SG_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$RDS_SG_ID\" --protocol tcp --port 3306 --source-group \"$EC2_V1_SG_ID\" --query 'SecurityGroupRules[0].SecurityGroupRuleId' --output text)"
    status=$?
fi

# echo "############################################################################################################"
# echo "# EC2-v2 Launch Preparation, RDS Instance Creation"
# echo "############################################################################################################"

# Create a new key pair for EC2-v2
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-key-pair --key-name \"$PRIV_KEY\" --key-type --key-format \"$KEY_FORMAT\" --query 'KeyMaterial' --output text > \"$PRIV_KEY\".\"$KEY_FORMAT\""
    status=$?
fi

# Set permissions for saving the private key
if [[ $status -eq 0 ]]; then
    execute_command "chmod 400 \"$PRIV_KEY.$KEY_FORMAT\""
    status=$?
fi

# Create an image of the new EC2-v1 instance for backup
if [[ $status -eq 0 ]]; then
    execute_command "SERVER_V1_IMAGE_ID=\$(aws ec2 create-image --instance-id \"$INSTANCE_ID\" --name \"$EC2_IMAGE1_NAME\" --query 'ImageId' --output text)"
    status=$?
fi

# Create a new EC2-v2 instance
if [[ $status -eq 0 ]]; then
    execute_command "NEW_INSTANCE_ID=\$(aws ec2 run-instances --image-id \"$AMI_ID\" --count 1 --instance-type t2.micro --key-name \"$PRIV_KEY\" --security-group-ids \"$EC2_V1_SG_ID\" --subnet-id \"$PUB_SUBNET1\" --user-data file://\"$USER_DATA_FILE_V2\" --iam-instance-profile Name=$INVENTORY_SERVER_ROLE --tag-specifications \"ResourceType=instance,Tags=[{Key=Name,Value=$EC2_V2_NAME}]\" --query 'Instances[0].InstanceId' --output text)"
    status=$?
fi

# Create a Single Availability Zone RDS Instance
if [[ $status -eq 0 ]]; then
    execute_command "RDS_INSTANCE=\$(aws rds create-db-instance --db-instance-identifier \"$RDS_IDENTIFIER\" --db-instance-class db.t3.micro --storage-type gp3 --allocated-storage 20 --no-multi-az --engine mysql --db-subnet-group-name \"$DB_SUBNET_GROUP_NAME\" --availability-zone $AVAILABILITY_ZONE1 --master-username $SECRET_USERNAME --master-user-password $SECRET_PASSWORD --vpc-security-group-ids \"$RDS_SG_ID\" --backup-retention-period 1 --no-enable-performance-insights --query 'DBInstance.DBInstanceIdentifier' --output text)"
    status=$?
fi

# Wait for the RDS instance to be available
if [[ $status -eq 0 ]]; then
    execute_command "aws rds wait db-instance-available --db-instance-identifier \"$RDS_INSTANCE\" --cli-read-timeout 0"
    status=$?
fi

# Get the RDS endpoint
if [[ $status -eq 0 ]]; then
    execute_command "RDS_ENDPOINT=\$(aws rds describe-db-instances --db-instance-identifier \"$RDS_INSTANCE\" --query 'DBInstances[0].Endpoint.Address' --output text)"
    status=$?
fi

# Create a new Secret for RDS
if [[ $status -eq 0 ]]; then
    execute_command "SECRET_ARN=\$(aws secretsmanager create-secret --name \"$SECRET_NAME\" --description \"Database secret for web app\" --secret-string '{\"username\":\"$SECRET_USERNAME\",\"password\":\"$SECRET_PASSWORD\",\"host\":\"$RDS_ENDPOINT\",\"db\":\"$SECRET_DBNAME\"}' --force-overwrite-replica-secret --query 'ARN' --output text)"
    status=$?
fi

# Get the new EC2-v2 instance Public IP
if [[ $status -eq 0 ]]; then
    execute_command "NEW_INSTANCE_PUBLIC_IP=\$(aws ec2 describe-instances --instance-ids \"$NEW_INSTANCE_ID\" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
    status=$?
fi

# Get the new EC2-v2 instance Private IP
if [[ $status -eq 0 ]]; then
    execute_command "NEW_INSTANCE_PRIVATE_IP=\$(aws ec2 describe-instances --instance-ids \"$NEW_INSTANCE_ID\" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)"
    status=$?
fi

# echo "############################################################################################################"
# echo "# Database Migration"
# echo "############################################################################################################"

# Step 1: Login to the EC2 instance v1 and export the database
if [[ $status -eq 0 ]]; then
echo '############################################################################################################'
ssh -t -i "$SCRIPT_DIR/$PUB_KEY".pem -o StrictHostKeyChecking=no ubuntu@"$INSTANCE_PRIVATE_IP" << EOF
echo '----------------------------------------------------------------------------------------------------------------'
mysqldump -u nodeapp -pstudent12 --databases STUDENTS > /tmp/data.sql # Export the database
echo '----------------------------------------------------------------------------------------------------------------'
EOF
echo '############################################################################################################'

# Step 2: Copy the dump from the EC2 instance v1 to the Cloud9 instance
scp -i "$SCRIPT_DIR/$PUB_KEY".pem -o StrictHostKeyChecking=no ubuntu@"$INSTANCE_PRIVATE_IP":/tmp/data.sql "$SCRIPT_DIR"/data.sql # Copy the dump to the Cloud9 instance 

# Step 3: Login to the EC2 instance v2 and create the database 
echo '############################################################################################################'
ssh -t -i "$SCRIPT_DIR/$PRIV_KEY".pem -o StrictHostKeyChecking=no ubuntu@"$NEW_INSTANCE_PRIVATE_IP" << EOF # Login to instance 2
echo '----------------------------------------------------------------------------------------------------------------'
mysql -h $RDS_ENDPOINT -u $SECRET_USERNAME -p$SECRET_PASSWORD -e 'CREATE DATABASE STUDENTS' # Create the database
echo '----------------------------------------------------------------------------------------------------------------'
EOF
echo '############################################################################################################'

# Step 4: Copy the selected database dump to the EC2 instance v2 (default: sample_entries.sql)
scp -i "$SCRIPT_DIR/$PRIV_KEY".pem -o StrictHostKeyChecking=no "$SCRIPT_DIR/$DEFAULT_DB_FILE" ubuntu@"$NEW_INSTANCE_PRIVATE_IP":/tmp/data.sql # Copy the dump to the Cloud9 instance

# Step 5: Login to the ec2 instance v2 and export the database to RDS
echo '############################################################################################################'
ssh -t -i "$SCRIPT_DIR/$PRIV_KEY".pem -o StrictHostKeyChecking=no ubuntu@"$NEW_INSTANCE_PRIVATE_IP" << EOF # Login to instance 2
echo '----------------------------------------------------------------------------------------------------------------'
mysql -h "$RDS_ENDPOINT" -u "$SECRET_USERNAME" -p"$SECRET_PASSWORD" STUDENTS < /tmp/data.sql
echo '----------------------------------------------------------------------------------------------------------------'
EOF
echo '############################################################################################################'
fi

echo -e "\n\n\n"
# echo "############################################################################################################"
# echo "# RDS Multi-AZ Reconfiguration, EC2-v2 backup and EC2-v1 termination"
# echo "############################################################################################################"
# RDS Multi-AZ Reconfiguration, EC2-v2 backup and EC2-v1 termination
if [[ $status -eq 0 ]]; then
    execute_command "RDS_MODIFY=\$(aws rds modify-db-instance --db-instance-identifier \"$RDS_INSTANCE\" --multi-az --apply-immediately --backup-retention-period 1 --output text)"
    status=$?
fi

if [[ $status -eq 0 ]]; then
    execute_command "SERVER_V2_IMAGE_ID=\$(aws ec2 create-image --instance-id \"$NEW_INSTANCE_ID\" --name \"$EC2_IMAGE2_NAME\" --query 'ImageId' --output text)"
    status=$?
fi


if [[ $status -eq 0 ]]; then
    echo -e "\n\n\n"
    echo "############################################################################################################"
    echo "# Phase 2 Complete: EC2-v2 Public IP - $NEW_INSTANCE_PUBLIC_IP"
    echo "# Please wait 5 minutes for the web application to be fully operational."
    echo "# You can access the application at http://$NEW_INSTANCE_PUBLIC_IP"
    echo "# The instance needs to be fully operational before proceeding to Phase 3."
    echo "RDS Endpoint - $RDS_ENDPOINT"
    echo "# EC2-v2 Image ID - $SERVER_V2_IMAGE_ID"
    echo "############################################################################################################"
else
    echo -e "\n\n\n"
    echo "############################################################################################################"
    echo "# Phase 2 Failed: Please check the last error message above."
    echo "# Please check log files dumped in the Cloud9 directory for more information."
    echo "############################################################################################################"
fi