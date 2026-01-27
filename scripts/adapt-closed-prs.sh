#!/bin/bash

set -euo pipefail

CATEGORY="${1:-}"
ORG="ironcore-dev"
PROJECT_NAME="Roadmap"
MONTHS_BACK=2

# Define categories and repos
CATEGORIES="metal-automation networking storage compute iaas operatingsystem gardener-extension"
metal_automation_repos="metal-operator cloud-provider-metal cluster-api-provider-ironcore-metal ironcore-image FeDHCP boot-operator ipam metal-token-rotate metal-load-balancer-controller os-images maintenance-operator firmware-operator"
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
  cutoff_date=$(python - <<PY
from datetime import datetime
def months_ago(dt, months):
    y, m = dt.year, dt.month - months
    while m <= 0:
        y -= 1
        m += 12
    d = min(dt.day, [31, 29 if (y%4==0 and (y%100!=0 or y%400==0)) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m-1])
    return dt.replace(year=y, month=m, day=d)
print(months_ago(datetime.utcnow(), $MONTHS_BACK).date().isoformat())
PY
)

  echo "✅ [$CATEGORY] Project and fields loaded. Enriching closed PRs (last $MONTHS_BACK months, since $cutoff_date)..."

  for repo in $REPOS; do
    echo "📦 [$CATEGORY] Repo: $repo"
    endCursor=""
    hasNextPage=true

    while [[ "$hasNextPage" == "true" ]]; do
      after_part=$([[ -z "$endCursor" ]] && echo "" || echo ", after: \"$endCursor\"")
      search_query="repo:$ORG/$repo is:pr is:closed closed:>=$cutoff_date"
      query=$(cat <<EOF
        query {
          search(query: "$search_query", type: ISSUE, first: 50$after_part) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              ... on PullRequest {
                id
                number
                closedAt
                projectItems(first: 100) {
                  nodes {
                    id
                    project { id }
                    fieldValues(first: 20) {
                      nodes {
                        __typename
                        ... on ProjectV2ItemFieldSingleSelectValue {
                          field { ... on ProjectV2FieldCommon { name } }
                          optionId
                        }
                        ... on ProjectV2ItemFieldDateValue {
                          field { ... on ProjectV2FieldCommon { name } }
                          date
                        }
                      }
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
      hasNextPage=$(echo "$response" | jq -r '.data.search.pageInfo.hasNextPage')
      endCursor=$(echo "$response" | jq -r '.data.search.pageInfo.endCursor // ""')
      prs=$(echo "$response" | jq -c '.data.search.nodes[]')

      while IFS= read -r pr; do
        pr_id=$(echo "$pr" | jq -r '.id')
        number=$(echo "$pr" | jq -r '.number')
        closedAt=$(echo "$pr" | jq -r '.closedAt // empty')
        item_json=$(echo "$pr" | jq -c --arg pid "$project_id" '.projectItems.nodes[] | select(.project.id == $pid)' || true)
        item_id=$(echo "$item_json" | jq -r '.id' || true)

        if [[ -z "$item_id" ]]; then
          echo "   ⏩ PR #$number not in project — skipping"
          continue
        fi

        status_option_id=$(echo "$item_json" | jq -r '.fieldValues.nodes[] | select(.field.name == "Status") | .optionId // empty' | head -n1)
        end_date_value=$(echo "$item_json" | jq -r '.fieldValues.nodes[] | select(.field.name == "End date") | .date // empty' | head -n1)

        if [[ "$status_option_id" == "$done_option_id" && -n "$end_date_value" ]]; then
          echo "   ✅ PR #$number already Done with End date — skipping"
          continue
        fi

        echo "   ✅ PR #$number → Done @ $closedAt"

        # Set Status = Done
        if [[ "$status_option_id" != "$done_option_id" ]]; then
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
        fi

        # Set End Date
        if [[ -z "$end_date_value" ]]; then
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
        fi

      done <<< "$prs"
    done
  done

  echo "🎯 Done enriching closed PRs in category: $CATEGORY"
}

# Check token
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "❌ Please export GITHUB_TOKEN before running."
  exit 1
fi

# Handle all / all-odd-even / single category
if [[ "$CATEGORY" == "all" ]]; then
  echo "🚀 Running all categories in parallel..."
  for cat in $CATEGORIES; do
    run_category "$cat" &
  done
  wait
  echo "✅ All categories done."

elif [[ "$CATEGORY" == "all-odd-even" ]]; then
  day=$(date +%d)
  mod=$((10#$day % 2))  # Remove leading zeroes, get 0 or 1

  # Split CATEGORIES into odd/even index groups
  echo "📆 Running in odd-even mode (Day $day → ${mod:-even}-indexed categories)"
  idx=0
  for cat in $CATEGORIES; do
    if [[ $((idx % 2)) -eq $mod ]]; then
      run_category "$cat" &
    fi
    idx=$((idx + 1))
  done
  wait
  echo "✅ Odd-even run completed."

else
  run_category "$CATEGORY"
fi
