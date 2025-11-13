### *Disaster Recovery Simulation – AWS Terraform Infrastructure Assessment*

This document describes **how to simulate disaster recovery (DR)** for the Terraform-based AWS infrastructure.
It covers:

* RDS recovery scenarios
* Bastion recovery
* Grafana + ALB restoration
* Region-wide failover
* Terraform state reconciliation
* Operational verification steps

This DR simulation is built to demonstrate readiness for **real-world high-severity outages**.

---

# **1. DR Objectives**

This DR plan ensures:

* ✔ High availability
* ✔ Recoverability of databases
* ✔ Infrastructure rebuild using IaC
* ✔ Zero SSH dependency (SSM only)
* ✔ Observability restored
* ✔ Minimal manual steps
* ✔ Terraform remains the single source of truth

---

# **2. AWS Components Involved in DR**

* **RDS PostgreSQL** (snapshot-based recovery)
* **VPC + Subnets** (Terraform recreates)
* **Bastion host** (SSM-enabled)
* **Grafana EC2 instance** (restored via module)
* **Application Load Balancer**
* **IAM roles (OIDC)**
* **Terraform backend (S3 + DynamoDB)**

---

# **3. Failure Scenarios Covered**

This DR simulation covers:

### 1. **RDS Data Corruption**

* Bad migration
* Table dropped
* PII overwritten incorrectly

### 2. **Accidental RDS Instance Deletion**

* Infrastructure misconfiguration
* Accidental deletion

### 3. **Unhealthy RDS Cluster / Failover Loop**

* Multi-AZ failure
* Storage failure
* Writer/reader stuck

### 4. **Grafana Failure**

* EC2 compromise
* ALB failure
* Configuration corruption

### 5. **Entire Region Failure**

* AWS service disruption
* Regional outage (rare but must be tested)

Terraform + snapshots + cross-region restore ensures full system recovery.

---

# **4. Pre-DR Checklist**

Before running any DR simulation:

* ✔ Confirm Terraform backend is healthy
* ✔ Ensure latest snapshots exist
* ✔ CI backup check passed last night
* ✔ IAM/OIDC roles functioning
* ✔ Bastion access tested via SSM
* ✔ Deployment freeze (prod only)

---

# **5. Scenario 1 – RDS Data Corruption Simulation**

### Step 1 — Induce a failure (safe simulation)

Run from bastion:

```sql
DELETE FROM users WHERE id = 1;
```

Or simulate a broken migration.

### Step 2 — Identify corruption

* Error in application
* Missing rows
* CI nightly snapshot check fails
* Grafana alarm triggers

### Step 3 — Initiate DR restore

Restore the last known-good snapshot:

```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier prod-db-restore \
  --db-snapshot-identifier snapshot-prod-2025-02-10
```

### Step 4 — Map Terraform to new DB

Temporarily update:

```
globals.tfvars
```

Set:

```
db_identifier_override = "prod-db-restore"
```

### Step 5 — Reapply Terraform:

```bash
terraform apply -var-file="../../globals.tfvars"
```

This reconnects:

* Bastion → New DB
* Security groups
* Monitoring

### Step 6 — Validate

From bastion:

```bash
psql -h <new-endpoint> -U <user> -c "SELECT count(*) FROM users;"
```

### Step 7 — Clean Up

Delete the corrupted DB:

```bash
aws rds delete-db-instance --db-instance-identifier prod-db-broken
```

---

# **6. Scenario 2 – Accidental RDS Deletion**

If someone deletes RDS accidentally:

### Step 1 — Terraform Plan will fail

```bash
terraform plan
```

Output:

```
Error: DB instance not found
```

### Step 2 — Look up latest snapshot

```bash
aws rds describe-db-snapshots --db-instance-identifier prod
```

### Step 3 — Restore DB from snapshot

Same as Scenario #1.

### Step 4 — Re-run Terraform

Terraform will reattach networking, SGs, and bastion routes.

---

# **7. Scenario 3 – Grafana EC2 / ALB Failure**

### Symptoms:

* Dashboard unreachable
* ALB unhealthy
* EC2 failure

### Recovery Steps:

1. **Re-run Terraform apply**
   Terraform will recreate ALB + EC2 + IAM profile.

2. **Check userdata logs**

```bash
sudo cat /var/log/cloud-init.log
```

3. **Restart Grafana**

```bash
sudo systemctl restart grafana-server
```

4. **Verify ALB target health**

```bash
aws elbv2 describe-target-health --target-group-arn <tg>
```

---

# **8. Scenario 4 – Region-Wide AWS Failure (Full Disaster)**

This simulates the worst-case scenario.

### Step 1 — Update backend.hcl to DR region

Example:

```
region         = "eu-central-1"
bucket         = "tf-state-dr-region"
dynamodb_table = "terraform-locks-dr"
```

### Step 2 — Initialize Terraform in new region

```bash
terraform init -migrate-state
```

### Step 3 — Restore RDS snapshot to new region

```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier prod-dr \
  --source-region me-central-1 \
  --db-snapshot-identifier arn:aws:rds:me-central-1:snapshot/prod-latest
```

### Step 4 — Deploy entire infra in new region

```bash
terraform apply -var-file="../../globals.tfvars"
```

This rebuilds:

* VPC
* Subnets
* NAT gateways
* Bastion
* Grafana
* Security groups
* IAM OIDC roles
* ALB

### Step 5 — Validate Connectivity

* Bastion via SSM
* Grafana via ALB
* RDS connectivity

### Step 6 — Switch DNS / Endpoint Cutover

Update Cloudflare / Route53 / API Gateway:

```
prod.api.company.com -> new ALB DNS
```

---

# **9. Scenario 5 – Blue/Green DB Upgrade Rollback**

Documented in MIGRATION_NOTES.md.

### Blue deployment:

Terraform:

```hcl
enable_blue_green_upgrade = true
```

Apply new engine version.

### Validate:

* Run queries
* Check logs
* Test performance

### Promote:

```bash
aws rds describe-blue-green-deployments
```

### If failure → rollback:

```bash
aws rds switchover-blue-green-deployment \
  --blue-green-deployment-identifier bgd-123
```

---

# **10. Post-DR State Reconciliation**

After any DR restoration:

### ✔ Update Terraform state

If DB restored manually:

```bash
terraform import aws_db_instance.prod-db <arn>
```

Or update variables:

```
db_identifier_override = "prod-restore"
```

### ✔ Re-run full plan

```bash
terraform plan -var-file="../../globals.tfvars"
```

### ✔ Fix drift

```bash
terraform apply -var-file="../../globals.tfvars"
```

---

# **11. Validation Checklist**

After DR, confirm:

* RDS reachable
* Bastion reachable
* Grafana reachable
* ALB healthy
* CI/CD functioning
* OIDC trust restored
* Backups re-enabled
* Terraform state clean

---

# **12. Handover Notes**

* Prod DR must be approved by engineering lead
* All restores logged in Confluence/Jira
* Snapshots must be retained for 7–30 days
* Multi-AZ must be enabled in prod
* Blue/green upgrades recommended for engine changes
* Bastion access always via SSM
* Never modify infra manually except during DR

---

# **13. Final DR Outcome**

Using this simulation:

✔ You can recover from corruption
✔ You can recover from accidental deletion
✔ You can rebuild entire environments
✔ You can fail over to a DR region
✔ You can restore monitoring + bastion
✔ You can maintain Terraform integrity
✔ You demonstrate enterprise-level DR readiness
