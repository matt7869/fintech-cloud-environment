# Fintech Cloud Environment

A hands-on Cloud Engineering project focused on building and validating a secure, AWS-compatible environment for a fintech workload.

The project uses **Moto** to simulate AWS services locally. It provides a repeatable lab for configuring S3 storage controls, IAM identities, policies, role trust relationships, and security-audit access through the AWS CLI.

> **Environment notice:** This is a local simulation using Moto. The configurations and test results documented here are not evidence of a deployment to a live AWS account or production environment.

## Project objectives

- Configure an S3 bucket for fintech backup storage.
- Enable S3 bucket versioning.
- Apply default server-side encryption using SSE-S3 (AES256).
- Block public access to the backup bucket.
- Define separate IAM permissions for backup operations and security auditing.
- Configure IAM role trust relationships and test role assumption with AWS STS.
- Automate environment setup using shell scripts and the AWS CLI.

## Architecture overview

The local environment uses the AWS CLI to communicate with a Moto server endpoint.

```text
                 Cloud Engineer
                       |
                       | AWS CLI
                       |
                       v
              +------------------+
              |   Moto Server    |
              | Local AWS API    |
              +------------------+
                       |
             +---------+---------+
             |                   |
             v                   v
      +-------------+     +----------------+
      |     IAM     |     |       S3       |
      |             |     |                |
      | IAM users   |     | fintech-dev-   |
      | IAM roles   |     | backups        |
      | Policies    |     |                |
      | Trust       |     | Versioning     |
      | policies    |     | SSE-S3         |
      +-------------+     | Public access  |
                          | block          |
                          +----------------+

cat > README.md <<'EOF'
# Fintech Cloud Environment

A hands-on Cloud Engineering project focused on building and validating a secure, AWS-compatible environment for a fintech workload.

The project uses **Moto** to simulate AWS services locally. It provides a repeatable lab for configuring S3 storage controls, IAM identities, policies, role trust relationships, and security-audit access through the AWS CLI.

> **Environment notice:** This is a local simulation using Moto. The configurations and test results documented here are not evidence of a deployment to a live AWS account or production environment.

## Project Objectives

- Configure an S3 bucket for fintech backup storage.
- Enable S3 bucket versioning.
- Apply default server-side encryption using SSE-S3 (AES256).
- Block public access to the backup bucket.
- Define separate IAM permissions for backup operations and security auditing.
- Configure IAM role trust relationships and test role assumption with AWS STS.
- Automate environment setup using shell scripts and the AWS CLI.

## Architecture Overview

The local environment uses the AWS CLI to communicate with a Moto server endpoint.

```text
                 Cloud Engineer
                       |
                       | AWS CLI
                       |
                       v
              +------------------+
              |   Moto Server    |
              | Local AWS API    |
              +------------------+
                       |
             +---------+---------+
             |                   |
             v                   v
      +-------------+     +----------------+
      |     IAM     |     |       S3       |
      |             |     |                |
      | IAM users   |     | fintech-dev-   |
      | IAM roles   |     | backups        |
      | Policies    |     |                |
      | Trust       |     | Versioning     |
      | policies    |     | SSE-S3         |
      +-------------+     | Public access  |
                          | block          |
                          +----------------+
```

## Repository Structure

```text
fintech-cloud-environment/
├── .gitignore
├── README.md
├── fintech-auditor-assume-role-policy.json
├── fintech-backup-writer-assume-role-policy.json
├── fintech-backup-writer-policy.json
├── fintech-backup-writer-trust-policy.json
├── fintech-security-audit-policy.json
├── fintech-security-audit-trust-policy.json
└── scripts/
    ├── setup-iam-environment.sh
    └── setup-s3-environment.sh
```

## Technology Stack

- **AWS CLI** — interacting with AWS-compatible APIs.
- **Moto** — local AWS service simulation.
- **AWS IAM** — identity, permission, and role-trust configuration.
- **Amazon S3 API** — bucket configuration and storage security controls.
- **Bash** — environment setup and validation automation.
- **Git and GitHub CLI** — source control and repository publishing.

## S3 Security Configuration

The simulated backup bucket is named:

`fintech-dev-backups`

| Control | Configuration |
|---|---|
| Bucket versioning | Enabled |
| Default encryption | SSE-S3 (AES256) |
| Block public ACLs | Enabled |
| Ignore public ACLs | Enabled |
| Block public bucket policies | Enabled |
| Restrict public buckets | Enabled |

These controls establish a baseline for protecting backup storage in the local environment.

## IAM Security Design

The repository contains separate IAM policy and trust-policy documents for backup-writing and security-audit access.

The security-audit implementation uses:

- IAM user: `fintech-auditor`
- IAM role: `FintechSecurityAuditRole`
- Managed policy: `FintechSecurityAuditPolicy`
- STS action: `sts:AssumeRole`

The audit policy was configured with read-oriented S3 permissions for inspecting:

- Bucket versioning
- Bucket encryption configuration
- Public access block configuration
- Bucket policy

The trust relationship allows the designated auditor identity to assume the audit role.

## Local Environment

The Moto server was run locally at:

`http://127.0.0.1:5000`

Start the Moto server with:

```bash
moto_server -H 0.0.0.0 -p 5000
```

AWS CLI operations for this lab should explicitly target the Moto endpoint:

```bash
--endpoint-url=http://127.0.0.1:5000
```

**Important:** Use test credentials when communicating with the local Moto server. Do not place real AWS access keys, secret keys, or session tokens in this repository.

## Validation and Test Results

The following configurations and operations were verified in the local Moto environment:

| Test | Result |
|---|---|
| S3 bucket versioning | Verified enabled |
| Default S3 encryption | Verified as AES256 |
| S3 public access block | All four settings verified enabled |
| IAM audit policy | Verified present and attached |
| IAM role trust policy | Verified |
| STS role assumption | Successful |
| Assumed-role identity | Returned successfully |

### Permission-Enforcement Limitation

During testing, an S3 `ListObjectsV2` request returned successfully with an empty result, even though the audit policy did not explicitly grant `s3:ListBucket`.

This behavior has not yet been conclusively explained. It may reflect a limitation in the local simulator or its IAM enforcement behavior.

Therefore, least-privilege enforcement has **not** been fully validated. Further testing is required before making production-security claims.

## Production Considerations

A real AWS deployment would require additional design and validation, including:

- Reviewing IAM permissions against the principle of least privilege.
- Validating access-denial behavior in a real AWS account.
- Using IAM Identity Center, federation, or an appropriately designed cross-account role model for external auditors.
- Protecting credentials and avoiding long-lived access keys where possible.
- Enabling and reviewing CloudTrail audit records.
- Testing backup recovery, retention, and disaster-recovery requirements.
- Reviewing encryption, key-management, and account-level security requirements.

## Current Project Status

The local S3 security configuration, IAM audit-role configuration, and STS role-assumption workflow have been implemented and tested.

Further work is required to validate permission-denial behavior and strengthen the environment's production-readiness evidence.

## Disclaimer

This repository is an engineering lab and demonstration project. It uses Moto for local AWS-compatible service simulation. It is not a production deployment, a compliance certification, or a substitute for testing security controls in AWS.

---

**Project Focus:** Cloud Engineering | AWS | IAM | Amazon S3 | Security | Bash Automation
