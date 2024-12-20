#!/bin/bash
##################################################################################################################
# Phase 5: Cleanup
##################################################################################################################

echo -e "/n/n/n"
echo "############################################################################################################"
echo "# Starting Phase 5: Cleanup of provisioned Resources"
echo "############################################################################################################"
echo -e "\n\n\n"

# Authorize files to be created
chmod +x "$CLEANER_DIR"
# Helper function
check_command_success() {
    if [ $? -eq 0 ]; then
        echo "$1 succeeded."
    else
        echo "$1 failed or resource does not exist. Skipping..."
    fi
}

# Create separate execution files
cat << 'EOF' > "$CLEANER_DIR/delete_key_pairs.sh"
#!/bin/bash
for key_name in "$PUBLIC_KEY" "$PRIVATE_KEY"; do
    if [ -n "$key_name" ]; then
        aws ec2 delete-key-pair --key-name "$key_name" || true
        rm -f "$key_name.pem"
        check_command_success "Delete key pair $key_name"
    fi
done
EOF

cat << 'EOF' > "$CLEANER_DIR/scale_down_asg.sh"
#!/bin/bash
aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$ASG_NAME" --min-size 0 --desired-capacity 0 || true
check_command_success "Scale down ASG"
EOF

cat << 'EOF' > "$CLEANER_DIR/terminate_instances.sh"
#!/bin/bash
for instance_id in "$INSTANCE_ID" "$NEW_INSTANCE_ID"; do
    if [ -n "$instance_id" ]; then
        aws ec2 terminate-instances --instance-ids "$instance_id" --output text > /dev/null 2>&1
        check_command_success "Terminate instance $instance_id"
    fi
done
EOF

cat << 'EOF' > "$CLEANER_DIR/delete_launch_template.sh"
#!/bin/bash
if aws ec2 describe-launch-templates --launch-template-names "$LAUNCH_TEMPLATE_NAME" >/dev/null 2>&1; then
    aws ec2 delete-launch-template --launch-template-name "$LAUNCH_TEMPLATE_NAME"
    check_command_success "Delete launch template $LAUNCH_TEMPLATE_NAME"
fi
EOF

cat << 'EOF' > "$CLEANER_DIR/deregister_amis.sh"
#!/bin/bash
if [ -n "$SERVER_V1_IMAGE_ID" ]; then
    aws ec2 deregister-image --image-id "$SERVER_V1_IMAGE_ID"
    check_command_success "Deregister AMI $SERVER_V1_IMAGE_ID"
fi

if [ -n "$SERVER_V2_IMAGE_ID" ]; then
    aws ec2 deregister-image --image-id "$SERVER_V2_IMAGE_ID"
    check_command_success "Deregister AMI $SERVER_V2_IMAGE_ID"
fi
EOF

cat << 'EOF' > "$CLEANER_DIR/delete_rds_instance.sh"
#!/bin/bash
if aws rds describe-db-instances --db-instance-identifier "$RDS_IDENTIFIER" >/dev/null 2>&1; then
    aws rds delete-db-instance --db-instance-identifier "$RDS_IDENTIFIER" --skip-final-snapshot > /dev/null 2>&1
    check_command_success "Delete RDS instance $RDS_IDENTIFIER"
fi
EOF

cat << 'EOF' > "$CLEANER_DIR/delete_load_balancer.sh"
#!/bin/bash
if [ -n "$LB_ARN" ]; then
    aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN"
    check_command_success "Delete load balancer $LB_ARN"
    sleep 30
fi

if [ -n "$TG_ARN" ]; then
    aws elbv2 delete-target-group --target-group-arn "$TG_ARN"
    check_command_success "Delete target group $TG_ARN"
fi

if [ -n "$LB_ARN" ]; then
    aws elbv2 delete-listener --load-balancer-arn "$LB_ARN" --port 80
    check_command_success "Delete listener for load balancer $LB_ARN"
fi
EOF

cat << 'EOF' > "$CLEANER_DIR/revoke_ingress_rules.sh"
#!/bin/bash
for sg_id in "$EC2_V1_SG_ID" "$RDS_SG" "$LB_SG" "$EC2_V1_SG_ID" "$ASG_SG_ID"; do
    rule_ids=$(aws ec2 describe-security-group-rules \
        --filters Name="group-id",Values="$CLOUD9_SG_ID" Name="is-egress",Values="false" \
        --query "SecurityGroupRules[?GroupId=='$CLOUD9_SG_ID'].SecurityGroupRuleId" \
        --output text)

    if [[ -n "$rule_ids" ]]; then
        aws ec2 revoke-security-group-ingress --group-id "$CLOUD9_SG_ID" --security-group-rule-ids $rule_ids
        check_command_success "Revoke ingress rules for security group $CLOUD9_SG_ID"
    else
        echo "No ingress rules found for security group $CLOUD9_SG_ID"
    fi
done
EOF

cat << 'EOF' > "$CLEANER_DIR/delete_security_groups.sh"
#!/bin/bash
for sg_id in "$EC2_V1_SG_ID" "$RDS_SG_ID" "$EC2_V2_SG_ID" "$LB_SG_ID" "$ASG_SG_ID"; do
    if [[ -n "$sg_id" ]]; then
        echo "Processing Security Group: $sg_id"
        rule_ids=$(aws ec2 describe-security-group-rules \
            --filters Name="group-id",Values="$sg_id" Name="is-egress",Values="false" \
            --query "SecurityGroupRules[?GroupId=='$sg_id'].SecurityGroupRuleId" \
            --output text)

        if [[ -n "$rule_ids" ]]; then
            for rule in $rule_ids; do
                if aws ec2 revoke-security-group-ingress --group-id "$sg_id" --security-group-rule-ids "$rule" --output text; then
                    check_command_success "Revoke rule $rule from $sg_id"
                else
                    echo "Failed to revoke rule $rule from $sg_id"
                fi
            done
        else
            echo "No ingress rules found for Security Group: $sg_id"
        fi
    else
        echo "Security Group ID is empty, skipping."
    fi
done

for sg_id in "$EC2_V1_SG_ID" "$RDS_SG_ID" "$EC2_V2_SG_ID" "$LB_SG_ID" "$ASG_SG_ID"; do
    echo "Deleting Security Groups..."
    if [ -n "$sg_id" ]; then
        aws ec2 delete-security-group --group-id "$sg_id" || true
        check_command_success "Delete security group $sg_id"
    fi
done
EOF

cat << 'EOF' > "$CLEANER_DIR/delete_rds_subnet_group.sh"
#!/bin/bash
if [ -n "$RDS_IDENTIFIER" ]; then
    aws rds wait db-instance-deleted --db-instance-identifier "$RDS_IDENTIFIER" || true
fi

echo "Deleting DB Subnet Group..."
aws rds delete-db-subnet-group --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" || true
check_command_success "Delete DB Subnet Group $DB_SUBNET_GROUP_NAME"
EOF

cat << 'EOF' > "$CLEANER_DIR/delete_nat_gateway.sh"
#!/bin/bash
echo "Deleting NAT Gateway..."
if [ -n "$NAT_GW_ID" ]; then
    aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_GW_ID" || true
    aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT_GW_ID" || true
    check_command_success "Delete NAT Gateway $NAT_GW_ID"
fi

if [ -n "$EIP_ALLOC" ]; then
    aws ec2 release-address --allocation-id "$EIP_ALLOC" || true
    check_command_success "Release Elastic IP $EIP_ALLOC"
fi
EOF

cat << 'EOF' > "$CLEANER_DIR/delete_internet_gateway.sh"
#!/bin/bash
echo "Detaching and deleting Internet Gateway..."
if [ -n "$IGW_ID" ] && [ -n "$MAIN_VPC_ID" ]; then
    sleep 10
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$MAIN_VPC_ID" || true
    sleep 10
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" || true
    check_command_success "Delete Internet Gateway $IGW_ID"
fi
EOF

cat << 'EOF' > "$CLEANER_DIR/delete_vpc_peering.sh"
#!/bin/bash
echo "Deleting Route Tables for VPC Peering Connection..."
if [ -n "$DEFAULT_ROUTE_TABLE_ID" ]; then
    aws ec2 delete-route --route-table-id "$DEFAULT_ROUTE_TABLE_ID" --destination-cidr-block "$VPC_CIDR" || true
    check_command_success "Delete route for VPC Peering Connection"
fi

echo "Deleting VPC Peering Connection..."
if [ -n "$PEERING_CONNECTION_ID" ]; then
    aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id "$PEERING_CONNECTION_ID" || true
    check_command_success "Delete VPC Peering Connection $PEERING_CONNECTION_ID"
fi
EOF

cat << 'EOF' > "$CLEANER_DIR/delete_subnets.sh"
#!/bin/bash
echo "Deleting Subnets..."
for subnet_id in "$PUB_SUBNET1" "$PUB_SUBNET2" "$PRIV_SUBNET1" "$PRIV_SUBNET2" "$DB_SUBNET1" "$DB_SUBNET2"; do
    if [ -n "$subnet_id" ]; then
        aws ec2 delete-subnet --subnet-id "$subnet_id" || true
        check_command_success "Delete subnet $subnet_id"
    fi
done
EOF

cat << 'EOF' > "$CLEANER_DIR/delete_route_tables.sh"
#!/bin/bash
if [ -n "$PUB_ROUTE_TABLE_ID" ]; then
    aws ec2 delete-route-table --route-table-id "$PUB_ROUTE_TABLE_ID" || true
    check_command_success "Delete public route table $PUB_ROUTE_TABLE_ID"
fi

if [ -n "$PRIV_ROUTE_TABLE_ID" ]; then
    aws ec2 delete-route-table --route-table-id "$PRIV_ROUTE_TABLE_ID" || true
    check_command_success "Delete private route table $PRIV_ROUTE_TABLE_ID"
fi

if [ -n "$DB_ROUTE_TABLE_ID" ]; then
    aws ec2 delete-route-table --route-table-id "$DB_ROUTE_TABLE_ID" || true
    check_command_success "Delete DB route table $DB_ROUTE_TABLE_ID"
fi
EOF

cat << 'EOF' > "$CLEANER_DIR/delete_vpc.sh"
#!/bin/bash
echo "Deleting VPC..."
if [ -n "$MAIN_VPC_ID" ]; then
    sleep 10
    aws ec2 delete-vpc --vpc-id "$MAIN_VPC_ID" || true
    check_command_success "Delete VPC $MAIN_VPC_ID"
fi
EOF
wait 20
# Make the scripts executable
chmod +x "$CLEANER_DIR"/*.sh
# Execute the caller script
source "$CALLER"

