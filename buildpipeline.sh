#!/bin/bash

# Variables from GitHub Actions Secrets (they are passed as env variables)
TAG="$TAG_VERSION"  # This would come from GitHub Actions secrets
DOCKER_IMAGE="$DOCKER_IMAGE"
DOCKER_REGISTRY="$DOCKER_REGISTRY"
SONAR_HOST_URL="$SONAR_HOST_URL"
SONAR_PROJECT_KEY="$SONAR_PROJECT_KEY"
SONAR_LOGIN_TOKEN="$SONAR_LOGIN_TOKEN"
REPO_NAME="$REPO_NAME"

# Function to exit on failure and call failure.sh
exit_on_failure() {
    if [ $? -ne 0 ]; then
        bash failure.sh "$1"
        exit 1
    fi
}

# Step 1: Create repository (if required)
echo "Creating repository..."
bash create_repo.sh "$REPO_NAME"
exit_on_failure "Repository creation failed"

# Step 2: Tag the code
echo "Tagging the code with $TAG"
git tag "$TAG"
git push origin "$TAG"
exit_on_failure "Tagging failed"

# Step 3: Compile the code
echo "Compiling the code..."
mvn clean compile
exit_on_failure "Compilation failed"

# Step 4: Run unit tests
echo "Running unit tests..."
mvn test
exit_on_failure "Unit tests failed"

# Step 5: Run SonarQube analysis
echo "Running SonarQube analysis..."
mvn sonar:sonar \
  -Dsonar.host.url="$SONAR_HOST_URL" \
  -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
  -Dsonar.login="$SONAR_LOGIN_TOKEN"
exit_on_failure "SonarQube analysis failed"

# Step 6: Build Docker image
echo "Building Docker image..."
docker build -t "$DOCKER_IMAGE:$TAG" .
exit_on_failure "Docker image build failed"

# Step 7: Tag Docker image
echo "Tagging Docker image..."
docker tag "$DOCKER_IMAGE:$TAG" "$DOCKER_REGISTRY/$DOCKER_IMAGE:$TAG"
exit_on_failure "Docker image tagging failed"

# Step 8: Push Docker image to registry
echo "Pushing Docker image to registry..."
docker push "$DOCKER_REGISTRY/$DOCKER_IMAGE:$TAG"
exit_on_failure "Docker image push failed"

# Step 9: Call success.sh on success
bash send_success_email.sh "Build and push completed successfully"
