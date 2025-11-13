### *Infrastructure Handover Document – AWS Terraform Multi-Environment Deployment*

This document is intended for **new engineers** joining the project.
It provides a complete understanding of:

* How the infrastructure is structured
* How Terraform is organized
* How deployments work per environment
* How CI/CD interacts with AWS using OIDC
* How to perform day-to-day operations
* Backup, DR, and troubleshooting workflows
* Module responsibilities

This ensures smooth onboarding, zero guesswork, and consistent operational discipline.

---

# **1. High-Level Architecture Overview**

The infrastructure is deployed across **three AWS environments**:

* **dev** (development/testing)
* **stage** (pre-production)
* **prod** (production)

Each environment provisions:

### ✔ VPC (private/public subnets)

### ✔ RDS PostgreSQL (multi-AZ)

### ✔ Bastion host for controlled DB access

### ✔ Grafana EC2 with ALB

### ✔ Security groups enforcing strict isolation

### ✔ IAM + OIDC for GitHub deployments

Terraform builds each environment using a **shared set of modules**:

```
modules/
  ├── vpc/
  ├── rds_postgres/
  ├── bastion/
  ├── grafana_ec2_alb/
  ├── iam_github_oidc/
  └── security_groups/
```

---

# **2. Repository Structure (What You Must Know)**

```
terraform-infrastructure-assessment/
│
├── env/dev/       # Environment-specific entrypoint
├── env/stage/
├── env/prod/
│
├── modules/       # Reusable infrastructure blocks
│
├── .github/workflows/   # CI/CD pipelines
│   ├── terraform-plan-apply.yml
│   ├── nightly-backup-check.yml
│   └── security-scan.yml
│
├── globals.tfvars        # Shared values (instance sizes, tags, naming)
├── backend.hcl           # Remote state configuration
├── providers.tf          # AWS + GitHub OIDC
├── versions.tf           # Providers / Terraform version
│
├── README.md
├── DECISIONS.md
├── SECURITY_PRACTICES.md
├── DR_SIMULATION.md
└── MIGRATION_NOTES.md
```

This structure is intentionally simple, modular, and enterprise-aligned.

---

# **3. How to Work With Terraform**

## **3.1 Backend Setup**

Before running Terraform, ensure the backend is configured:

```
backend.hcl
```

Contains:

* S3 bucket for state
* DynamoDB table for locks
* Pointer to environment

---

## **3.2 Initialize Terraform**

From the root:

```bash
terraform init -backend-config=backend.hcl
```

---

## **3.3 Running Terraform for an Environment**

### Dev:

```bash
cd env/dev
terraform plan -var-file="../../globals.tfvars"
terraform apply -var-file="../../globals.tfvars"
```

### Stage:

```bash
cd env/stage
terraform apply -var-file="../../globals.tfvars"
```

### Prod:

```bash
cd env/prod
terraform apply -var-file="../../globals.tfvars"
```

⚠️ **Prod requires explicit approval and multi-person review.**

---

# **4. CI/CD Workflow (GitHub Actions)**

The deployment process is automated through OIDC.

### Pipelines:

| File                       | Purpose                          |
| -------------------------- | -------------------------------- |
| `terraform-plan-apply.yml` | PR plan → auto apply on merge    |
| `security-scan.yml`        | tfsec + checkov scans            |
| `nightly-backup-check.yml` | Validates RDS snapshot freshness |
| `main.yml`                 | Combined workflow                |

### Branch Rules

| Git Branch | AWS Environment |
| ---------- | --------------- |
| `dev`      | Dev             |
| `stage`    | Staging         |
| `main`     | Production      |

### OIDC Auth — Important

No AWS access keys are used.
GitHub identities assume AWS roles via:

```
module "iam_github_oidc"
```

This role determines **which environment** the pipeline can deploy to.

---

# **5. Secrets, Access & Credentials**

### ✔ No AWS Secrets stored in GitHub

✔ No `.tfvars` containing credentials
✔ RDS passwords generated in Terraform & stored in AWS Secrets Manager
✔ Bastion login only via AWS SSM Session Manager
✔ Grafana credentials set via userdata

---

# **6. Accessing the Infrastructure**

## **6.1 Bastion Access**

Bastion host is the only way to reach RDS.

**Start session (SSM):**

```bash
aws ssm start-session --target <instance-id>
```

From bastion:

```bash
psql -h <rds-endpoint> -U <db-user>
```

SSH keys are **not** used anywhere.

---

# **7. Monitoring (Grafana)**

### Deployment:

Grafana runs on an EC2 instance behind an ALB.

### Access:

* ALB DNS → HTTP/HTTPS
* Protected via SG
* Basic dashboards pre-provisioned

Logs and metrics collected from:

* EC2 metrics
* RDS metrics
* VPC flow logs (optional extension)

---

# **8. Backup & DR Operations**

Described in detail in **DR_SIMULATION.md**.

### Backup Expectations:

* RDS automated backups enabled
* Retention: production > staging > dev
* Nightly GitHub workflow checks snapshot timestamp
* Failures alert through pipeline

### Disaster Recovery Steps:

1. Identify latest snapshot
2. Restore new RDS instance
3. Point bastion + apps to restored endpoint
4. Validate data integrity
5. (Optional) Promote replica
6. Update Terraform state

### Region-Wide Disaster:

* Restore snapshot in secondary region
* Recreate bastion & Grafana
* Re-attach networking
* Re-run Terraform with updated backend

---

# **9. Blue/Green Deployment Workflow**

Documented in **MIGRATION_NOTES.md**.

Supported through Terraform by:

* Creating new RDS cluster or upgraded instance
* Testing it
* Promoting blue version
* Rolling back if needed (snapshot restore)

This ensures zero-downtime database upgrades.

---

# **10. Cost Optimization Guidelines**

See **optimization-plan.md** (in local repo version).
AWS version summarized:

✔ Rightsize RDS instances per environment
✔ Use gp3 storage + autoscaling
✔ Use SSM Session Manager to avoid NAT/SSH costs
✔ Remove unused QA/Dev resources
✔ Destroy ephemeral resources after testing
✔ Enable CloudWatch alarms for cost anomalies

---

# **11. Daily Operational Tasks Checklist**

### **Morning**

* Check last RDS snapshot
* Check CI/CD pipeline status
* Review CloudWatch alarms
* Confirm Grafana dashboards healthy

### **Before Deployment**

* Ensure branch matches environment
* Review Terraform plan
* Check pending DR risks
* Confirm IAM/OIDC role access

### **Weekly**

* Rotate IAM roles if needed
* Review SG rules
* Validate Grafana & Bastion patches
* Audit Terraform state health

---

# **12. Troubleshooting Guide**

### **Terraform Fails With "state lock"**

Run:

```bash
aws dynamodb delete-item --table-name terraform-locks ...
```

### **Grafana not accessible**

* Check ALB SG
* Check ALB health checks
* Restart EC2 instance via console

### **Cannot access RDS**

* Validate:

  * Bastion instance running
  * SSM agent healthy
  * RDS in private subnet
  * SG allows bastion → RDS

### **CI/CD Plan succeeds but Apply fails**

* Plan applied with older backend state
* Run `terraform init -reconfigure`

### **Terraform drift**

Run:

```bash
terraform plan -refresh-only
```

---

# **13. Who Owns What (Roles & Responsibilities)**

| Area                  | Responsibility       |
| --------------------- | -------------------- |
| VPC, Subnets, Routing | Cloud/Infra Engineer |
| RDS Postgres          | DB + Infra           |
| Bastion Host          | Infra/Security       |
| Grafana               | Infra/Monitoring     |
| Security Groups       | DevSecOps            |
| CI/CD (OIDC)          | DevOps               |
| DR Process            | Infra + Compliance   |
| Terraform Modules     | Platform Engineering |

---

# **14. Final Notes**

This handover ensures **zero ambiguity** for anyone maintaining or extending the infrastructure.

You now have:

* Clear deployment flows
* Safe CI/CD pipelines
* Fully modular Terraform
* Secure networking
* Monitoring stack
* Backup + DR strategy
* Audit-ready documentation

