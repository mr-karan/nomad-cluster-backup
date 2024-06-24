#!/bin/bash
set -eo pipefail

# This script is used to backup Nomad variables and cluster state by fetching them and uploading them to an S3 bucket.

# Set the S3 bucket name from environment variable
S3_BUCKET_NAME="${NOMAD_BACKUP_S3_BUCKET:-}"

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >&2
}

if [ -z "$S3_BUCKET_NAME" ]; then
    log ERROR "S3_BUCKET_NAME is not set. Please set the NOMAD_BACKUP_S3_BUCKET environment variable."
    exit 1
fi

# Function to check if the input is valid JSON
check_json_validity() {
    if ! jq empty > /dev/null 2>&1 <<< "$1"; then
        log ERROR "Invalid JSON input."
        return 1
    fi
}

# Function to upload file to S3
upload_to_s3() {
    local source_file="$1"
    local destination_path="$2"

    if aws s3 cp "$source_file" "s3://$S3_BUCKET_NAME$destination_path"; then
        log INFO "Successfully uploaded $source_file to s3://$S3_BUCKET_NAME$destination_path"
    else
        log ERROR "Failed to upload $source_file to s3://$S3_BUCKET_NAME$destination_path"
        return 1
    fi
}

# Backup Nomad variables
# Backup Nomad variables
backup_nomad_vars() {
    local nomad_vars_json
    nomad_vars_json=$(nomad var list -out=json -namespace="*") || { log ERROR "Failed to fetch Nomad variables"; return 1; }

    if ! check_json_validity "$nomad_vars_json"; then
        log ERROR "Invalid JSON from nomad var list command"
        return 1
    fi

    echo "$nomad_vars_json" | jq -c '.[]' | while IFS= read -r item; do
        local namespace var_path secrets_json
        namespace=$(jq -r '.Namespace' <<< "$item")
        var_path=$(jq -r '.Path' <<< "$item")

        secrets_json=$(nomad var get -namespace="$namespace" -out=json "$var_path") || { log ERROR "Failed to fetch secrets for Namespace: $namespace, Path: $var_path"; continue; }

        if ! check_json_validity "$secrets_json"; then
            log ERROR "Invalid JSON from nomad var get command for Namespace: $namespace, Path: $var_path"
            continue
        fi

        local temp_file="$TEMP_DIR/vars_${namespace}_${var_path//\//_}.json"
        echo "$secrets_json" > "$temp_file"

        log INFO "Uploading secrets for Namespace: $namespace, Path: $var_path"
        upload_to_s3 "$temp_file" "/vars/${namespace}/${var_path#/}" || continue
    done
}

# Backup Nomad cluster state
backup_cluster_state() {
    local snapshot_file="$TEMP_DIR/backup.snap"
    local state_file="$TEMP_DIR/state.json"

    if ! nomad operator snapshot save -stale "$snapshot_file"; then
        log ERROR "Failed to save Nomad snapshot"
        return 1
    fi

    if ! nomad operator snapshot state "$snapshot_file" > "$state_file"; then
        log ERROR "Failed to extract state from Nomad snapshot"
        return 1
    fi

    log INFO "Uploading Nomad cluster state"
    upload_to_s3 "$state_file" "/cluster/state.json" || return 1
}

# Main execution
main() {
    log INFO "Starting Nomad backup process..."

    if ! backup_nomad_vars; then
        log ERROR "Failed to backup Nomad variables"
    fi

    if ! backup_cluster_state; then
        log ERROR "Failed to backup Nomad cluster state"
    fi

    log INFO "Nomad backup process completed."
}

main