#!/bin/bash

set -euo pipefail

CATEGORY="${1:-}"
ORG="ironcore-dev"
PROJECT_NAME="Roadmap"

# Define categories and repos
CATEGORIES="metal-automation networking storage compute iaas operatingsystem gardener-extension"
metal_automation_repos="metal-operator cloud-provider-metal cluster-api-provider-ironcore-metal ironcore-image FeDHCP boot-operator ipam metal-token-rotate metal-load-balancer-controller os-images maintenance-operator firmware-operator switch-operator"
networking_repos="metalnet dpservice ironcore-net ebpf-nat64 metalbond"
storage_repos="ceph-provider ironcore-csi-driver"
compute_repos="libvirt-provider cloud-hypervisor-provider"
iaas_repos="ironcore openapi-extractor controller-utils cloud-provider-ironcore vgopath kubectl-ironcore ironcore-in-a-box provider-utils"
operatingsystem_repos="FeOS feos-demo feos-provider"
gardener_extension_repos="gardener-extension-provider-ironcore machine-controller-manager-provider-ironcore-metal gardener-extension-provider-ironcore-metal machine-controller-manager-provider-ironcore machine-controller-manager gardener-extension-os-gardenlinux"

# Get Project ID
get_project_id() {
  gh api graphql -f query='
    query($org: String!) {
      organization(login: $org) {
        projectsV2(first: 50) {
          nodes {
            id
            title
          }
        }
      }
    }' -f org="$ORG" --jq ".data.organization.projectsV2.nodes[] | select(.title==\"$PROJECT_NAME\") | .id"
}

# Fetch field IDs for the project
get_field_ids() {
  gh api graphql -f query='
    query($project: ID!) {
      node(id: $project) {
        ... on ProjectV2 {
          fields(first: 100) {
            nodes {
              __typename
              ... on ProjectV2FieldCommon {
                id
                name
              }
              ... on ProjectV2SingleSelectField {
                options {
                  id
                  name
                }
              }
            }
          }
        }
      }
    }' -f project="$1"
}

# Run enrichment logic per category
run_category() {
  local CATEGORY="$1"
  local repos_var="${CATEGORY//-/_}_repos"
  local REPOS="${!repos_var:-}"

  if [[ -z "$REPOS" ]]; then
    echo "❌ Unknown or unsupported category '$CATEGORY'. Allowed: $CATEGORIES"
    return
  fi

  local project_id
  project_id=$(get_project_id)
  [[ -z "$project_id" ]] && echo "❌ Project '$PROJECT_NAME' not found." && return

  local FIELDS_JSON
  FIELDS_JSON=$(get_field_ids "$project_id")
  local status_field_id done_option_id end_date_field_id
  status_field_id=$(echo "$FIELDS_JSON" | jq -r '.data.node.fields.nodes[] | select(.name == "Status") | .id')
  done_option_id=$(echo "$FIELDS_JSON" | jq -r '.data.node.fields.nodes[] | select(.name == "Status") | .options[]? | select(.name == "Done") | .id')
  end_date_field_id=$(echo "$FIELDS_JSON" | jq -r '.data.node.fields.nodes[] | select(.name == "End date") | .id')

  echo "✅ [$CATEGORY] Project and fields loaded. Enriching..."

  for repo in $REPOS; do
    echo "📦 [$CATEGORY] Repo: $repo"
    endCursor=""
    hasNextPage=true

    while [[ "$hasNextPage" == "true" ]]; do
      after_part=$([[ -z "$endCursor" ]] && echo "" || echo ", after: \"$endCursor\"")
      query=$(cat <<EOF
        query {
          repository(owner: "$ORG", name: "$repo") {
            issues(first: 50, states: [CLOSED]$after_part) {
              pageInfo {
                hasNextPage
                endCursor
              }
              nodes {
                id
                number
                closedAt
                projectItems(first: 100) {
                  nodes {
                    id
                    project { id }
                  }
                }
              }
            }
          }
        }
EOF
      )

      response=$(gh api graphql -f query="$query")
      hasNextPage=$(echo "$response" | jq -r '.data.repository.issues.pageInfo.hasNextPage')
      endCursor=$(echo "$response" | jq -r '.data.repository.issues.pageInfo.endCursor // ""')
      issues=$(echo "$response" | jq -c '.data.repository.issues.nodes[]')

      while IFS= read -r issue; do
        issue_id=$(echo "$issue" | jq -r '.id')
        number=$(echo "$issue" | jq -r '.number')
        closedAt=$(echo "$issue" | jq -r '.closedAt // empty')
        item_id=$(echo "$issue" | jq -r --arg pid "$project_id" '.projectItems.nodes[] | select(.project.id == $pid) | .id' || true)

        if [[ -z "$item_id" ]]; then
          echo "   ⏩ #$number not in project — skipping"
          continue
        fi

        echo "   ✅ #$number → Done @ $closedAt"

        # Status
        gh api graphql -f query='
          mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
            updateProjectV2ItemFieldValue(input: {
              projectId: $projectId,
              itemId: $itemId,
              fieldId: $fieldId,
              value: { singleSelectOptionId: $optionId }
            }) {
              projectV2Item { id }
            }
          }' \
          -f projectId="$project_id" \
          -f itemId="$item_id" \
          -f fieldId="$status_field_id" \
          -f optionId="$done_option_id" >/dev/null

        # End Date
        gh api graphql -f query='
          mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $date: Date!) {
            updateProjectV2ItemFieldValue(input: {
              projectId: $projectId,
              itemId: $itemId,
              fieldId: $fieldId,
              value: { date: $date }
            }) {
              projectV2Item { id }
            }
          }' \
          -f projectId="$project_id" \
          -f itemId="$item_id" \
          -f fieldId="$end_date_field_id" \
          -f date="$closedAt" >/dev/null

      done <<< "$issues"
    done
  done

  echo "🎯 Done enriching closed issues in category: $CATEGORY"
}

# Check token
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "❌ Please export GITHUB_TOKEN before running."
  exit 1
fi

# Handle all or single
if [[ "$CATEGORY" == "all" ]]; then
  echo "🚀 Running all categories in parallel..."
  for cat in $CATEGORIES; do
    run_category "$cat" &
  done
  wait
  echo "✅ All categories done."
else
  run_category "$CATEGORY"
fi