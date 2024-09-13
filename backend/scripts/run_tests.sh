#!/bin/bash
set -e

REPO_PAT=$1

# Set up Python
echo "Setting up Python 3.12.3..."
# Add commands to set up Python if necessary

# Run automation test
echo "Running automation tests..."
chmod +x ./run_pytest.sh
./run_pytest.sh "$REPO_PAT"

# Login to Amazon ECR
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 357586184453.dkr.ecr.eu-west-1.amazonaws.com

# Build, tag, and push systest image to Amazon ECR
echo "Building and pushing systest Docker image..."
docker build -t ${ECR_REPOSITORY}/${ECR_REPOSITORY_SYSTEST}:latest .
docker push ${ECR_REPOSITORY}/${ECR_REPOSITORY_SYSTEST}:latest 

# Update ECS service for systest
echo "Updating ECS service for systest..."
aws ecs update-service --cluster ${CLUSTER} --service ${SYSTEST_SERVICE} --force-new-deployment
