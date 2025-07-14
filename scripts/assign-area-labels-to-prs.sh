#!/bin/bash

set -euo pipefail

CATEGORY="${1:-}"
ORG="ironcore-dev"
MAX_JOBS="${MAX_JOBS:-5}"

# Define categories and labels
CATEGORIES="metal-automation networking storage compute iaas operatingsystem gardener-extension"
LABELS="area/metal-automation area/networking area/storage area/compute area/iaas area/operatingsystem area/gardener-extension"

metal_automation_repos="metal-operator cloud-provider-metal cluster-api-provider-ironcore-metal ironcore-image FeDHCP boot-operator ipam metal-token-rotate metal-load-balancer-controller os-images maintenance-operator firmware-operator network-operator"
networking_repos="metalnet dpservice ironcore-net ebpf-nat64 metalbond"
storage_repos="ceph-provider ironcore-csi-driver"
compute_repos="libvirt-provider cloud-hypervisor-provider"
iaas_repos="ironcore openapi-extractor controller-utils cloud-provider-ironcore vgopath kubectl-ironcore ironcore-in-a-box provider-utils ironcore-csi-driver"
operatingsystem_repos="FeOS feos-demo feos-provider"
gardener_extension_repos="gardener-extension-provider-ironcore machine-controller-manager-provider-ironcore-metal gardener-extension-provider-ironcore-metal machine-controller-manager-provider-ironcore machine-controller-manager gardener-extension-os-gardenlinux"

run_limited_parallel() {
  local max_jobs=$1
  shift
  local cmds=("$@")
  local pids=()

  for cmd in "${cmds[@]}"; do
    eval "$cmd" &
    pids+=($!)

    while (( $(jobs -r | wc -l) >= max_jobs )); do
      sleep 0.5
    done
  done

  wait "${pids[@]}"
}

process_category() {
  local category="$1"
  local label
  local repos_var
  local repos
  local cmds=()

  # Find label
  i=1
  for cat in $CATEGORIES; do
    if [[ "$cat" == "$category" ]]; then
      label=$(echo "$LABELS" | cut -d' ' -f"$i")
      break
    fi
    i=$((i+1))
  done

  if [[ -z "${label:-}" ]]; then
    echo "❌ Unknown category '$category'"
    return
  fi

  repos_var="${category//-/_}_repos"
  repos="${!repos_var}"

  echo "✅ Category: $category"
  echo "🏷️  Label to apply: $label"
  echo "📦 Repos: $repos"
  echo

  for repo in $repos; do
    full_repo="$ORG/$repo"
    cmds+=("process_repo_prs '$full_repo' '$label'")
  done

  run_limited_parallel "$MAX_JOBS" "${cmds[@]}"
}

process_repo_prs() {
  local full_repo="$1"
  local label="$2"

  echo "🔍 Processing PRs in repo: $full_repo"

  PRS=$(gh pr list -R "$full_repo" --state all --limit 1500 --json number,labels \
    --jq '.[] | [.number, (.labels | map(.name) | join(","))] | @tsv' || true)

  if [[ -z "$PRS" ]]; then
    echo "   ⚠️  No PRs found in $full_repo"
    return
  fi

  while IFS=$'\t' read -r pr_number existing_labels; do
    if [[ ",$existing_labels," == *",$label,"* ]]; then
      echo "   ⚠️  PR #$pr_number already has label '$label', skipping."
    else
      echo "   ➕ Adding label '$label' to PR #$pr_number"
      gh pr edit "$pr_number" -R "$full_repo" --add-label "$label" || echo "   ❌ Failed to label PR #$pr_number"
    fi
  done <<< "$PRS"
}

# Handle "all" case
if [[ "$CATEGORY" == "all" ]]; then
  for cat in $CATEGORIES; do
    process_category "$cat"
  done
else
  process_category "$CATEGORY"
fi

echo "🎉 PR labeling complete."
