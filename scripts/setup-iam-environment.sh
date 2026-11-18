
#!/bin/bash

# Fintech Cloud Environment
# IAM Resource Deployment Script
# Target: Local Moto AWS Simulator

set -Eeuo pipefail

# -----------------------------
# Configuration
# -----------------------------

PROJECT_DIR="$HOME/fintech-cloud-environment"
MOTO_ENDPOINT="http://127.0.0.1:5000"
ACCOUNT_ID="123456789012"

export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Resource names
WRITER_USER="moto"
WRITER_POLICY="FintechBackupWriterPolicy"
WRITER_ROLE="FintechBackupWriterRole"
WRITER_ASSUME_POLICY="FintechBackupWriterAssumeRolePolicy"

AUDITOR_USER="fintech-auditor"
AUDIT_POLICY="FintechSecurityAuditPolicy"
AUDIT_ROLE="FintechSecurityAuditRole"
AUDITOR_ASSUME_POLICY="FintechAuditorAssumeRolePolicy"

# Policy ARNs
WRITER_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${WRITER_POLICY}"
WRITER_ASSUME_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${WRITER_ASSUME_POLICY}"
AUDIT_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${AUDIT_POLICY}"
AUDITOR_ASSUME_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${AUDITOR_ASSUME_POLICY}"

# -----------------------------
# AWS CLI wrapper
# -----------------------------

aws_moto() {
    aws "$@" --endpoint-url="$MOTO_ENDPOINT"
}

# -----------------------------
# Error handling
# -----------------------------

trap 'echo "[ERROR] Deployment failed at line ${LINENO}" >&2' ERR

# -----------------------------
# Pre-deployment checks
# -----------------------------

echo "======================================"
echo "FINTECH IAM ENVIRONMENT DEPLOYMENT"
echo "======================================"

echo "[CHECK] Checking required policy files..."

required_files=(
    fintech-backup-writer-policy.json
    fintech-backup-writer-trust-policy.json
    fintech-backup-writer-assume-role-policy.json
    fintech-security-audit-policy.json
    fintech-security-audit-trust-policy.json
    fintech-auditor-assume-role-policy.json
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$PROJECT_DIR/$file" ]]; then
        echo "[ERROR] Missing file: $file"
        exit 1
    fi
done

echo "[CHECK] Checking Moto connectivity..."

aws_moto iam list-users --output json >/dev/null

echo "[SUCCESS] Moto is responding."

# -----------------------------
# Create IAM users
# -----------------------------

ensure_user() {
    local user_name="$1"

    if aws_moto iam get-user \
        --user-name "$user_name" >/dev/null 2>&1; then

        echo "[EXISTS] IAM user: $user_name"

    else
        aws_moto iam create-user \
            --user-name "$user_name" >/dev/null

        echo "[CREATED] IAM user: $user_name"
    fi
}

echo
echo "Creating IAM users..."

ensure_user "$WRITER_USER"
ensure_user "$AUDITOR_USER"

# -----------------------------
# Create managed policies
# -----------------------------

ensure_policy() {
    local policy_name="$1"
    local policy_file="$2"
    local policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${policy_name}"

    if aws_moto iam get-policy \
        --policy-arn "$policy_arn" >/dev/null 2>&1; then

        echo "[EXISTS] IAM policy: $policy_name"

    else
        aws_moto iam create-policy \
            --policy-name "$policy_name" \
            --policy-document "file://${PROJECT_DIR}/${policy_file}" \
            >/dev/null

        echo "[CREATED] IAM policy: $policy_name"
    fi
}

echo
echo "Creating managed policies..."

ensure_policy "$WRITER_POLICY" \
    "fintech-backup-writer-policy.json"

ensure_policy "$WRITER_ASSUME_POLICY" \
    "fintech-backup-writer-assume-role-policy.json"

ensure_policy "$AUDIT_POLICY" \
    "fintech-security-audit-policy.json"

ensure_policy "$AUDITOR_ASSUME_POLICY" \
    "fintech-auditor-assume-role-policy.json"

# -----------------------------
# Create IAM roles
# -----------------------------

ensure_role() {
    local role_name="$1"
    local trust_file="$2"

    if aws_moto iam get-role \
        --role-name "$role_name" >/dev/null 2>&1; then

        aws_moto iam update-assume-role-policy \
            --role-name "$role_name" \
            --policy-document "file://${PROJECT_DIR}/${trust_file}"

        echo "[UPDATED] Trust policy: $role_name"

    else
        aws_moto iam create-role \
            --role-name "$role_name" \
            --assume-role-policy-document "file://${PROJECT_DIR}/${trust_file}" \
            --max-session-duration 3600 >/dev/null

        echo "[CREATED] IAM role: $role_name"
    fi
}

echo
echo "Creating IAM roles..."

ensure_role "$WRITER_ROLE" \
    "fintech-backup-writer-trust-policy.json"

ensure_role "$AUDIT_ROLE" \
    "fintech-security-audit-trust-policy.json"

# -----------------------------
# Attach policies to roles
# -----------------------------

ensure_role_policy() {
    local role_name="$1"
    local policy_arn="$2"

    local attached_count

    attached_count=$(aws_moto iam list-attached-role-policies \
        --role-name "$role_name" \
        --query "length(AttachedPolicies[?PolicyArn=='${policy_arn}'])" \
        --output text)

    if [[ "$attached_count" == "0" ]]; then

        aws_moto iam attach-role-policy \
            --role-name "$role_name" \
            --policy-arn "$policy_arn"

        echo "[ATTACHED] $policy_arn -> $role_name"

    else
        echo "[EXISTS] Policy already attached to $role_name"
    fi
}

echo
echo "Attaching role permissions..."

ensure_role_policy "$WRITER_ROLE" "$WRITER_POLICY_ARN"
ensure_role_policy "$AUDIT_ROLE" "$AUDIT_POLICY_ARN"

# -----------------------------
# Attach AssumeRole policies to users
# -----------------------------

ensure_user_policy() {
    local user_name="$1"
    local policy_arn="$2"

    local attached_count

    attached_count=$(aws_moto iam list-attached-user-policies \
        --user-name "$user_name" \
        --query "length(AttachedPolicies[?PolicyArn=='${policy_arn}'])" \
        --output text)

    if [[ "$attached_count" == "0" ]]; then

        aws_moto iam attach-user-policy \
            --user-name "$user_name" \
            --policy-arn "$policy_arn"

        echo "[ATTACHED] $policy_arn -> $user_name"

    else
        echo "[EXISTS] AssumeRole policy already attached to $user_name"
    fi
}

echo
echo "Attaching AssumeRole permissions..."

ensure_user_policy "$WRITER_USER" "$WRITER_ASSUME_ARN"
ensure_user_policy "$AUDITOR_USER" "$AUDITOR_ASSUME_ARN"

# -----------------------------
# Deployment summary
# -----------------------------

echo
echo "======================================"
echo "IAM DEPLOYMENT COMPLETED"
echo "======================================"

echo "IAM users:"
aws_moto iam list-users \
    --query "Users[].UserName" \
    --output table

echo "IAM roles:"
aws_moto iam list-roles \
    --query "Roles[].RoleName" \
    --output table

echo
echo "Deployment finished."

