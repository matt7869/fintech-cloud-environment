#!/bin/bash

# Fintech Dev S3 Environment Automation
# Purpose: Recreate and configure the local Moto S3 environment
# Bucket: fintech-dev-backups

set -euo pipefail
# S3 environment configuration
BUCKET_NAME="fintech-dev-backups"
AWS_REGION="us-east-1"
MOTO_ENDPOINT="http://127.0.0.1:5000"

# Local Moto test credentials
export AWS_ACCESS_KEY_ID="testing"
export AWS_SECRET_ACCESS_KEY="testing"
export AWS_DEFAULT_REGION="$AWS_REGION"

if ! curl -s --fail "$MOTO_ENDPOINT" > /dev/null; then
    echo "ERROR: Moto server is not reachable."
    echo "Start Moto before running this script."
    exit 1
fi

echo "Moto server is reachable."
# Check whether the S3 bucket already exists
echo "Checking S3 bucket..."

if aws s3api head-bucket \
    --bucket "$BUCKET_NAME" \
    --endpoint-url="$MOTO_ENDPOINT" \
    --region "$AWS_REGION" 2>/dev/null; then

    echo "Bucket already exists: $BUCKET_NAME"

else
    echo "Bucket not found. Creating it..."

    aws s3 mb "s3://$BUCKET_NAME" \
        --endpoint-url="$MOTO_ENDPOINT" \
        --region "$AWS_REGION"

    echo "Bucket created: $BUCKET_NAME"
fi
# Enable S3 bucket versioning
echo "Enabling bucket versioning..."

aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --endpoint-url="$MOTO_ENDPOINT" \
    --region "$AWS_REGION"


# Configure S3 Block Public Access
echo "Configuring S3 Block Public Access..."

aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true' \
    --endpoint-url="$MOTO_ENDPOINT" \
    --region "$AWS_REGION"

echo "S3 Block Public Access configured."
    # Configure default S3 encryption
echo "Configuring default bucket encryption..."

aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
    --endpoint-url="$MOTO_ENDPOINT" \
    --region "$AWS_REGION"

echo "Default SSE-S3 encryption configured."
# Verify bucket versioning
echo "Verifying bucket versioning..."

VERSIONING_STATUS=$(aws s3api get-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --query 'Status' \
    --output text \
    --endpoint-url="$MOTO_ENDPOINT")

if [[ "$VERSIONING_STATUS" == "Enabled" ]]; then
    echo "SUCCESS: Bucket versioning is enabled."
else
    echo "ERROR: Bucket versioning verification failed."
    exit 1
fi
# Verify S3 Block Public Access
echo "Verifying S3 Block Public Access..."

PUBLIC_ACCESS=$(aws s3api get-public-access-block \
    --bucket "$BUCKET_NAME" \
    --query 'PublicAccessBlockConfiguration' \
    --output json \
    --endpoint-url="$MOTO_ENDPOINT")

if [[ "$PUBLIC_ACCESS" == *'"BlockPublicAcls": true'* ]] && \
   [[ "$PUBLIC_ACCESS" == *'"IgnorePublicAcls": true'* ]] && \
   [[ "$PUBLIC_ACCESS" == *'"BlockPublicPolicy": true'* ]] && \
   [[ "$PUBLIC_ACCESS" == *'"RestrictPublicBuckets": true'* ]]; then

    echo "SUCCESS: All Block Public Access protections are enabled."
else
    echo "ERROR: Block Public Access verification failed."
    exit 1
fi
# Verify default bucket encryption
echo "Verifying default bucket encryption..."

ENCRYPTION_ALGORITHM=$(aws s3api get-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
    --output text \
    --endpoint-url="$MOTO_ENDPOINT" \
    --region "$AWS_REGION")

if [[ "$ENCRYPTION_ALGORITHM" == "AES256" ]]; then
    echo "SUCCESS: Default SSE-S3 encryption is enabled."
else
    echo "ERROR: Encryption verification failed."
    exit 1
fi
