#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$(dirname "$ANSIBLE_DIR")/terraform"
INVENTORY_FILE="$ANSIBLE_DIR/inventory.ini"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/iac-project}"
SSH_PORT="${SSH_PORT:-22}"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required (sudo apt install jq)"; exit 1; }

echo "Reading Terraform outputs from $TERRAFORM_DIR ..."
IPS=$(terraform -chdir="$TERRAFORM_DIR" output -json web_public_ips | jq -r '.[]')

if [[ -z "$IPS" ]]; then
  echo "ERROR: no public IPs found. Has terraform apply been run?"
  exit 1
fi

{
  echo "# GENERATED FILE - do not edit by hand."
  echo "# Regenerate with: ./scripts/generate_inventory.sh"
  echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "[web]"
  i=1
  while read -r ip; do
    echo "web-${i} ansible_host=${ip}"
    i=$((i + 1))
  done <<< "$IPS"
  echo
  echo "[web:vars]"
  echo "ansible_user=ubuntu"
  echo "ansible_ssh_private_key_file=${SSH_KEY}"
  echo "ansible_port=${SSH_PORT}"
  echo "ansible_python_interpreter=/usr/bin/python3"
} > "$INVENTORY_FILE"

echo "Wrote $INVENTORY_FILE:"
cat "$INVENTORY_FILE"
