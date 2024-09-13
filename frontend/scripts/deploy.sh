#!/bin/bash

# Set up Node.js
echo "Setting up Node.js 18..."
# Add commands to set up Node.js if necessary

# Build frontend
echo "Building frontend..."
if npm run build; then
    BUILD_SUCCESS=true
else
    BUILD_SUCCESS=false
    echo "Frontend build failed, but continuing to deploy..."
fi

# Configure AWS credentials
echo "Configuring AWS credentials..."
# Add commands to configure AWS credentials if necessary

# Deploy to S3
echo "Deploying to S3..."
if aws s3 sync build/ s3://${S3_BUCKET}/${PROJECT_NAME}/new-reports; then
    echo "Successfully uploaded frontend build to S3"
else
    echo "Failed to upload frontend build to S3"
    exit 1
fi

# If build failed, exit here
if [ "$BUILD_SUCCESS" = false ]; then
    echo "Build failed. Exiting after S3 upload."
    exit 1
fi

# The rest of the script only runs if the build was successful

# Upload artifact
echo "Uploading artifact..."
# Add commands to upload artifact if necessary

# Login to Amazon ECR (if using Docker)
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REPO_URL}

# Build, tag, and push image to Amazon ECR (if using Docker)
echo "Building and pushing Docker image..."
docker build -t ${REPO_URL}:latest .
docker push ${REPO_URL}:latest

# Update ECS service (if using ECS)
echo "Updating ECS service..."
aws ecs update-service --cluster ${CLUSTER} --service ${SERVICE} --force-new-deployment

echo "Script completed successfully."
