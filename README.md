### *AWS Terraform Infrastructure Assessment – Multi-Environment Secure Deployment*

This repository contains a complete **AWS Infrastructure-as-Code (IaC) implementation** using **Terraform**, designed to deploy a fully secure, multi-environment platform with:

* **RDS PostgreSQL clusters** (dev, stage, prod)
* **VPC with public/private subnets**
* **Bastion host for controlled DB access**
* **EC2-based Grafana + ALB monitoring stack**
* **Security Groups enforcing strict isolation**
* **GitHub → AWS OIDC for keyless CI/CD**
* **Nightly backup checks + security scans**
* **Blue/Green-supporting database workflow**
* **Disaster Recovery simulation** (DR_SIMULATION.md)
* **Team handover documentation** (TEAM_HANDOVER.md)

Everything is modular, reusable, secure, and follows enterprise-grade Terraform patterns.

---

# **1. Architecture Overview**

This solution provisions:

## ✔ **Network Layout (modules/vpc)**

* Dedicated VPC per environment (dev/stage/prod)
* Public + Private subnets
* NAT Gateways for outbound private subnet traffic
* Internet Gateway for bastion + ALB
* Route tables per subnet class

## ✔ **Database Layer (modules/rds_postgres)**

For each environment:

* Multi-AZ **RDS PostgreSQL** (production-grade)
* Automated backups
* Enhanced monitoring
* Encrypted storage (KMS)
* Parameter groups for scaling
* Option group for extensions
* Blue-green upgrade readiness (AWS RDS feature)

## ✔ **Identity & Access (modules/iam_github_oidc)**

* GitHub Actions → AWS OIDC trust relationship
* No long-lived AWS keys
* Least-privilege IAM roles for CI/CD
* Separate roles per environment
* Deployment-scoped permissions

## ✔ **Compute Layer**

### **Bastion Host (modules/bastion)**

* Deployed in public subnet
* SSM enabled (no SSH keys)
* Restrictive SG → only admin access allowed
* Used to connect to private RDS instances

### **Grafana + ALB (modules/grafana_ec2_alb)**

* EC2 instance running Grafana
* Application Load Balancer
* Auto-healing health checks
* Security Groups
* Dashboard installed via `userdata.sh`

## ✔ **Security Groups (modules/security_groups)**

Includes:

* Bastion → RDS allow rules
* ALB → Grafana allow rules
* Cross-environment traffic **blocked**
* Strict ingress/egress baselines
* No open ports except ALB 80/443

## ✔ **CI/CD Pipelines (.github/workflows)**

1. `terraform-plan-apply.yml`

   * Runs plan on PR
   * Applies on merge
   * Uses OIDC (no secrets)

2. `security-scan.yml`

   * Runs tfsec
   * Runs Checkov
   * Fails if misconfigurations found

3. `nightly-backup-check.yml`

   * Queries AWS RDS for last snapshot
   * Ensures backups are healthy
   * Alerts if backup is stale

4. `main.yml`

   * Full workflow orchestration

---

# **2. Repository Structure**

```
terraform-infrastructure-assessment/
│
├── .github/workflows/         # CI/CD pipelines
├── env/
│   ├── dev/                   # Environment-specific variables & entrypoints
│   │   ├── main.tf
│   │   └── variables.tf
│   ├── stage/
│   └── prod/
│
├── modules/
│   ├── vpc/
│   ├── rds_postgres/
│   ├── bastion/
│   ├── grafana_ec2_alb/
│   ├── iam_github_oidc/
│   └── security_groups/
│
├── globals.tfvars             # Shared values for all environments
├── providers.tf               # AWS + GitHub providers + OIDC config
├── backend.hcl                # Remote backend configuration
├── versions.tf                # Version constraints
│
├── DECISIONS.md
├── MIGRATION_NOTES.md
├── SECURITY_PRACTICES.md
├── DR_SIMULATION.md
└── TEAM_HANDOVER.md
```

---

# **3. How to Deploy**

## **1️⃣ Configure Backend**

Edit:

```
backend.hcl
```

Set:

* S3 bucket
* DynamoDB lock table
* Region

Example:

```hcl
bucket         = "my-terraform-state-bucket"
key            = "infra/dev/terraform.tfstate"
region         = "me-central-1"
dynamodb_table = "terraform-locks"
```

---

## **2️⃣ Initialize Terraform**

```bash
terraform init -backend-config=backend.hcl
```

---

## **3️⃣ Choose Environment**

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

---

# **4. CI/CD Deployment Model**

### **Branch-Based Deployment Logic**

| Branch  | Deploys To |
| ------- | ---------- |
| `dev`   | AWS Dev    |
| `stage` | AWS Stage  |
| `main`  | AWS Prod   |

### **Security (OIDC)**

CI/CD authenticates through:

```
module "iam_github_oidc"
```

This ensures:

* No AWS access keys
* Rotating short-lived credentials
* Zero-trust GitHub → AWS identity model

---

# **5. Security Controls Summary**

✔ RDS encryption (KMS)
✔ Least privilege IAM
✔ OIDC → no long-lived secrets
✔ Bastion hardened with SSM
✔ Private subnets for databases
✔ No public DBs
✔ Security groups block cross-env traffic
✔ ALB only allows HTTP/HTTPS
✔ Grafana restricted by ALB SG
✔ tfsec + Checkov CI scans
✔ Nightly backup verification

See `SECURITY_PRACTICES.md` for full detail.

---

# **6. Blue-Green Deployment Support**

RDS PostgreSQL supports:

* **Automatic blue/green upgrade orchestration**
* **Zero-downtime failover**
* **Fast point-in-time restore**

Your Terraform RDS module is structured so you can:

* Deploy a new version of PostgreSQL
* Validate
* Promote
* Roll back

All explained in MIGRATION_NOTES.md.

---

# **7. Monitoring (Grafana)**

Module features:

* EC2 instance running Grafana
* ALB in front
* Security groups
* Dashboards provisioned in userdata
* CloudWatch metrics scraped

You can extend this by:

* Enabling CloudWatch Agent
* Using AWS Managed Grafana (future upgrade)

---

# **8. Disaster Recovery Simulation**

Documented in:

```
DR_SIMULATION.md
```

Covers:

* RDS snapshot restore
* Region failover
* Bastion recovery
* Grafana rebuild
* Cross-region failover procedures
* How Terraform re-applies state after outage

---

# **9. Team Handover**

`TEAM_HANDOVER.md` includes:

* Credentials model
* Deployment instructions
* DR workflow
* Secrets rotation
* How to extend modules
* Onboarding steps

---

# **10. How to Destroy**

### Only for development environments:

```bash
terraform destroy -var-file="../../globals.tfvars"
```

⚠️ **Never destroy prod without business approval.**

---

# **11. Conclusion**

This repository provides:

* Fully modular multi-environment Terraform
* Secure CI/CD deployments with OIDC
* Complete RDS PostgreSQL + Bastion architecture
* Observability with Grafana + ALB
* Backup verification
* DR simulation
* Security hardening
* Clear documentation for audit & handover

