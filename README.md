# 🚀 AWS EKS Infrastructure with Terraform \& GitHub Actions

## ✅ Summary

This repository provisions a complete, AWS platform using Terraform, EKS, Helm, and GitHub Actions.
It includes reusable modules for VPC, EKS, Security, Observability, and DR.
A secure Terraform backend (S3 + DynamoDB + KMS) is deployed using AWS SSO.
Networking delivers a multi‑AZ VPC with 2 public + 2 private subnets and NAT/IGW.
EKS cluster is HA, IRSA-enabled, and includes CoreDNS, kube-proxy, and VPC CNI add-ons.
Microservices (User \& Order) are deployed automatically via Terraform/Helm with HPA \& PDB.
Security stack includes CloudTrail, GuardDuty, SecurityHub, IAM least privilege, and KMS-encrypted logs.
Observability integrates CloudWatch, Prometheus, and Grafana.
DR includes EBS snapshot policies, RDS multi‑AZ, Route53 failover, and cross-region replication.
GitHub Actions performs Terraform Plan/Apply on PR comment triggers using OIDC authentication.
Modules ensure reusable, scalable infrastructure across environments.
Workspaces isolate dev/prod.
Kubernetes manifests stored under `/kubernetes`.
---

# 📁 Repository Structure

```
.
├── modules/
│   ├── bootstrap-backend/
│   ├── network/
│   ├── eks/
│   ├── security/
│   ├── dr/
│   └── observability/
│
├── env/
│   ├── dev.tfvars
│   ├── prod.tfvars
│   └── backend.tfvars
│
├── kubernetes/
│   ├── namespaces.yaml
│   ├── ingress/
│   ├── microservices/
│   └── policies/
│
├── .github/workflows/
│   ├── ci.yml
│   └── destroy.yml
│
├── main.tf
├── eks-cluster.tf
├── security.tf
├── dr.tf
├── observability.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── architecture.png
└── README.md
```

\---

# 🧩 Architecture Overview
<img width="1752" height="937" alt="image" src="https://github.com/user-attachments/assets/103a8103-4c53-4a11-8812-119d6481d7a1" />


✅ Multi-AZ VPC with public/private subnets  
✅ EKS cluster with managed node groups  
✅ ALB/NGINX ingress  
✅ Microservices with HPA \& PDB  
✅ CloudTrail, GuardDuty, SecurityHub  
✅ Prometheus + Grafana  
✅ EBS snapshots, RDS multi‑AZ, Route53 failover  
✅ Backend: S3 + DynamoDB + KMS

\---

# ✅ Terraform Backend (Bootstrap Module)

* S3 bucket (versioned, encrypted)
* DynamoDB state lock
* KMS CMK for encryption
* AWS SSO authentication
* IAM least-privilege
* Tagging policies

```
aws sso login --profile my-sso-profile
terraform init -backend-config=env/backend.tfvars
```

\---

# ✅ Terraform Modules

### **Network Module**

* VPC
* Subnets (public and private)
* NAT
* IGW
* Route tables
* Flow logs

### **EKS Module**

* HA EKS control plane
* Managed node groups
* IRSA
* CSI drivers
* CoreDNS, kube-proxy, VPC CNI

### **Security Module**

* CloudTrail, GuardDuty, SecurityHub
* KMS
* IAM least privilege
* Central log buckets

### **DR Module**

* EBS snapshot policies
* RDS multi‑AZ + backup
* Route53 failover
* Cross-region replication

### **Observability Module**

* CloudWatch
* Prometheus

\---

# ✅ Microservices

User + Order services:

* Deployment
* Service
* HPA
* PDB
* ConfigMaps
* Secrets (KMS encrypted)
* Ingress routes

\---

# ✅ GitHub Actions CI/CD

### ✅ `ci.yml`

Comment trigger:

```
run terraform
```

### ✅ `destroy.yml`

Comment trigger:

```
terraform destroy
```

\---

# ▶️ Deployment Steps

```
aws sso login --profile my-sso-profile
terraform init -backend-config=env/backend.tfvars
terraform workspace select dev
terraform plan -var-file env/dev.tfvars -out tfplan.bin
terraform apply tfplan.bin
```

