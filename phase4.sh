######################################
# Phase 4: Load Testing
######################################

phase4() {
    echo "Starting Phase 4: Load Testing"
    npm install -g loadtest || true

    echo "Running loadtest on the application"
    ELB_URL=$(aws elbv2 describe-load-balancers \
        --names "$LB_NAME"
        --query 'LoadBalancers[0].DNSName' \
        --output text)

    loadtest \
        --rps 1000 \
        -c 500 \
        -k "$ELB_URL" || true

    echo "Load Testing executed"
}