#!/usr/bin/env bash
# Runs $SCRIPT in the cluster through AKS run command, next to $MANIFEST as manifest.yaml, and fails
# unless it prints BOOTSTRAP_OK: the CLI exits 0 even when the remote command fails.
#
# Retried as a whole: the role assignments that let whoever runs Terraform into the cluster take
# minutes to propagate, and the remote scripts are idempotent.
set -euo pipefail

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
printf '%s' "$SCRIPT" > "$dir/run.sh"
printf '%s' "$MANIFEST" > "$dir/manifest.yaml"
cd "$dir"

for attempt in $(seq 10); do
  echo "Run command on $CLUSTER_NAME, attempt $attempt"
  if logs=$(az aks command invoke --subscription "$SUBSCRIPTION_ID" --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" --command "bash run.sh" --file . --query logs --output tsv 2>&1); then
    printf '%s\n' "$logs"
    if grep -q '^BOOTSTRAP_OK' <<<"$logs"; then
      exit 0
    fi
  else
    printf '%s\n' "$logs" >&2
  fi
  sleep 30
done
echo "Run command on $CLUSTER_NAME failed after $attempt attempts" >&2
exit 1
