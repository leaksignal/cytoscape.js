#!/bin/bash

# Make script exit on first failure
set -e

# Check if VERSION variable is set
if [ -z "$VERSION" ]; then
  echo "VERSION variable is not set."
  return 1;
else
  echo "VERSION is set to: $VERSION"
fi

# Check if NEXT_VERSION variable is set
if [ -z "$NEXT_VERSION" ]; then
  echo "NEXT_VERSION variable is not set."
  return 1;
else
  echo "NEXT_VERSION is set to: $VERSION"
fi

# Check if NEXT_BACK_PORT_VERSION variable is set
if [ -z "$NEXT_BACK_PORT_VERSION" ]; then
  echo "NEXT_BACK_PORT_VERSION variable is not set."
  return 1;
else
  echo "NEXT_BACK_PORT_VERSION is set to: $NEXT_BACK_PORT_VERSION"
fi


# See current branch
echo "# Current Branch: $(git branch --show-current)"

# See head of current branch
echo "# Current Head: "
git log -n 1

# See current origin
echo "# See remotes: "
git remote -v

# Set git configs
git config --global user.name "${GITHUB_ACTOR}"
git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"

# Check if the branch exists
if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
  exit 1
else
  echo "Branch '$branch_name' does not exist."
fi

git checkout -b $NEXT_BACK_PORT_VERSION
git push -f origin $NEXT_BACK_PORT_VERSION

# Step 2: Make sure local unstable is up-to-date
git checkout unstable
git pull

# Check if current Git branch is named "unstable"
current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)

if [ "$current_branch" = "unstable" ]; then
  echo "Current Git branch is unstable."
else
  echo "Current Git branch is not unstable."
  return 2;
fi

jq --arg ver "$VERSION" '.versions += [$ver]' ./documentation/versions.json >> /tmp/temp.json
mv /tmp/temp.json ./documentation/versions.json

git add documentation/versions.json
git commit -m "Documentation $VERSION: Append $VERSION to versions.json"

# Step 3: Create a merge commit and push it
git merge -s ours master -m "Merge master to unstable"
echo "# Master merged to unstable"
git push
echo "# Unstable pushed to remote"


# Step 4: Fast-forward master to the merge commit
git checkout master
git merge unstable
echo "# unstable merged in master"

git push
echo "# Unstable pushed to remote"

# Update package.json
jq --arg ver "$VERSION" '.version = $ver' package.json >> /tmp/temp.json
mv /tmp/temp.json package.json

# Update package-lock.json
jq --arg ver "$VERSION" '.version = $ver' package-lock.json >> /tmp/temp.json
mv /tmp/temp.json package-lock.json


# Check if version is updated in package.json
version_check_package=$(jq -r '.version' package.json)
if [ -z "$version_check_package" ]; then
  echo "# Failed to update version in package.json"
  return 3
else
  echo "# Version updated in package.json"
fi

# Check if version is updated in package-lock.json
version_check_package_lock=$(jq -r '.version' package-lock.json)
if [ -z "$version_check_package_lock" ]; then
  echo "# Failed to update version in package-lock.json"
  return 4
else
  echo "# Version updated in package-lock.json"
fi

# Commit and push the updated version files
git add package.json package-lock.json
git commit -m "Update version to $VERSION"
git push


# Update new to new version in unstable
git checkout unstable

# Update package.json
jq --arg ver "$NEXT_VERSION" '.version = $ver' package.json >> /tmp/temp.json
mv /tmp/temp.json package.json

# Update package-lock.json
jq --arg ver "$NEXT_VERSION" '.version = $ver' package-lock.json >> /tmp/temp.json
mv /tmp/temp.json package-lock.json


# Check if version is updated in package.json
version_check_package_unstable=$(jq -r '.version' package.json)
if [ -z "$version_check_package_unstable" ]; then
  echo "# Failed to update version in package.json for unstable"
  return 3
else
  echo "# Version updated in package.json for unstable"
fi

# Check if version is updated in package-lock.json
version_check_package_lock_unstable=$(jq -r '.version' package-lock.json)
if [ -z "$version_check_package_lock_unstable" ]; then
  echo "# Failed to update version in package-lock.json for unstable"
  return 4
else
  echo "# Version updated in package-lock.json for unstable"
fi

# Commit and push the updated version files
git add package.json package-lock.json
git commit -m "Update version to $NEXT_VERSION"
git push

git checkout master
