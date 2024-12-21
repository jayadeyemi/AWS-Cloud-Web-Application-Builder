#!/bin/bash

# status=0

############################################################################################################
# Phase 3: Auto Scaling and Load Balancer Setup 
############################################################################################################

echo -e "\n\n\n"
echo "---------------------------------------------------------------------------------------------------------"
echo "############################################################################################################"
echo "# Starting Phase 3: Load Balancer and Auto Scaling Setup"
echo "############################################################################################################"
echo -e "\n\n\n"

# Create a security group for the load balancer
if [[ $status -eq 0 ]]; then
    execute_command "LB_SG_ID=\$(aws ec2 create-security-group --group-name \"$LB_SG_NAME\" --description \"Load Balancer Security Group\" --vpc-id \"$MAIN_VPC_ID\" --query 'GroupId' --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=\"$LB_SG_NAME\"}]' --output text)"
    status=$?
fi

# Create a security group for the ASG
if [[ $status -eq 0 ]]; then
    execute_command "ASG_SG_ID=\$(aws ec2 create-security-group --group-name \"$ASG_SG_NAME\" --description \"ASG Security Group\" --vpc-id \"$MAIN_VPC_ID\" --query 'GroupId' --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=\"$ASG_SG_NAME\"}]' --output text)"
    status=$?
fi

# Create a launch template for ASG
if [[ $status -eq 0 ]]; then
    execute_command "LAUNCH_TEMPLATE_ID=\$(aws ec2 create-launch-template --launch-template-name \"$LAUNCH_TEMPLATE_NAME\" --version-description \"Initial version\" --launch-template-data '{\"ImageId\":\"$SERVER_V2_IMAGE_ID\",\"InstanceType\":\"t2.micro\",\"KeyName\":\"$PRIVATE_KEY\",\"SecurityGroupIds\":[\"$ASG_SG_ID\"]}' --query 'LaunchTemplate.LaunchTemplateId' --output text)"
    execute_command "LAUNCH_TEMPLATE_ID=\$(aws ec2 create-launch-template --launch-template-name \"$LAUNCH_TEMPLATE_NAME\" --version-description \"Initial version\" --launch-template-data '{\"ImageId\":\"$SERVER_V2_IMAGE_ID\",\"InstanceType\":\"t2.micro\",\"KeyName\":\"$PRIVATE_KEY\",\"SecurityGroupIds\":[\"$ASG_SG_ID\"],\"IamInstanceProfile\":{\"Name\":\"$INVENTORY_SERVER_ROLE\"}}' --query 'LaunchTemplate.LaunchTemplateId' --output text)"

    status=$?
fi

# Authorize Internet Access to Load Balancer Security Group
if [[ $status -eq 0 ]]; then
    execute_command "LB_SG_INTERNET_CIDR_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$LB_SG_ID\" --protocol tcp --port 80 --cidr \"$INTERNET_CIDR\" --query 'SecurityGroupRuleId' --output text)"
    status=$?
fi

# Authorize SSH Access to ASG Security Group
if [[ $status -eq 0 ]]; then
    execute_command "ASG_SG_USER_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$ASG_SG_ID\" --protocol tcp --port 22 --cidr \"$USER_CIDR\" --query 'SecurityGroupRuleId' --output text)"
    status=$?
fi

# Authorize Access from Load Balancer Security Group to ASG Security Group
if [[ $status -eq 0 ]]; then
    execute_command "ASG_SG_LB_SG_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$ASG_SG_ID\" --protocol tcp --port 80 --source-group \"$LB_SG_ID\" --query 'SecurityGroupRuleId' --output text)"
    status=$?
fi

# Authorize Access from ASG Security Group to Load Balancer Security Group
if [[ $status -eq 0 ]]; then
    execute_command "LB_SG_ASG_SG_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$LB_SG_ID\" --protocol tcp --port 80 --source-group \"$ASG_SG_ID\" --query 'SecurityGroupRuleId' --output text)"
    status=$?
fi

# Authorize Access from ASG Security Group to DB Security Group
if [[ $status -eq 0 ]]; then
    execute_command "ASG_SG_DB_SG_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$RDS_SG_ID\" --protocol tcp --port 3306 --source-group \"$ASG_SG_ID\" --query 'SecurityGroupRuleId' --output text)"
    status=$?
fi

# Authorize Access from DB Security Group to ASG Security Group
if [[ $status -eq 0 ]]; then
    execute_command "DB_SG_ASG_SG_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$ASG_SG_ID\" --protocol tcp --port 3306 --source-group \"$RDS_SG_ID\" --query 'SecurityGroupRuleId' --output text)"
    status=$?
fi
# Create a target group for the load balancer
if [[ $status -eq 0 ]]; then
    execute_command "TG_ARN=\$(aws elbv2 create-target-group --name \"$TG_NAME\" --protocol HTTP --port 80 --vpc-id \"$MAIN_VPC_ID\" --tags Key=Name,Value=\"$TG_NAME\" --query 'TargetGroups[0].TargetGroupArn' --output text)"
    status=$?
fi

# Create a load balancer and attach the target group
if [[ $status -eq 0 ]]; then
    sleep 60
    execute_command "LB_ARN=\$(aws elbv2 create-load-balancer --name \"$LB_NAME\" --subnets \"$PUB_SUBNET1\" \"$PUB_SUBNET2\" --security-groups \"$LB_SG_ID\" --ip-address-type ipv4 --query 'LoadBalancers[0].LoadBalancerArn' --output text)"
    status=$?
fi

# Wait for the load balancer to be available
if [[ $status -eq 0 ]]; then
    execute_command "aws elbv2 wait load-balancer-available --load-balancer-arns \"$LB_ARN\" --cli-read-timeout 0 --output text"
    status=$?
fi

# Create an autoscaling group and attach the target group
if [[ $status -eq 0 ]]; then
    execute_command "ASG_GROUP=\$(aws autoscaling create-auto-scaling-group --auto-scaling-group-name \"$ASG_NAME\" --launch-template LaunchTemplateId=\"$LAUNCH_TEMPLATE_ID\",Version=1 --min-size 2 --max-size 6 --desired-capacity 2 --target-group-arns \"$TG_ARN\" --vpc-zone-identifier \"$PRIV_SUBNET1,$PRIV_SUBNET2\" --health-check-type ELB --health-check-grace-period 300 --tags ResourceId=\"\$ASG_NAME\",ResourceType=auto-scaling-group,Key=Name,Value=\"$ASG_NAME\",PropagateAtLaunch=true)"
    status=$?
fi

# Create a scaling policy for the autoscaling group
if [[ $status -eq 0 ]]; then
    execute_command "ASG_GROUP_POLICY=\$(aws autoscaling put-scaling-policy --policy-name \"$ASG_POLICY_NAME\" --auto-scaling-group-name \"$ASG_NAME\" --policy-type TargetTrackingScaling --target-tracking-configuration file://\"$ASG_CONFIG\")"
    status=$?
fi


# Create an internet listener for the load balancer
if [[ $status -eq 0 ]]; then
    execute_command "aws elbv2 create-listener --load-balancer-arn \"$LB_ARN\" --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=\"$TG_ARN\""
    status=$?
fi

# Get the DNS name of the load balancer
if [[ $status -eq 0 ]]; then
    execute_command "LB_DNS=\$(aws elbv2 describe-load-balancers --names \"$LB_NAME\" --query 'LoadBalancers[0].DNSName' --output text)"
    status=$?
fi

if [[ $status -eq 0 ]]; then

    echo -e "\n\n\n"
    echo "############################################################################################################"
    echo "# Phase 3 Complete: Load Balancer and Auto Scaling setup finished."
    echo "# You can access the application through the load balancer at http://$LB_DNS"
    echo "############################################################################################################"
    echo "-------------------------------------------------------------------------------------------------------------"
else
    echo -e "\n\n\n"
    echo "############################################################################################################"
    echo "# Phase 3 encountered errors and did not complete successfully."
    echo "############################################################################################################"
    echo "-------------------------------------------------------------------------------------------------------------"
fi
echo -e "\n\n\n"

############################################################################################################
# End of Phase 3
############################################################################################################
