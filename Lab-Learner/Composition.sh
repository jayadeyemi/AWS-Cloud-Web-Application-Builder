#!/bin/bash -xe

# Get user's IP for SSH access
read -p "Enter your current IP address (e.g., 203.0.113.25): " USER_IP

# Generate a Key Pair for EC2 instances
KEY_NAME="LabKeyPair"
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > $KEY_NAME.pem
chmod 400 $KEY_NAME.pem

# Generate a Key Pair for Auto Scaling Group instances
ASG_KEY_NAME="LabASGKeyPair"
aws ec2 create-key-pair --key-name $ASG_KEY_NAME --query 'KeyMaterial' --output text > $ASG_KEY_NAME.pem
chmod 400 $ASG_KEY_NAME.pem

# Phase 1: VPC, Subnets, and EC2 with MySQL
function phase1() {
    echo "Starting Phase 1: Creating VPC and associated resources"

    # Create VPC
    VPC_ID=$(aws ec2 create-vpc --cidr-block 192.168.0.0/16 --query 'Vpc.VpcId' --output text)
    aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=Lab-VPC
    aws ec2 wait vpc-available --vpc-ids $VPC_ID

    # Create Subnets with tagging
    PUB_SUBNET1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 192.168.1.0/24 --availability-zone us-east-1a --query 'Subnet.SubnetId' --output text)
    aws ec2 create-tags --resources $PUB_SUBNET1 --tags Key=Name,Value=Lab-PublicSubnet1
    PUB_SUBNET2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 192.168.2.0/24 --availability-zone us-east-1b --query 'Subnet.SubnetId' --output text)
    aws ec2 create-tags --resources $PUB_SUBNET2 --tags Key=Name,Value=Lab-PublicSubnet2
    PRIV_SUBNET1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 192.168.3.0/24 --availability-zone us-east-1a --query 'Subnet.SubnetId' --output text)
    aws ec2 create-tags --resources $PRIV_SUBNET1 --tags Key=Name,Value=Lab-PrivateSubnet1
    PRIV_SUBNET2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 192.168.4.0/24 --availability-zone us-east-1b --query 'Subnet.SubnetId' --output text)
    aws ec2 create-tags --resources $PRIV_SUBNET2 --tags Key=Name,Value=Lab-PrivateSubnet2
    DB_SUBNET1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 192.168.5.0/24 --availability-zone us-east-1a --query 'Subnet.SubnetId' --output text)
    aws ec2 create-tags --resources $DB_SUBNET1 --tags Key=Name,Value=Lab-DBSubnet1
    DB_SUBNET2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 192.168.6.0/24 --availability-zone us-east-1b --query 'Subnet.SubnetId' --output text)
    aws ec2 create-tags --resources $DB_SUBNET2 --tags Key=Name,Value=Lab-DBSubnet2

    # Create and attach IGW
    IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
    aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=Lab-IGW
    aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

    # Create NAT Gateway and route table configuration
    EIP_ALLOC=$(aws ec2 allocate-address --query 'AllocationId' --output text)
    NAT_GW_ID=$(aws ec2 create-nat-gateway --subnet-id $PUB_SUBNET1 --allocation-id $EIP_ALLOC --query 'NatGateway.NatGatewayId' --output text)
    aws ec2 create-tags --resources $NAT_GW_ID --tags Key=Name,Value=Lab-NAT
    aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID

    # Create Route Table and associate with private subnets
    PRIV_ROUTE_TABLE=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
    aws ec2 create-route --route-table-id $PRIV_ROUTE_TABLE --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_ID
    aws ec2 associate-route-table --route-table-id $PRIV_ROUTE_TABLE --subnet-id $PRIV_SUBNET1
    aws ec2 associate-route-table --route-table-id $PRIV_ROUTE_TABLE --subnet-id $PRIV_SUBNET2

    # Create Security Group
    LAB_SG=$(aws ec2 create-security-group --group-name Lab-Server-SG --description "Lab Server Security Group" --vpc-id $VPC_ID --query 'GroupId' --output text)
    aws ec2 authorize-security-group-ingress --group-id $LAB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --group-id $LAB_SG --protocol tcp --port 22 --cidr $USER_IP/32

    # Enable Session Manager for EC2 instances
    INSTANCE_PROFILE_NAME="LabInstanceProfile"
    ROLE_NAME="AmazonSSMRoleForInstancesQuickSetup"
    if ! aws iam get-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME >/dev/null 2>&1; then
        echo "Instance profile $INSTANCE_PROFILE_NAME does not exist, creating..."
        aws iam create-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME
        aws iam add-role-to-instance-profile --instance-profile-name LabInstanceProfile --role-name AmazonSSMRoleForInstancesQuickSetup || true
    else
        echo "Instance profile $INSTANCE_PROFILE_NAME already exists."
    fi
    
    echo "Creating EC2-v1"

    # Create EC2 Instance with user data
    USER_DATA_FILE="phase1_userdata.sh"
    INSTANCE_ID=$(aws ec2 run-instances --image-id ami-0d5d9d301c853a04a --count 1 --instance-type t2.micro --key-name $KEY_NAME \
        --security-group-ids $LAB_SG --subnet-id $PUB_SUBNET1 --user-data file://$USER_DATA_FILE \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Lab-Server-v1}]' --query 'Instances[0].InstanceId' --output text)
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID
    INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    echo "Lab-Server-v1 Public IP: $INSTANCE_PUBLIC_IP"
}

# Phase 2: RDS Setup and Data Migration
function phase2() {
    echo "Starting Phase 2: Setting up RDS and migrating data"

    # Create Lab-DB-SG and modify Lab-Server-SG
    RDS_SG=$(aws ec2 create-security-group --group-name Lab-DB-SG --description "RDS Security Group" --vpc-id $VPC_ID --query 'GroupId' --output text)
    aws ec2 authorize-security-group-ingress --group-id $RDS_SG --protocol tcp --port 3306 --source-group $LAB_SG

    # Modify Lab-Server-SG to allow RDS access and remove HTTP access
    aws ec2 authorize-security-group-ingress --group-id $LAB_SG --protocol tcp --port 3306 --source-group $RDS_SG

    # Create a secret in Secrets Manager
    SECRET_NAME="LabRDSSecret"
    SECRET_ARN=$(aws secretsmanager create-secret --name $SECRET_NAME --description "RDS credentials for LabRDS" \
        --secret-string '{"username":"admin","password":"student12"}' --query 'ARN' --output text)

    # Create RDS Database (use the previously created DB subnet group)
    echo "Creating RDS MySQL instance..."
    RDS_INSTANCE=$(aws rds create-db-instance --db-instance-identifier LabRDS --allocated-storage 20 \
    --db-instance-class db.t2.micro --engine mysql --master-username admin --master-user-password student12 \
    --vpc-security-group-ids $RDS_SG --db-subnet-group-name LabDBSubnetGroup \
    --availability-zone us-east-1b --backup-retention-period 1 --no-enable-performance-insights \
    --tags Key=Name,Value=LabRDS --query 'DBInstance.DBInstanceIdentifier' --output text)
    aws rds wait db-instance-available --db-instance-identifier $RDS_INSTANCE
    RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $RDS_INSTANCE --query 'DBInstances[0].Endpoint.Address' --output text)
    
    echo "Migrating data to RDS..."
    mysqldump -h $INSTANCE_PUBLIC_IP -u nodeapp -p --databases STUDENTS > data.sql
    mysql -h $RDS_ENDPOINT -u admin -pstudent12 STUDENTS < data.sql

    echo "Terminating original EC2-v1"
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
    echo "Original EC2-v1 terminated."

    # Create a new EC2-v2 instance with the updated image (placeholder, assume we have a suitable AMI)
    echo "Creating EC2-v2"
    NEW_INSTANCE_ID=$(aws ec2 run-instances --image-id ami-08eec49a05b603ba3 --count 1 --instance-type t2.micro --key-name $KEY_NAME \
    --security-group-ids $LAB_SG --subnet-id $PUB_SUBNET1 \
    --iam-instance-profile Name=LabInstanceProfile \
    --user-data file://phase2_userdata.sh --query 'Instances[0].InstanceId' --output text)
    aws ec2 wait instance-running --instance-ids $NEW_INSTANCE_ID
    NEW_INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $NEW_INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    echo "New EC2 instance (EC2-v2) launched with Public IP: $NEW_INSTANCE_PUBLIC_IP"

    echo "Creating an EC2-v2 image..."
    SERVER_V2_IMAGE_ID=$(aws ec2 create-image --instance-id $NEW_INSTANCE_ID --name LabServerV2Image --query 'ImageId' --output text)
    aws ec2 wait image-available --image-ids $SERVER_V2_IMAGE_ID
    echo "Image created with ID: $SERVER_V2_IMAGE_ID"

    echo "Phase 2 Complete: RDS Endpoint - $RDS_ENDPOINT"
}

# Phase 3: Load Balancer and Auto Scaling
function phase3() {
    echo "Starting Phase 3: Setting up Load Balancer and Auto Scaling"
    echo "Creating a Launch Template for Ec2-v3 instance..."
    aws ec2 create-launch-template --launch-template-name LabServerV3Template \
    --launch-template-data "{
        \"ImageId\": \"$SERVER_V2_IMAGE_ID\",
        \"InstanceType\": \"t2.micro\",
        \"KeyName\": \"$ASG_KEY_NAME\",
        \"IamInstanceProfile\": {\"Name\": \"$INSTANCE_PROFILE_NAME\"},
        \"TagSpecifications\": [
            {
                \"ResourceType\": \"instance\",
                \"Tags\": [
                    {\"Key\": \"Name\", \"Value\": \"Lab-Server-v3\"}
                ]
            }
        ]
    }"
    aws ec2 wait launch-template-available --launch-template-name LabServerV3Template

    echo "Launching new EC2-v3 from template..."
    NEW_INSTANCE_ID=$(aws ec2 run-instances --image-id $SERVER_V2_IMAGE_ID --count 1 --instance-type t2.micro --key-name $KEY_NAME \
    --security-group-ids $LAB_SG --subnet-id $PUB_SUBNET1 \
    --iam-instance-profile Name=LabInstanceProfile \
    --user-data file://phase2_userdata.sh --query 'Instances[0].InstanceId' --output text)

    echo "Waiting for new EC2 instance (EC2-v3) to be ready..."
    aws ec2 wait instance-running --instance-ids $NEW_INSTANCE_ID
    NEW_INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $NEW_INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    echo "New EC2 instance (EC2-v3) launched with Public IP: $NEW_INSTANCE_PUBLIC_IP"
    
    # Create Load Balancer Security Group
    LB_SG=$(aws ec2 create-security-group --group-name Lab-LB-SG --description "Load Balancer Security Group" --vpc-id $VPC_ID --query 'GroupId' --output text)
    aws ec2 authorize-security-group-ingress --group-id $LB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0

    # Modify Lab-Server-SG for private subnet usage
    aws ec2 revoke-security-group-ingress --group-id $LAB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --group-id $LAB_SG --protocol tcp --port 80 --source-group $LB_SG
    aws ec2 authorize-security-group-ingress --group-id $LAB_SG --protocol tcp --port 443 --source-group $LB_SG

    # Create Load Balancer
    LB_ARN=$(aws elbv2 create-load-balancer --name Lab-Server-LB --subnets $PUB_SUBNET1 $PUB_SUBNET2 --security-groups $LB_SG \
    --tags Key=Name,Value=Lab-Server-LB --query 'LoadBalancers[0].LoadBalancerArn' --output text)
    aws elbv2 wait load-balancer-available --load-balancer-arns $LB_ARN

    # Create Target Group
    TG_ARN=$(aws elbv2 create-target-group --name Lab-Server-TG --protocol HTTP --port 80 --vpc-id $VPC_ID \
        --tags Key=Name,Value=Lab-Server-TG --query 'TargetGroups[0].TargetGroupArn' --output text)

    # Register Targets
    aws elbv2 register-targets --target-group-arn $TG_ARN --targets Id=$INSTANCE_ID

    # Create Auto Scaling Group (using Launch Template)
    ASG_NAME="Lab-ASG"
    aws autoscaling create-auto-scaling-group --auto-scaling-group-name $ASG_NAME \
    --min-size 2 --max-size 6 --desired-capacity 2 \
    --vpc-zone-identifier "$PRIV_SUBNET1,$PRIV_SUBNET2" \
    --target-group-arns $TG_ARN --health-check-type ELB \
    --tags Key=Name,Value=Lab-ASG --health-check-grace-period 300 \
    --launch-template "LaunchTemplateName=LabServerV3Template"

    # Set a target tracking scaling policy for 50% CPU utilization
    aws autoscaling put-scaling-policy \
    --auto-scaling-group-name $ASG_NAME \
    --policy-name CPU50PercentPolicy \
    --policy-type TargetTrackingScaling \
    --target-tracking-configuration "{
       \"TargetValue\":50.0,
       \"PredefinedMetricSpecification\":{
         \"PredefinedMetricType\":\"ASGAverageCPUUtilization\"
       },
       \"ScaleOutCooldown\":60,
       \"ScaleInCooldown\":60
    }"

    echo "Phase 3 Complete: Load Balancer and Auto Scaling setup finished"
}

# Phase 4: Load Testing
function phase4() {

    echo "Starting Phase 4: Load Testing"
    npm install -g loadtest

    echo "Running loadtest on the application"
    ELB_URL=$(aws elbv2 describe-load-balancers --names Lab-Server-LB --query 'LoadBalancers[0].DNSName' --output text)
    loadtest --rps 1000 -c 500 -k $ELB_URL
    echo "Load Testing executed"
}

# Phase 5: Cleanup
function phase5() {
    echo "Starting Phase 5: Cleanup"
    
    # Terminate EC2 instances
    echo "Terminating EC2 instances..."
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID $NEW_INSTANCE_ID
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID $NEW_INSTANCE_ID
    echo "EC2 instances terminated."

    # Delete EC2 Key Pairs
    echo "Deleting EC2 Key Pairs..."
    aws ec2 delete-key-pair --key-name $KEY_NAME
    aws ec2 delete-key-pair --key-name $ASG_KEY_NAME
    echo "EC2 Key Pairs deleted."

    # Delete Launch Template
    echo "Deleting Launch Template..."
    aws ec2 delete-launch-template --launch-template-name LabServerV3Template
    echo "Launch Template deleted."

    # Delete RDS instance
    echo "Deleting RDS instance..."
    aws rds delete-db-instance --db-instance-identifier LabRDS --skip-final-snapshot
    aws rds wait db-instance-deleted --db-instance-identifier LabRDS
    echo "RDS instance deleted."

    # Delete RDS Secret
    echo "Deleting RDS secret..."
    aws secretsmanager delete-secret --secret-id $SECRET_ARN --force-delete-without-recovery
    echo "RDS secret deleted."

    # Delete Load Balancer and Target Group
    echo "Deleting Load Balancer..."
    aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN
    echo "Load Balancer deleted."
    
    echo "Deleting Target Group..."
    aws elbv2 delete-target-group --target-group-arn $TG_ARN
    echo "Target Group deleted."

    # Delete Auto Scaling Group
    echo "Deleting Auto Scaling Group..."
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $ASG_NAME --force-delete
    echo "Auto Scaling Group deleted."

    # Delete Security Groups
    echo "Deleting Security Groups..."
    aws ec2 delete-security-group --group-id $LAB_SG
    aws ec2 delete-security-group --group-id $RDS_SG
    aws ec2 delete-security-group --group-id $LB_SG
    echo "Security Groups deleted."

    # Delete Subnets
    echo "Deleting Subnets..."
    aws ec2 delete-subnet --subnet-id $PUB_SUBNET1
    aws ec2 delete-subnet --subnet-id $PUB_SUBNET2
    aws ec2 delete-subnet --subnet-id $PRIV_SUBNET1
    aws ec2 delete-subnet --subnet-id $PRIV_SUBNET2
    aws ec2 delete-subnet --subnet-id $DB_SUBNET1
    aws ec2 delete-subnet --subnet-id $DB_SUBNET2
    echo "Subnets deleted."

    # Delete Route Tables
    echo "Deleting Route Tables..."
    aws ec2 delete-route-table --route-table-id $PRIV_ROUTE_TABLE
    echo "Route Table deleted."

    # Delete NAT Gateway and Elastic IP
    echo "Deleting NAT Gateway..."
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID
    aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_GW_ID
    echo "NAT Gateway deleted."

    echo "Releasing Elastic IP..."
    aws ec2 release-address --allocation-id $EIP_ALLOC
    echo "Elastic IP released."

    # Delete Internet Gateway
    echo "Detaching and deleting Internet Gateway..."
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
    echo "Internet Gateway deleted."

    # Delete VPC
    echo "Deleting VPC..."
    aws ec2 delete-vpc --vpc-id $VPC_ID
    echo "VPC deleted."

    echo "Phase 5 Complete: All resources deleted."
}

## Execute Phases with Confirmation
phase1
read -p "Continue to Phase 2? (yes/no): " cont
if [ "$cont" == "yes" ]; then
    phase2
    read -p "Continue to Phase 3? (yes/no): " cont
    if [ "$cont" == "yes" ]; then
        phase3
        while true; do
            read -p "Continue to Phase 4? (yes/no): " cont
            if [ "$cont" == "yes" ]; then
                phase4
            else
                echo "Delete Resources and Exit? (yes/no)"
                break
                if [ "$cont" == "yes" ]; then
                    phase5
                else
                    echo "Exiting, All created resources still active..."
                    break
                fi
            fi
        done
    else
        echo "Deployment stopped after Phase 2"
    fi
else
    echo "Deployment stopped after Phase 1"
fi
