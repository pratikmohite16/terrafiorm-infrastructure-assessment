# 🛡️ **SECURITY_PRACTICES.md**

### *Full Security Hardening Guide for AWS + Terraform + GitHub Actions (OIDC)*

---

## 📌 **Purpose**

This document defines the **security controls, guardrails, and best practices** used in this Terraform-based AWS multi-environment infrastructure with GitHub Actions CI/CD.

The goal:

* Enforce **least privilege**
* Ensure **zero trust** principles
* Maintain **auditability**
* Secure **data at rest + in transit**
* Prevent **secret leakage**
* Protect **supply chain integrity**
* Maintain **environment isolation**
* Support **PCI-DSS, SOC 2, ISO 27001** readiness

---

# 🔐 **1. Identity & Access Management (IAM)**

## **1.1 GitHub Actions OIDC – Zero Secrets CI/CD**

This repo uses **AWS IAM Roles + OpenID Connect federation**:

✔ No long-lived AWS keys
✔ No GitHub org secrets containing AWS credentials
✔ Each environment has its **own IAM role**:

* `dev-gha-role`
* `stage-gha-role`
* `prod-gha-role`

### **Security Controls**

| Control                                      | Why it matters                     |
| -------------------------------------------- | ---------------------------------- |
| Bound to specific repo (`repo:owner/name:*`) | Prevents external repo hijacking   |
| Bound to protected branches                  | Prevent unauthorized infra changes |
| Session duration < 1 hour                    | Limits blast radius                |
| Terraform plan/apply separated               | Change control enforcement         |
| IAM role has limited actions                 | Principle of least privilege       |

### **Example Permissions (restrictive)**

* Allow:
  `ec2:*`, `rds:*`, `iam:PassRole`, `eks:*`, etc **ONLY for resources tagged with `Env=dev|stage|prod`**
* Deny:
  Access to KMS keys not belonging to environment
  Access to SSM parameters from other envs
  Access to Secrets Manager secrets from other envs

---

# 🏗️ **2. Infrastructure-as-Code Security (Terraform)**

## **2.1 Remote State Security**

Terraform state is secured using:

* **S3 bucket with enforced SSE-KMS**
* **Bucket versioning**
* **Bucket access logging**
* **Block Public Access = TRUE**
* **DynamoDB table for state locking**

### **State Access Controls**

* Only the environment-specific GitHub OIDC role can read/write state.
* Cross-environment state access is explicitly denied.
* IAM SCPs prevent accidental sharing.

## **2.2 Terraform Security Scanning**

Automated via CI:

* **tfsec** → IaC vulnerability scanning
* **Checkov** → compliance scanning (PCI, SOC2, ISO)
* **Terraform fmt/validate** → linting & sanity checks
* **OPA/ConfTest** (optional) → enforce guardrails

### Detected Violations Automatically Include:

* Public subnets with no need
* Security groups with `0.0.0.0/0` ingress
* Missing encryption
* IAM wildcard permissions
* Public S3 buckets
* Deprecated instance types

---

# 📡 **3. Network Security**

## **3.1 Multi-Environment VPC Isolation**

Each environment has strong VPC isolation:

| ENV   | VPC      | Peering | Notes             |
| ----- | -------- | ------- | ----------------- |
| dev   | isolated | no      | strictly internal |
| stage | isolated | no      | only for QA + UAT |
| prod  | isolated | no      | critical systems  |

No VPC sharing.
No peering.
No transitive routing.

**Unless explicitly configured**, the environments **cannot talk to each other**.

## **3.2 Subnet Segmentation**

* Public Subnets → Bastion, ALBs only
* Private Subnets → RDS/Grafana
* No RDS in public subnets
* NAT Gateway for outbound-only access
* Deny IGW access from private subnets

## **3.3 Security Groups – Zero Trust**

Strict ingress model:

* Bastion can reach DBs
* CI/CD cannot reach DBs directly
* Apps reach DB only via allowed ports
* SSH restricted to VPN/office IPs
* Deny all outbound from RDS except necessary replication/endpoints

---

# 🔑 **4. Secrets Management**

## **4.1 AWS Secrets Manager (Primary)**

All sensitive values:

* RDS PG Passwords
* Grafana admin credentials
* API keys
* External service credentials
* Bastion SSH Public keys

are stored in **AWS Secrets Manager**.

### Rotations:

| Env   | Frequency                        |
| ----- | -------------------------------- |
| dev   | 7 days                           |
| stage | 14 days                          |
| prod  | 30 days (PCI requires ≤ 90 days) |

### CI/CD Access:

GitHub OIDC role loads secrets **only during deployment**, never stored.

## **4.2 No Secrets in Terraform Code**

✔ No plaintext passwords
✔ No secrets in variables.tf
✔ No tfvars stored in repo
✔ No secrets in STDERR/STDOUT logs
✔ No secrets in state (because we use generated passwords stored in Secrets Manager)

---

# 🧱 **5. RDS / Postgres Security**

## **5.1 Encryption**

* **SSE-KMS** required for all RDS instances
* Customer-managed KMS keys for prod
* Automatic rotation enabled

## **5.2 Authentication Hardening**

* Require TLS connections
* IAM Database Authentication disabled unless required
* Root user password rotated every 30 days
* No public RDS instances

## **5.3 Backup Security**

Production RDS:

* PITR retention: 14 days
* Automatic snapshots
* KMS-encrypted snapshots
* Cross-region snapshots (optional)

---

# 🛡️ **6. Bastion Host Security**

* Runs in isolated public subnet
* SSH allowed only from VPN/global office CIDR
* No persistent storage
* Session logs shipped to CloudWatch
* Fail2Ban (optional)
* No long-lived keys
* Uses SSM Session Manager to eliminate SSH entirely (recommended for prod)

---

# 🔐 **7. GitHub Actions Security**

## **7.1 Protected Branches**

| Branch | Restrictions                  |
| ------ | ----------------------------- |
| prod   | Must require PR + 2 approvals |
| stage  | Must require PR + 1 approval  |
| dev    | Optional                      |
| main   | No direct pushes              |

## **7.2 Sensitive Actions Restrictions**

* Only prod OIDC role can deploy to prod
* Terraform apply allowed only via workflow, never manual
* Terraform plan allowed by anyone

## **7.3 Supply Chain Security**

* Pin all Actions using SHA256 hashes
* Use Dependabot for action version bumps
* Use Gitleaks for secret detection
* Use SLSA Level 2+ (enabled via GitHub Actions attestation)

---

# 🧵 **8. Logging & Monitoring**

## **8.1 Mandatory Logging**

* VPC Flow Logs
* ALB Logs
* RDS Logs (slow query, error)
* CloudTrail (all regions, all accounts)
* S3 Access Logs for Terraform state bucket

All logs stored in a central **Security OU -> Logging Account**.

## **8.2 Grafana Dashboards**

Dashboards include:

* RDS CPU, connections, IOPS
* ALB request counts
* NAT data transfer
* Terraform deployment logs
* GitHub Actions audit logs

---

# 🗃️ **9. Compliance Hardening**

Supports:

### PCI-DSS

* Database encryption enforced
* Rotation policies in place
* Bastion access auditing
* Network segmentation
* No default passwords
* Backup retention
* MFA everywhere

### SOC2

* Audit logs exported
* Infrastructure code version-controlled
* Access control policies
* CI/CD logging

### ISO 27001

* Asset inventory via Terraform
* IAM role lifecycle management
* Incident/DR documentation

---

# 🧨 **10. Disaster Recovery & Incident Response**

### DR Controls

* Cross-region snapshots
* Terraform IaC allows full environment recreation
* RPO: 5 minutes (PITR)
* RTO: < 30 minutes (redeploy infra + restore DB)

### Incident Response Controls

* Automated alerts (CloudWatch + GitHub)
* On-call escalation plan
* Post-mortem culture
* Backup validation via CI/CD ephemeral restore

---

# 🔚 **Conclusion**

This repository implements **real-world enterprise security standards** across:

* IAM
* Networking
* Secrets
* Terraform state
* CI/CD
* RDS
* Compliance
* Monitoring

These practices ensure that **development, staging, and production** environments are:

✔ Secure
✔ Isolated
✔ Auditable
✔ Compliant
✔ Automated

---


