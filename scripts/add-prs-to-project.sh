#!/bin/bash

set -euo pipefail

ORG="ironcore-dev"
PROJECT_NAME="Roadmap"

# Check GITHUB_TOKEN
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "❌ Please export GITHUB_TOKEN before running the script."
  exit 1
fi

# Get the Project ID
project_id=$(gh api graphql -f query='
  query($org: String!) {
    organization(login: $org) {
      projectsV2(first: 50) {
        nodes {
          id
          title
        }
      }
    }
  }' -f org="$ORG" --jq ".data.organization.projectsV2.nodes[] | select(.title==\"$PROJECT_NAME\") | .id")

if [[ -z "$project_id" ]]; then
  echo "❌ Project '$PROJECT_NAME' not found in org '$ORG'."
  exit 1
fi

echo "✅ Found project ID: $project_id"

# Get all repos in the org
repos=$(gh repo list "$ORG" --limit 1000 --json name -q '.[].name')

for repo in $repos; do
  echo "📦 Processing repo: $repo"

  endCursor=""
  hasNextPage=true

  while [[ "$hasNextPage" == "true" ]]; do
    if [[ -z "$endCursor" ]]; then
      after_part=""
    else
      after_part=", after: \"$endCursor\""
    fi

    query=$(cat <<EOF
query {
  repository(owner: "$ORG", name: "$repo") {
    pullRequests(first: 50, states: [OPEN, MERGED, CLOSED]$after_part) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        id
        number
        title
        state
        ... on PullRequest {
          merged
        }
        projectItems(first: 100) {
          nodes {
            project {
              id
            }
          }
        }
      }
    }
  }
}
EOF
    )

    response=$(gh api graphql -f query="$query")

    hasNextPage=$(echo "$response" | jq -r '.data.repository.pullRequests.pageInfo.hasNextPage')
    endCursor=$(echo "$response" | jq -r '.data.repository.pullRequests.pageInfo.endCursor // ""')

    prs=$(echo "$response" | jq -c '.data.repository.pullRequests.nodes[]')

    while IFS= read -r pr; do
      pr_id=$(echo "$pr" | jq -r '.id')
      number=$(echo "$pr" | jq -r '.number')
      state=$(echo "$pr" | jq -r '.state')
      merged=$(echo "$pr" | jq -r '.merged')
      existing_project_ids=$(echo "$pr" | jq -r '.projectItems.nodes[].project.id')

      if [[ -z "$pr_id" || -z "$number" ]]; then
        echo "   ⚠️  Skipping malformed or empty PR entry."
        continue
      fi

      if echo "$existing_project_ids" | grep -q "$project_id"; then
        echo "   ✅ Already in project: PR #$number"
        continue
      fi

      echo "   ➕ Adding to project: PR #$number (state: $state, merged: $merged)"

      gh api graphql -f query='
        mutation($projectId: ID!, $contentId: ID!) {
          addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
            item { id }
          }
        }' -f projectId="$project_id" -f contentId="$pr_id" >/dev/null

    done <<< "$prs"


  done
done

echo "🎯 Done: All PRs are now in '$PROJECT_NAME'."
