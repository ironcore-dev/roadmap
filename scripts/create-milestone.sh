#!/bin/bash

# === CONFIGURATION ===
ORG_NAME="ironcore-dev"
MILESTONE_TITLE="H2/2025"
MILESTONE_DUE_DATE="2025-12-31"

# === GET ALL REPOS IN THE ORG ===
REPOS=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
  "https://api.github.com/orgs/${ORG_NAME}/repos?per_page=100" | jq -r '.[].full_name')

for REPO in $REPOS; do
  echo "🔍 Checking $REPO..."

  # Check if milestone already exists
  EXISTS=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${REPO}/milestones" | jq -r ".[] | select(.title==\"$MILESTONE_TITLE\") | .title")

  if [ "$EXISTS" == "$MILESTONE_TITLE" ]; then
    echo "⚠️  Milestone '$MILESTONE_TITLE' already exists in $REPO. Skipping."
    continue
  fi

  # Create milestone
  curl -s -X POST "https://api.github.com/repos/${REPO}/milestones" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    -d "{\"title\":\"${MILESTONE_TITLE}\", \"due_on\":\"${MILESTONE_DUE_DATE}T23:59:59Z\"}" \
    | jq '.title, .message'

  echo "✅ Milestone added to $REPO."
done