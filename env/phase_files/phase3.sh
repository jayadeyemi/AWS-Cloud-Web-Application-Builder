#!/bin/bash

######################################
# Phase 3: Load Balancer and Auto Scaling Setup
######################################

echo -e "\n\n\n"
echo "######################################"
echo "# Starting Phase 3: Load Balancer and Auto Scaling Setup"
echo "######################################"
# Initialize status variable to track failures
status=0

if [[ $status -eq 0 ]]; then
    echo "Creating EC2-v3 Launch Template..."
    execute_command "LAUNCH_TEMPLATE_ID=\$(aws ec2 create-launch-template --launch-template-name \"$LAUNCH_TEMPLATE_NAME\" --version-description \"Initial version\" --launch-template-data '{\"ImageId\":\"$SERVER_V2_IMAGE_ID\",\"InstanceType\":\"t2.micro\",\"KeyName\":\"$PRIV_KEY\",\"SecurityGroupIds\":[\"$EC2_V1_SG_NAME\"]}' --query 'LaunchTemplate.LaunchTemplateId' --output text)"
    status=$?
fi

if [[ $status -eq 0 ]]; then
    execute_command "LB_SG=\$(aws ec2 create-security-group --group-name \"$LB_SG_NAME\" --description \"Load Balancer Security Group\" --vpc-id \"$MAIN_VPC_ID\" --query 'GroupId' --output text)"
    status=$?
fi

if [[ $status -eq 0 ]]; then
    execute_command "LB_SG_INTERNET_CIDR_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$LB_SG\" --protocol tcp --port 80 --cidr \"$INTERNET_CIDR\" --query 'SecurityGroupRuleId' --output text)"
    status=$?
fi

if [[ $status -eq 0 ]]; then
    execute_command "LB_SG_EC2_V1_SG_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$LB_SG\" --protocol tcp --port 80 --source-group \"$EC2_V1_SG_NAME\" --query 'SecurityGroupRuleId' --output text)"
    status=$?
fi

# Remove the rule that allows all traffic from the internet
if [[ $status -eq 0 ]]; then
    execute_command "EC2_V1_SG_INTERNET_ACCESS=\$(aws ec2 revoke-security-group-ingress --group-id \"$EC2_V1_SG_NAME\" --protocol tcp --port 80 --cidr \"$INTERNET_CIDR\")"
    status=$?
fi

if [[ $status -eq 0 ]]; then
    execute_command "TG_ARN=\$(aws elbv2 create-target-group --name \"$TG_NAME\" --protocol HTTP --port 80 --vpc-id \"$MAIN_VPC_ID\" --tags Key=Name,Value=\"$TG_NAME\" --query 'TargetGroups[0].TargetGroupArn' --output text)"
    status=$?
fi

if [[ $status -eq 0 ]]; then
    sleep 60
    execute_command "LB_ARN=\$(aws elbv2 create-load-balancer --name \"$LB_NAME\" --subnets \"$PUB_SUBNET1\" \"$PUB_SUBNET2\" --security-groups \"$LB_SG\" --ip-address-type ipv4 --query 'LoadBalancers[0].LoadBalancerArn' --output text)"
    status=$?
fi

if [[ $status -eq 0 ]]; then
    execute_command "aws elbv2 wait load-balancer-available --load-balancer-arns \"$LB_ARN\" --cli-read-timeout 0 --output text"
    status=$?
fi

if [[ $status -eq 0 ]]; then
    execute_command "ASG_GROUP=\$(aws autoscaling create-auto-scaling-group --auto-scaling-group-name \"$EC2_ASG_NAME\" --launch-template LaunchTemplateId=\"$LAUNCH_TEMPLATE_ID\",Version=1 --min-size 2 --max-size 6 --desired-capacity 2 --target-group-arns \"$TG_ARN\" --vpc-zone-identifier \"$PRIV_SUBNET1,$PRIV_SUBNET2\" --target-tracking-configuration file://config.json)"
    status=$?
fi

if [[ $status -eq 0 ]]; then
    execute_command "LB_DNS=\$(aws elbv2 describe-load-balancers --names \"$LB_NAME\" --query 'LoadBalancers[0].DNSName' --output text)"
    status=$?
fi

if [[ $status -eq 0 ]]; then
    echo "Phase 3 Complete: Load Balancer and Auto Scaling setup finished."
    echo "Load Balancer DNS: $LB_DNS"
else
    echo "Phase 3 encountered errors and did not complete successfully."
fi
