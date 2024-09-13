#!/bin/bash
set -e

# Set up Node.js
echo "Setting up Node.js 18..."
# Add commands to set up Node.js if necessary

# Cache npm packages
echo "Caching npm packages..."
# Add commands to cache npm packages if necessary

# Build and analyze
echo "Running build and analyze..."
npm install
npm run build
npx sonar-scanner -Dsonar.projectKey=your-frontend-project -Dsonar.projectName='your-frontend-project'
