#!/bin/bash

# Function to create repositories, set team permissions, and create branches
create_repo_with_teams_and_branches() {
    local repo_name=$1
    local qa_repo_name="${repo_name}_QA"

    # Get credentials from AWS Secrets Manager
    GITHUB_TOKEN=$(aws secretsmanager get-secret-value --secret-id github-token --query SecretString --output text)
   

    # Export the token as an environment variable
    export GITHUB_TOKEN=$GITHUB_TOKEN

    # Login to GitHub using the token
    echo "Logging in to GitHub..."
    gh auth login --with-token <<< $GITHUB_TOKEN > /dev/null 2>&1

    # Check if login was successful
    if gh auth status > /dev/null 2>&1; then
        echo "Successfully authenticated with GitHub."
    else
        echo "Failed to authenticate with GitHub."
        exit 1
    fi

    # Check if the organization exists
    echo "Checking if organization $ORG exists..."
    if ! gh api /orgs/$ORG > /dev/null 2>&1; then
        echo "Organization $ORG does not exist. Please create it manually."
        exit 1
    else
        echo "Organization $ORG exists."
    fi

    # Check if the repository already exists
    echo "Checking if repository $repo_name exists in $ORG..."
    if gh api /repos/$ORG/$repo_name > /dev/null 2>&1; then
        echo "Repository $ORG/$repo_name already exists."
        exit 1
    else
        echo "Repository $ORG/$repo_name does not exist. Creating repository..."
        gh repo create "$ORG/$repo_name" --private -y
        echo "# $repo_name" > README.md

        # Set up GitHub Actions workflow for auto-deleting branches after PR merge
        mkdir -p .github/workflows
        cat << 'EOF' > .github/workflows/auto-delete-branches.yml
name: Auto Delete Branches

on:
  pull_request:
    types:
      - closed

jobs:
  delete-merged-branch:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    steps:
      - name: Delete branch
        run: |
          branch_name=${{ github.event.pull_request.head.ref }}
          if [[ $branch_name != "main" && $branch_name != "dev" && $branch_name != "prod-support" ]]; then
            git push origin --delete $branch_name
          fi
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
EOF

        # Initialize Git repository and push to GitHub
        rm -rf .git
        git init
        git add .github/workflows/auto-delete-branches.yml README.md
        git commit -m "Repo creation"
        git branch -M main
        git remote add origin https://github.com/$ORG/$repo_name.git
        git push -u origin main
        git checkout -b dev
        git push origin dev
        git checkout -b prod-support
        git push origin prod-support
        echo "Created repository: $ORG/$repo_name"

        # Create the QA repository
        echo "Creating QA repository: $ORG/$qa_repo_name..."
        gh repo create "$ORG/$qa_repo_name" --private -y
        echo "# $qa_repo_name" > README.md

        # Initialize Git repository and push to GitHub
        rm -rf .git
        git init
        git add .github/workflows/auto-delete-branches.yml README.md
        git commit -m "Repo creation"
        git branch -M main
        git remote add origin https://github.com/$ORG/$qa_repo_name.git
        git push -u origin main
        git checkout -b dev
        git push origin dev
        git checkout -b prod-support
        git push origin prod-support
        echo "Created QA repository: $ORG/$qa_repo_name"

        # Add collaborators to the main repository
        IFS=',' read -r -a USER_ARRAY <<< "$USERS"
        for USER in "${USER_ARRAY[@]}"; do
            echo "Adding $USER to the repository $ORG/$repo_name with write permission..."
            gh api -X PUT "repos/$ORG/$repo_name/collaborators/$USER" -f permission=write
        done
        echo "All users have been added to the main repository."

        # Add collaborators to the QA repository
        IFS=',' read -r -a QA_USER_ARRAY <<< "$QA_USERS"
        for QA_USER in "${QA_USER_ARRAY[@]}"; do
            echo "Adding $QA_USER to the repository $ORG/$qa_repo_name with write permission..."
            gh api -X PUT "repos/$ORG/$qa_repo_name/collaborators/$QA_USER" -f permission=write
        done

        for USER in "${USER_ARRAY[@]}"; do
            echo "Adding $USER to the repository $ORG/$qa_repo_name with read permission..."
            gh api -X PUT "repos/$ORG/$qa_repo_name/collaborators/$USER" -f permission=read
        done
        echo "All users have been added to the QA repository."

        for QA_USER in "${QA_USER_ARRAY[@]}"; do
            echo "Adding $QA_USER to the repository $ORG/$repo_name with read permission..."
            gh api -X PUT "repos/$ORG/$repo_name/collaborators/$QA_USER" -f permission=read
        done
        echo "All users have been added to the main repository."

        # Cloud engineers team slug (URL-friendly version of the team name)
        CLOUD_ENGINEERS_TEAM="joshrichhy"

        # JSON content for branch protection rules
        read -r -d '' PROTECTION_RULES << EOM
{
  "required_status_checks": {
    "strict": true,
    
  },
  "restrictions": {
    "users": [],
    "teams": ["$CLOUD_ENGINEERS_TEAM"],
    "apps": []
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "require_code_owner_reviews": true,
    "dismiss_stale_reviews": true,
    "required_approving_review_count": 1
  },
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
EOM

        # Apply branch protection rules to each branch
        BRANCHES=("main" "dev" "prod-support")
        for branch in "${BRANCHES[@]}"; do
            echo "Applying protection rules to branch: $branch"
            echo "$PROTECTION_RULES" | gh api \
                -X PUT \
                -H "Accept: application/vnd.github.v3+json" \
                "/repos/$ORG/$repo_name/branches/$branch/protection" \
                --input -

            echo "$PROTECTION_RULES" | gh api \
                -X PUT \
                -H "Accept: application/vnd.github.v3+json" \
                "/repos/$ORG/$qa_repo_name/branches/$branch/protection" \
                --input -
        done

        # Set repository permissions for the cloud engineers team
        gh api \
            -X PUT \
            -H "Accept: application/vnd.github.v3+json" \
            "/orgs/$ORG/teams/$CLOUD_ENGINEERS_TEAM/repos/$ORG/$repo_name" \
            -f permission=push

        echo "Branch protection rules applied and team permissions set."
    fi
}

# Prompt for organization, repository name, and team type
read -p "Enter the GitHub organization name: " ORG
read -p "Enter the name of the first repository: " REPO_NAME
echo "Enter Users to add in the first repository (separate with commas):"
read USERS
echo "Enter Users to add in the QA repository (separate with commas):"
read QA_USERS

# GitHub username for organization creation (if needed)
read -p "Enter your GitHub username for organization management: " GITHUB_USERNAME

# Create repositories, set permissions, and create branches
create_repo_with_teams_and_branches "$REPO_NAME"

# Logout from Github
# gh auth logout

# echo "logging out of github..."