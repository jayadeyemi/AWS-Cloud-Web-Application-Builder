#!/bin/bash

# This script is a caller script that runs all the cleanup scripts in the correct order.
set -euo pipefail

CLEANER_DIR="$(dirname "$0")"

# Ensure that all variables referenced below are exported and available, e.g.:
# export PUBLIC_KEY PRIVATE_KEY ASG_NAME INSTANCE_ID NEW_INSTANCE_ID LAUNCH_TEMPLATE_NAME ...
# This should be done before this script runs.

# 1. Delete Key Pairs
"$CLEANER_DIR/delete_key_pairs.sh" &
# 2. Scale down ASG to zero before terminating instances
"$CLEANER_DIR/scale_down_asg.sh" &
# 3. Terminate EC2 instances and wait for them to be terminated
"$CLEANER_DIR/terminate_instances.sh" &
# 4. Delete Launch Template
"$CLEANER_DIR/delete_launch_template.sh" &
# 5. Deregister AMIs
"$CLEANER_DIR/deregister_amis.sh" &
# 6. Delete RDS instance
"$CLEANER_DIR/delete_rds_instance.sh"
sleep 10

if [ -n "$RDS_IDENTIFIER" ]; then
    aws rds wait db-instance-deleted --db-instance-identifier "$RDS_IDENTIFIER" || true
fi &
# 7. Delete RDS Subnet Group
"$CLEANER_DIR/delete_rds_subnet_group.sh" &
# 8. Delete Load Balancer, Target Group, and Listener
"$CLEANER_DIR/delete_load_balancer.sh" &
# 9. Delete Security Groups (once no rules or resources depend on them)
"$CLEANER_DIR/delete_security_groups.sh"
# 10. Delete NAT Gateway and wait for it to be fully deleted before releasing EIP
"$CLEANER_DIR/delete_nat_gateway.sh"
sleep 10

# 11. Detach and Delete Internet Gateway
"$CLEANER_DIR/delete_internet_gateway.sh"

# 12. Delete VPC Peering Connection and related routes
"$CLEANER_DIR/delete_vpc_peering.sh"

# 13. Delete Route Tables
"$CLEANER_DIR/delete_route_tables.sh"

# 14. Delete Subnets
"$CLEANER_DIR/delete_subnets.sh"

# 15 . Delete the VPC
"$CLEANER_DIR/delete_vpc.sh"
# Once everything inside is removed, the VPC can be deleted.

echo "All resources have been cleaned up according to AWS dependencies."

# Delete all cleaner scripts after completion
find "$CLEANER_DIR" -type f -name '*.sh' -delete


