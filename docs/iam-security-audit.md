# IAM Security Audit — Fintech Cloud Environment

## 1. Overview

This document records the implementation and validation of an IAM-based security-audit access model for the Fintech Cloud Environment project.

The objective was to provide a dedicated auditor identity with controlled, read-oriented access to selected S3 security configurations without granting unrestricted access to the environment.

The implementation and tests were performed locally using Moto, an AWS service simulator.

> **Environment:** Local Moto simulation. This report does not represent a production AWS deployment or a formal security certification.

## 2. Security Objectives

The implementation focused on the following objectives:

- Separate security-audit access from backup-writing access.
- Define an IAM role specifically for security auditing.
- Use a trust policy to control which identity can assume the role.
- Grant selected S3 inspection permissions through an IAM policy.
- Use AWS STS to test role assumption.
- Verify the configured S3 security controls through the assumed role.

## 3. IAM Architecture

The audit access model consists of three main components:

| Component | Name |
|---|---|
| IAM user | `fintech-auditor` |
| IAM role | `FintechSecurityAuditRole` |
| Managed policy | `FintechSecurityAuditPolicy` |

The intended access flow is:

```text
             Security Auditor
                    |
                    |
                    v
          IAM User: fintech-auditor
                    |
                    |
                    | sts:AssumeRole
                    v
          FintechSecurityAuditRole
                    |
                    |
                    v
          FintechSecurityAuditPolicy
                    |
                    |
                    v
              Amazon S3
                    |
          +---------+----------+
          |         |          |
          v         v          v
       Version   Encryption  Public Access
       Status    Settings      Block
```

The auditor assumes the dedicated IAM role and uses the resulting temporary role session to perform the configured audit operations.

## 4. Trust Policy Configuration

The role trust policy identifies the principal allowed to assume the audit role.

The configured principal was:

`arn:aws:iam::123456789012:user/fintech-auditor`

The permitted STS action was:

`sts:AssumeRole`

The maximum session duration was configured as 3,600 seconds.

The trust policy is maintained in:

`fintech-security-audit-trust-policy.json`

This separates the question of who can assume the role from the question of what permissions the role receives.

## 5. Audit Permissions

The managed policy was configured with the following S3 inspection actions:

| IAM action | Purpose |
|---|---|
| `s3:GetBucketVersioning` | Inspect bucket versioning configuration |
| `s3:GetEncryptionConfiguration` | Inspect default bucket encryption |
| `s3:GetBucketPublicAccessBlock` | Inspect public-access-block settings |
| `s3:GetBucketPolicy` | Retrieve the bucket policy |

The configured resource was:

`arn:aws:s3:::fintech-dev-backups`

The policy document is maintained in:

`fintech-security-audit-policy.json`

The intention is to provide the auditor with access to selected bucket security information rather than general backup-management permissions.

## 6. STS Role-Assumption Validation

The role-assumption workflow was tested using AWS STS against the local Moto endpoint.

The role assumption completed successfully.

The returned assumed-role identity was:

`arn:aws:sts::123456789012:assumed-role/FintechSecurityAuditRole/FintechAuditSession2`

This confirmed that the configured role could be assumed by the designated auditor identity in the simulated environment.

## 7. S3 Security Verification

The audit workflow was used to inspect the following bucket:

`fintech-dev-backups`

The following configurations were verified:

### 7.1 Bucket Versioning

Result: **Enabled**

Versioning helps preserve multiple versions of objects and supports recovery from accidental overwrites or deletions.

### 7.2 Default Encryption

Result: **SSE-S3 (AES256)**

The bucket reported AES256 as its default server-side encryption algorithm.

### 7.3 Public Access Block

All four public-access-block settings were verified as enabled:

- `BlockPublicAcls`
- `IgnorePublicAcls`
- `BlockPublicPolicy`
- `RestrictPublicBuckets`

These settings provide protection against unintended public access through bucket ACLs and policies.

## 8. IAM Configuration Review

The following IAM configuration checks were completed in Moto:

- The audit managed policy existed.
- The policy was attached to the intended role.
- The policy version was verified.
- No inline policies were present on the role.
- The role trust relationship was inspected.
- STS role assumption succeeded.

These checks confirmed the presence of the intended IAM configuration in the local simulator.

## 9. Permission-Enforcement Limitation

During testing, the following operation returned successfully with an empty result:

`aws s3api list-objects-v2 --bucket fintech-dev-backups --endpoint-url=http://127.0.0.1:5000`

The audit policy did not explicitly grant `s3:ListBucket`.

This result was unexpected and has not yet been conclusively explained.

It may reflect a difference or limitation in Moto's IAM permission-enforcement behavior. A successful response with an empty result does not establish that the intended least-privilege boundary is correctly enforced.

Consequently:

- The intended audit permissions were configured.
- STS role assumption was verified.
- Selected S3 configuration reads were verified.
- Denial of unauthorized operations has not been conclusively validated.

Further testing is required before claiming complete least-privilege enforcement.

## 10. Further Validation

The next validation activities are:

1. Investigate the unexpected `ListObjectsV2` response.
2. Test unauthorized S3 operations, including write attempts.
3. Confirm expected access-denied behavior.
4. Use a real AWS test account or another reliable IAM evaluation method to validate enforcement independently of Moto.
5. Review the final permissions against the principle of least privilege.

## 11. Production Engineering Considerations

Before adapting this design for a real fintech workload, additional controls and decisions would be required.

These include:

- Use IAM Identity Center or an appropriate federation model for human auditor access.
- Consider cross-account role assumption where auditors belong to another AWS account.
- Evaluate external IDs when designing third-party cross-account access.
- Avoid distributing long-lived IAM access keys.
- Enable and review AWS CloudTrail records for audit activity.
- Define backup retention and recovery requirements.
- Validate security controls in the actual AWS environment.
- Review access policies periodically.

The local implementation is a starting point for engineering and security validation, not a complete production security architecture.

## 12. Implementation Status

| Area | Status |
|---|---|
| Dedicated auditor identity | Configured |
| Audit IAM role | Configured |
| Role trust policy | Verified |
| Audit managed policy | Verified |
| STS role assumption | Successful |
| S3 versioning inspection | Successful |
| S3 encryption inspection | Successful |
| Public access block inspection | Successful |
| Least-privilege enforcement | Further validation required |

## 13. Conclusion

The project demonstrates an IAM role-based approach to separating security-audit access from other operational permissions.

The implementation established a dedicated auditor identity, a role trust relationship, a managed audit policy, and a successful STS role-assumption workflow in a local AWS-compatible environment.

The next engineering priority is to validate permission-denial behavior and confirm that the intended access boundaries are enforced.

---

**Project:** Fintech Cloud Environment  
**Focus:** Cloud Engineering | AWS IAM | STS | Amazon S3 | Security Auditing  
**Test environment:** Moto local AWS simulator
