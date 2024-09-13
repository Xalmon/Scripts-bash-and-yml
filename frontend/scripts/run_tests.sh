#!/bin/bash
set -e

# Set up Node.js
echo "Setting up Node.js 18..."
# Add commands to set up Node.js if necessary

# Run automation tests
echo "Running automation tests..."
npm install
npm test

# Login to Amazon ECR (if using Docker)
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REPO_URL}

# Build, tag, and push test Docker image to Amazon ECR (if using Docker)
echo "Building and pushing test Docker image..."
docker build -t ${REPO_URL}/${ECR_REPOSITORY_SYSTEST}:latest .
docker push ${REPO_URL}/${ECR_REPOSITORY_SYSTEST}:latest 

# Update ECS service for systest (if using ECS)
echo "Updating ECS service for systest..."
aws ecs update-service --cluster ${CLUSTER} --service ${SYSTEST_SERVICE} --force-new-deployment

echo "Script completed successfully."
