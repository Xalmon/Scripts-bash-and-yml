#!/bin/bash

# Set up JDK
echo "Setting up JDK 17..."
# Add commands to set up JDK if necessary

# Maven Package
echo "Running Maven Package..."
if mvn -B clean verify; then
    BUILD_SUCCESS=true
else
    BUILD_SUCCESS=false
    echo "Maven verify failed, but continuing to generate site..."
fi

# Generate Maven site
echo "Generating Maven site..."
mvn site || echo "Maven site generation failed, but continuing to upload..."

# Configure AWS credentials
echo "Configuring AWS credentials..."
# Add commands to configure AWS credentials if necessary

# Deploy to S3
echo "Deploying to S3..."
if aws s3 sync target/site s3://${S3_BUCKET}/${PROJECT_NAME}/new-reports; then
    echo "Successfully uploaded Maven site to S3"
else
    echo "Failed to upload Maven site to S3"
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

# Login to Amazon ECR
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REPO_URL}

# Build, tag, and push image to Amazon ECR
echo "Building and pushing Docker image..."
docker build -t ${REPO_URL}:latest .
docker push ${REPO_URL}:latest

# Update ECS service
echo "Updating ECS service..."
aws ecs update-service --cluster ${CLUSTER} --service ${SERVICE} --force-new-deployment

echo "Script completed successfully."
