#!/bin/bash

set -euo pipefail

# === CONFIGURATION ===
: "${GITHUB_TOKEN:?❌ Please export GITHUB_TOKEN before running.}"
ORG_NAME="ironcore-dev"

# === LABELS TO ADD ===
declare -A LABELS
LABELS["area/clusterapi-extension-metal"]="ClusterAPI extension for MetalAPI"
LABELS["area/compute"]="Compute and virtualization specific issues and enhancements."
LABELS["area/documentation"]="Documentation updates and fixes."
LABELS["area/gardener-extension"]="Gardener extension integration."
LABELS["area/iaas"]="Issues related to IronCore IaaS development."
LABELS["area/ironcore-api"]="Ironcore API related tasks and improvements."
LABELS["area/metal-automation"]="Automation processes within the Metal project."
LABELS["area/networking"]="Networking-related tasks and improvements."
LABELS["area/operatingsystem"]="Operating system-related concerns."
LABELS["area/product"]="Ironcore delivered as a product."
LABELS["area/security"]="Security and compliance-related topics."
LABELS["area/storage"]="Storage solutions and related concerns."
LABELS["area/ui"]="Related to UI, Dashboard etc."
LABELS["area/website"]="Website-related issues and improvements."

LABEL_COLOR="0052CC"  # GitHub blue

# === FETCH REPOS ===
REPOS=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
  "https://api.github.com/orgs/${ORG_NAME}/repos?per_page=100" | jq -r '.[].full_name')

# === APPLY LABELS TO EACH REPO ===
for REPO in $REPOS; do
  echo "📁 Working on $REPO..."

  for LABEL in "${!LABELS[@]}"; do
    DESC="${LABELS[$LABEL]}"

    # Check if label exists
    EXISTS=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
      "https://api.github.com/repos/${REPO}/labels" | jq -r ".[] | select(.name==\"$LABEL\") | .name")

    if [ "$EXISTS" == "$LABEL" ]; then
      echo "  ⚠️  Label '$LABEL' already exists. Skipping."
    else
      # Create label
      curl -s -X POST "https://api.github.com/repos/${REPO}/labels" \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "{\"name\":\"${LABEL}\", \"color\":\"${LABEL_COLOR}\", \"description\":\"${DESC}\"}" \
        > /dev/null

      echo "  ✅ Created label '$LABEL'"
    fi
  done

  echo
done

