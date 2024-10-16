#!/bin/bash

# Usage: ./ecr-copy.sh <source-region> <source-account-id> <source-repo-name> <tag> <destination-region> <destination-account-id> <destination-repo-name>

# Input parameters
SOURCE_REGION=$1
SOURCE_ACCOUNT_ID=$2
SOURCE_REPO_NAME=$3
IMAGE_TAG=$4
DESTINATION_REGION=$5
DESTINATION_ACCOUNT_ID=$6
DESTINATION_REPO_NAME=$7

# Check if all arguments are passed
if [ "$#" -ne 7 ]; then
    echo "Usage: $0 <source-region> <source-account-id> <source-repo-name> <tag> <destination-region> <destination-account-id> <destination-repo-name>"
    exit 1
fi

# Log in to the source registry
echo "Logging in to the source ECR registry..."
aws ecr get-login-password --region "$SOURCE_REGION" | docker login --username AWS --password-stdin "$SOURCE_ACCOUNT_ID".dkr.ecr."$SOURCE_REGION".amazonaws.com

# Pull the image from the source ECR
echo "Pulling the image from the source registry..."
docker pull "$SOURCE_ACCOUNT_ID".dkr.ecr."$SOURCE_REGION".amazonaws.com/"$SOURCE_REPO_NAME":"$IMAGE_TAG"

# Tag the image for the destination registry
echo "Tagging the image for the destination registry..."
docker tag "$SOURCE_ACCOUNT_ID".dkr.ecr."$SOURCE_REGION".amazonaws.com/"$SOURCE_REPO_NAME":"$IMAGE_TAG" \
    "$DESTINATION_ACCOUNT_ID".dkr.ecr."$DESTINATION_REGION".amazonaws.com/"$DESTINATION_REPO_NAME":"$IMAGE_TAG"

# Log in to the destination registry
echo "Logging in to the destination ECR registry..."
aws ecr get-login-password --region "$DESTINATION_REGION" | docker login --username AWS --password-stdin "$DESTINATION_ACCOUNT_ID".dkr.ecr."$DESTINATION_REGION".amazonaws.com

# Push the image to the destination ECR
echo "Pushing the image to the destination registry..."
docker push "$DESTINATION_ACCOUNT_ID".dkr.ecr."$DESTINATION_REGION".amazonaws.com/"$DESTINATION_REPO_NAME":"$IMAGE_TAG"

# Optionally remove the local image to free up space
echo "Cleaning up local images..."
docker rmi "$SOURCE_ACCOUNT_ID".dkr.ecr."$SOURCE_REGION".amazonaws.com/"$SOURCE_REPO_NAME":"$IMAGE_TAG"
docker rmi "$DESTINATION_ACCOUNT_ID".dkr.ecr."$DESTINATION_REGION".amazonaws.com/"$DESTINATION_REPO_NAME":"$IMAGE_TAG"

echo "Image successfully copied from $SOURCE_ACCOUNT_ID/$SOURCE_REPO_NAME to $DESTINATION_ACCOUNT_ID/$DESTINATION_REPO_NAME."
