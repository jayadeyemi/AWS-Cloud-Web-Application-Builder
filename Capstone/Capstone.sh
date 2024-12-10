#!/bin/bash

# Variables (replace with actual values)
REGION="us-east-1"
RDS_IDENTIFIER="ProjectRDS"
DB_NAME="countries"
DB_USERNAME="admin"
DB_PASSWORD="securepassword123"
SECRET_NAME="ProjectDBSecret"
LAUNCH_TEMPLATE_NAME="Project-LT"
ASG_NAME="Project-ASG"
TARGET_GROUP_NAME="Project-TG"
LOAD_BALANCER_NAME="Project-ALB"
EC2_IAM_ROLE="Inventory-App-Role"
ALB_SECURITY_GROUP="ALBSG"
DB_SECURITY_GROUP="ExampleDB-SG"
APP_SECURITY_GROUP="Inventory-App"
PRIVATE_SUBNET_TAG="Private Subnet*"
PUBLIC_SUBNET_TAG="Public Subnet*"
RDS_SUBNET_GROUP="Example-DB-subnet-group"

# Function to check for required variables
check_variable() {
    if [ -z "${!1}" ]; then
        echo "Error: Variable $1 is not set. Please set it before running the script."
        exit 1
    fi
}

# Function to check if a required AWS resource exists
check_aws_resource() {
    local resource_type=$1
    local resource_name=$2
    local filter=$3
    local query=$4

    result=$(aws "$resource_type" "$filter" "$resource_name" --query "$query" --output text --region "$REGION" 2>/dev/null)
    if [[ $? -ne 0 || $result == "None" ]]; then
        echo "Error: $resource_type $resource_name not found."
        exit 1
    fi
    echo "$resource_type $resource_name is configured."
}

echo "Checking prerequisites for deployment..."

# Check if required variables are set
required_variables=("REGION" "RDS_IDENTIFIER" "DB_USERNAME" "DB_PASSWORD" "SECRET_NAME" 
                    "LAUNCH_TEMPLATE_NAME" "ASG_NAME" "TARGET_GROUP_NAME" "LOAD_BALANCER_NAME" 
                    "EC2_IAM_ROLE" "ALB_SECURITY_GROUP" "DB_SECURITY_GROUP" "APP_SECURITY_GROUP" 
                    "PRIVATE_SUBNET_TAG" "PUBLIC_SUBNET_TAG" "RDS_SUBNET_GROUP")
for var in "${required_variables[@]}"; do
    check_variable "$var"
done

# Check for AWS CLI
if ! command -v aws &>/dev/null; then
    echo "Error: AWS CLI is not installed or not in PATH."
    exit 1
fi

# Check for jq
if ! command -v jq &>/dev/null; then
    echo "Error: jq is not installed or not in PATH."
    exit 1
fi

# Check for MySQL client
if ! command -v mysql &>/dev/null; then
    echo "Error: MySQL client is not installed or not in PATH."
    exit 1
fi

# Check RDS Subnet Group
check_aws_resource "rds describe-db-subnet-groups" "--db-subnet-group-name" "$RDS_SUBNET_GROUP" "DBSubnetGroups[0].DBSubnetGroupName"

# Check IAM Role
check_aws_resource "iam get-role" "--role-name" "$EC2_IAM_ROLE" "Role.RoleName"

# Check ALB Security Group
check_aws_resource "ec2 describe-security-groups" "--filters Name=group-name,Values=$ALB_SECURITY_GROUP" "SecurityGroups[0].GroupId"

# Check Database Security Group
check_aws_resource "ec2 describe-security-groups" "--filters Name=group-name,Values=$DB_SECURITY_GROUP" "SecurityGroups[0].GroupId"

# Check Application Security Group
check_aws_resource "ec2 describe-security-groups" "--filters Name=group-name,Values=$APP_SECURITY_GROUP" "SecurityGroups[0].GroupId"

# Check Private Subnets
private_subnets=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PRIVATE_SUBNET_TAG" --query 'Subnets[*].[SubnetId, AvailabilityZone]' --output text --region "$REGION")
if [[ -z $private_subnets ]]; then
    echo "Error: No private subnets found with tag $PRIVATE_SUBNET_TAG."
    exit 1
fi
echo "Private subnets found:"
echo "$private_subnets"

# Check Public Subnets
public_subnets=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=$PUBLIC_SUBNET_TAG" --query 'Subnets[*].[SubnetId, AvailabilityZone]' --output text --region "$REGION")
if [[ -z $public_subnets ]]; then
    echo "Error: No public subnets found with tag $PUBLIC_SUBNET_TAG."
    exit 1
fi
echo "Public subnets found:"
echo "$public_subnets"

# Check for existing RDS instance
rds_instance=$(aws rds describe-db-instances --db-instance-identifier "$RDS_IDENTIFIER" --query "DBInstances[0].DBInstanceIdentifier" --output text --region "$REGION" 2>/dev/null)
if [[ $? -eq 0 && $rds_instance == "$RDS_IDENTIFIER" ]]; then
    echo "RDS instance $RDS_IDENTIFIER exists."
else
    echo "RDS instance $RDS_IDENTIFIER does not exist. It will be created during deployment."
fi

echo "All prerequisites checked successfully."

read -p "Enter your public IP address (x.x.x.x): " ADMIN_IP # Prompt for Admin's Public IP Address
ADMIN_IP="$ADMIN_IP/32" # Append /32 to specify a single IP address

echo "Starting resource execution..."

# Step 1: Configure Security Group Rules
echo "Updating security group rules..."

# Allow ALB to communicate with EC2 instances
aws ec2 authorize-security-group-ingress \
    --group-name Inventory-App \
    --protocol tcp \
    --port 80 \
    --source-group $(aws ec2 describe-security-groups --filters Name=group-name,Values=ALBSG --query 'SecurityGroups[0].GroupId' --output text) \
    --region $REGION
check_status "Failed to allow ALB to communicate with EC2."

# Allow EC2 to communicate with RDS
aws ec2 authorize-security-group-egress \
    --group-name Inventory-App \
    --protocol tcp \
    --port 3306 \
    --destination-group $(aws ec2 describe-security-groups --filters Name=group-name,Values=ExampleDB-SG --query 'SecurityGroups[0].GroupId' --output text) \
    --region $REGION
check_status "Failed to allow EC2 to communicate with RDS."

# Allow SSH access for Admin
aws ec2 authorize-security-group-ingress \
    --group-name Inventory-App \
    --protocol tcp \
    --port 22 \
    --cidr $ADMIN_IP \
    --region $REGION
check_status "Failed to allow SSH access for Admin."

# Step 2: Create RDS Database
echo "Creating RDS MySQL instance..."
aws rds create-db-instance \
    --db-instance-identifier $RDS_IDENTIFIER \
    --db-instance-class db.t2.micro \
    --engine mysql \
    --master-username $DB_USERNAME \
    --master-user-password $DB_PASSWORD \
    --allocated-storage 20 \
    --db-subnet-group-name Example-DB-subnet-group \
    --vpc-security-group-ids $(aws ec2 describe-security-groups --filters Name=group-name,Values=ExampleDB-SG --query 'SecurityGroups[0].GroupId' --output text) \
    --region $REGION
check_status "RDS creation failed."

echo "Waiting for RDS instance to be available..."
aws rds wait db-instance-available --db-instance-identifier $RDS_IDENTIFIER
check_status "RDS wait failed."

RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $RDS_IDENTIFIER --query "DBInstances[0].Endpoint.Address" --output text)
check_status "Failed to retrieve RDS endpoint."

echo "RDS Endpoint: $RDS_ENDPOINT"

# Step 3: Store Database Credentials in Secrets Manager
echo "Storing database credentials in Secrets Manager..."
aws secretsmanager create-secret \
    --name $SECRET_NAME \
    --description "Credentials for RDS instance" \
    --secret-string "{\"username\":\"$DB_USERNAME\",\"password\":\"$DB_PASSWORD\"}" \
    --region $REGION
check_status "Secrets Manager creation failed."

# Step 4: Create Application Load Balancer
echo "Creating Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name $LOAD_BALANCER_NAME \
    --subnets $(aws ec2 describe-subnets --filters Name=tag:Name,Values="Public Subnet*" --query 'Subnets[*].SubnetId' --output text) \
    --security-groups $(aws ec2 describe-security-groups --filters Name=group-name,Values=ALBSG --query 'SecurityGroups[0].GroupId' --output text) \
    --scheme internet-facing \
    --region $REGION \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)
check_status "Load Balancer creation failed."

echo "Creating Target Group..."
TG_ARN=$(aws elbv2 create-target-group \
    --name $TARGET_GROUP_NAME \
    --protocol HTTP \
    --port 80 \
    --vpc-id $(aws ec2 describe-vpcs --filters Name=tag:Name,Values="Project VPC" --query 'Vpcs[0].VpcId' --output text) \
    --target-type instance \
    --region $REGION \
    --query 'TargetGroups[0].TargetGroupArn' --output text)
check_status "Target Group creation failed."

echo "Creating Listener for ALB..."
aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN \
    --region $REGION
check_status "Listener creation failed."

# Step 5: Configure Auto Scaling Group
echo "Creating Auto Scaling Group..."
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name $ASG_NAME \
    --launch-template "LaunchTemplateName=$LAUNCH_TEMPLATE_NAME,Version=1" \
    --min-size 1 \
    --max-size 3 \
    --desired-capacity 1 \
    --vpc-zone-identifier $(aws ec2 describe-subnets --filters Name=tag:Name,Values="Private Subnet*" --query 'Subnets[*].SubnetId' --output text) \
    --target-group-arns $TG_ARN \
    --iam-instance-profile Inventory-App-Role \
    --region $REGION
check_status "Auto Scaling Group creation failed."

# Step 6: Import SQL Data
echo "Importing SQL data into RDS..."
SECRET=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query 'SecretString' --output text)
DB_USERNAME=$(echo $SECRET | jq -r '.username')
DB_PASSWORD=$(echo $SECRET | jq -r '.password')

mysql -h $RDS_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD < Countrydatadump.sql
check_status "SQL data import failed."

# Step 7: Output ALB DNS
echo "Fetching ALB DNS name..."
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query "LoadBalancers[0].DNSName" --output text)
check_status "Failed to retrieve ALB DNS name."

echo "Application deployed successfully. Access it at: http://$ALB_DNS"
