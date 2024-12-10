# Step 1: Create a database subnet group
aws rds create-db-subnet-group \
    --db-subnet-group-name my-db-subnet-group \
    --db-subnet-group-description "Database subnet group" \
    --subnet-ids <subnet-id-1> <subnet-id-2>

# Step 1.1: Create an RDS MySQL database instance
RDS_DB_IDENTIFIER=my-rds-instance
aws rds create-db-instance \
    --db-instance-identifier $RDS_DB_IDENTIFIER \
    --db-instance-class db.t2.micro \
    --engine mysql \
    --master-username <admin-username> \
    --master-user-password <admin-password> \
    --allocated-storage 20 \
    --db-subnet-group-name my-db-subnet-group \
    --vpc-security-group-ids <security-group-id> \
    --no-publicly-accessible

# Step 1.2: Store database credentials in AWS Secrets Manager
aws secretsmanager create-secret \
    --name MyRDSSecret \
    --description "RDS MySQL credentials" \
    --secret-string '{"username":"<admin-username>","password":"<admin-password>"}'

# Output RDS Endpoint for use in Step 4
aws rds describe-db-instances --query "DBInstances[?DBInstanceIdentifier=='$RDS_DB_IDENTIFIER'].Endpoint.Address" --output text







# Step 2.1: Create an Application Load Balancer
LOAD_BALANCER_ARN=$(aws elbv2 create-load-balancer \
    --name my-alb \
    --subnets <subnet-id-1> <subnet-id-2> \
    --security-groups <security-group-id> \
    --scheme internet-facing \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# Step 2.2: Create a target group for the ALB
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name my-target-group \
    --protocol HTTP \
    --port 80 \
    --vpc-id <vpc-id> \
    --target-type instance \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

# Step 2.3: Create a listener for the ALB
aws elbv2 create-listener \
    --load-balancer-arn $LOAD_BALANCER_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN




# Step 3.1: Create a Launch Template
LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
    --launch-template-name my-launch-template \
    --version-description "Version 1" \
    --launch-template-data '{"ImageId":"<ami-id>","InstanceType":"t2.micro","UserData":"<base64-encoded-userdata-script>","IamInstanceProfile":{"Name":"<instance-profile-name>"}}' \
    --query 'LaunchTemplate.LaunchTemplateId' --output text)

# Step 3.2: Create an Auto Scaling Group
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name my-asg \
    --launch-template "LaunchTemplateId=$LAUNCH_TEMPLATE_ID,Version=1" \
    --min-size 1 \
    --max-size 3 \
    --desired-capacity 1 \
    --vpc-zone-identifier "<subnet-id-1>,<subnet-id-2>" \
    --target-group-arns $TARGET_GROUP_ARN




# Step 4.1: Retrieve RDS Endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier $RDS_DB_IDENTIFIER \
    --query "DBInstances[0].Endpoint.Address" --output text)

# Step 4.2: Use Secrets Manager to retrieve credentials
SECRET=$(aws secretsmanager get-secret-value --secret-id MyRDSSecret --query 'SecretString' --output text)
USERNAME=$(echo $SECRET | jq -r '.username')
PASSWORD=$(echo $SECRET | jq -r '.password')

# Step 4.3: Import the SQL dump into RDS
mysql -h $RDS_ENDPOINT -u $USERNAME -p$PASSWORD < /path/to/sql-dump-file.sql




# Access the application via the Load Balancer DNS
aws elbv2 describe-load-balancers --query "LoadBalancers[?LoadBalancerArn=='$LOAD_BALANCER_ARN'].DNSName" --output text
