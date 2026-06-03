# GCP Cloud Economics Demo — Full Deployment Guide

Everything you need to deploy from zero on Windows.
No scripts. Every GCP Console click and every terminal command in exact order.

---

## What you will deploy

```
before/   ← inefficient "legacy" GKE cluster  (~$2,625/month)
after/    ← AI-optimized GKE cluster           (~$348/month)
```

Each is an independent Terraform root. You deploy `before/` first,
run the AI analysis, then deploy `after/`.

---

## PART 1 — Install the tools on Windows

Open **PowerShell as Administrator** and run each block.

### 1.1 Install gcloud CLI
Download and run the installer from:
```
https://cloud.google.com/sdk/docs/install-sdk#windows
```
Click through the installer. When it finishes, **close and reopen PowerShell**.
Verify:
```powershell
gcloud version
```

### 1.2 Install Terraform
Download the Windows AMD64 zip from:
```
https://developer.hashicorp.com/terraform/install#windows
```
1. Unzip it — you get a single file: `terraform.exe`
2. Move `terraform.exe` to `C:\terraform\`
3. Add it to your PATH:
   - Start → search "Environment Variables"
   - Click "Environment Variables"
   - Under "System variables" find `Path` → Edit → New
   - Add: `C:\terraform`
   - Click OK on all windows

Verify (in a new PowerShell window):
```powershell
terraform version
```

### 1.3 Install kubectl
```powershell
gcloud components install kubectl
```
Verify:
```powershell
kubectl version --client
```

### 1.4 Install helm
Download the Windows installer from:
```
https://github.com/helm/helm/releases/latest
```
Download `helm-vX.X.X-windows-amd64.zip`, unzip, move `helm.exe` to `C:\terraform\` (same folder).

Verify:
```powershell
helm version
```

---

## PART 2 — Create a GCP account and project

### 2.1 Create a Google account (if you don't have one)
Go to: `https://accounts.google.com/signup`

### 2.2 Activate Google Cloud
Go to: `https://console.cloud.google.com`
- Click **"Get started for free"**
- Enter billing info (credit card required — Google gives $300 free credit)
- You will NOT be charged during the trial without manual upgrade

### 2.3 Create a new project
In the GCP Console:
1. Click the project dropdown at the top (next to "Google Cloud")
2. Click **"New Project"**
3. Fill in:
   - **Project name:** `cloud-economics-demo`
   - **Project ID:** note the auto-generated ID (e.g. `cloud-economics-demo-123456`) — you will need this
4. Click **Create**
5. Wait ~30 seconds, then select the project from the dropdown

> Write down your **Project ID** — you will use it in every step below.

### 2.4 Enable billing on the project
1. In the GCP Console left menu → **Billing**
2. Click **"Link a billing account"**
3. Select your billing account → **Set account**

---

## PART 3 — Enable the required APIs

In the GCP Console:
1. Left menu → **APIs & Services** → **Library**
2. Search for and **Enable** each of these (click the API name → Enable button):

| API | Search term |
|---|---|
| Kubernetes Engine API | `Kubernetes Engine` |
| Compute Engine API | `Compute Engine` |
| Identity and Access Management API | `IAM` |
| Cloud Resource Manager API | `Cloud Resource Manager` |
| Cloud Storage API | `Cloud Storage` |
| Cloud Monitoring API | `Cloud Monitoring` |
| Cloud Logging API | `Cloud Logging` |
| Artifact Registry API | `Artifact Registry` |

> Alternatively, run all at once in PowerShell (faster):
> ```powershell
> gcloud services enable `
>   container.googleapis.com `
>   compute.googleapis.com `
>   iam.googleapis.com `
>   cloudresourcemanager.googleapis.com `
>   storage.googleapis.com `
>   monitoring.googleapis.com `
>   logging.googleapis.com `
>   artifactregistry.googleapis.com `
>   --project=YOUR-PROJECT-ID
> ```

---

## PART 4 — Authenticate on Windows

Open **PowerShell** (not as admin this time) and run:

### 4.1 Log in to gcloud
```powershell
gcloud auth login
```
A browser window opens. Log in with your Google account. Come back to PowerShell when done.

### 4.2 Set your project
```powershell
gcloud config set project YOUR-PROJECT-ID
```
Replace `YOUR-PROJECT-ID` with the project ID from step 2.3.

### 4.3 Set credentials for Terraform
```powershell
gcloud auth application-default login
```
Another browser window opens. Log in again. This sets the credentials Terraform uses.

---

## PART 5 — Create the Terraform state bucket

Terraform needs a GCS bucket to store its state file before it can run.
You create this once — both `before/` and `after/` share it.

### 5.1 In the GCP Console
1. Left menu → **Cloud Storage** → **Buckets**
2. Click **"Create"**
3. Fill in:
   - **Name:** `YOUR-PROJECT-ID-tfstate` (e.g. `cloud-economics-demo-123456-tfstate`)
   - **Location type:** Region
   - **Region:** `us-east1`
   - **Storage class:** Standard
   - **Access control:** Uniform
4. Click **Create**

5. After creation, click on the bucket → **Configuration** tab
6. Under "Versioning" click **Edit** → enable → **Save**

### 5.2 Note the bucket name
You will use it in the next step. It should be: `YOUR-PROJECT-ID-tfstate`

---

## PART 6 — Configure the Terraform files

Open the project folder in Windows Explorer or VS Code.

### 6.1 Edit `before\main.tf`
Find this line near the top:
```hcl
bucket = "REPLACE_WITH_YOUR_TFSTATE_BUCKET"
```
Replace with your actual bucket name:
```hcl
bucket = "cloud-economics-demo-123456-tfstate"
```

### 6.2 Edit `after\main.tf`
Same change — find and replace the same line:
```hcl
bucket = "cloud-economics-demo-123456-tfstate"
```

### 6.3 Create `before\terraform.tfvars`
Create a new file called `terraform.tfvars` inside the `before\` folder with this content:
```hcl
project_id   = "YOUR-PROJECT-ID"
region       = "us-east1"
cluster_name = "prod-cluster"
environment  = "production"
```

### 6.4 Create `after\terraform.tfvars`
Create a new file called `terraform.tfvars` inside the `after\` folder with this content:
```hcl
project_id      = "YOUR-PROJECT-ID"
region          = "southamerica-east1"
cluster_name    = "prod-cluster"
environment     = "production"
authorized_cidr = "0.0.0.0/0"
spot_min_nodes  = 1
spot_max_nodes  = 4
```

---

## PART 7 — Deploy the BEFORE infrastructure

Open PowerShell and navigate to the `before\` folder:
```powershell
cd path\to\gcp-k8s-demo\before
```

### 7.1 Initialize Terraform
```powershell
terraform init
```
This downloads the Google provider and connects to your GCS backend.
Expected output: `Terraform has been successfully initialized!`

### 7.2 Preview what will be created
```powershell
terraform plan
```
Read through the output. You should see:
- 1 GKE cluster (zonal, us-east1-b)
- 1 node pool (5 × n1-standard-8, static)
- 3 GCS buckets
- 3 compute disks
- 3 static IPs

### 7.3 Deploy
```powershell
terraform apply
```
Type `yes` when prompted.

> ⏱ This takes **10–15 minutes** — GKE cluster creation is slow.

### 7.4 Configure kubectl
After apply finishes, run the command from the output:
```powershell
gcloud container clusters get-credentials prod-cluster --zone us-east1-b --project YOUR-PROJECT-ID
```
Verify:
```powershell
kubectl get nodes
```
You should see 6 nodes (1 default + 5 workload pool).

### 7.5 Deploy the inefficient k8s workloads
```powershell
kubectl apply -f k8s-deployments.yaml
```
Verify:
```powershell
kubectl get pods
kubectl get hpa
```

---

## PART 8 — AI reads the files and optimizes them

Point Claude at the `before\` folder contents:

```
Read all the files in before/ and identify every cloud cost inefficiency.
Then rewrite them as optimized infrastructure.
```

The AI will find issues in:
- `main.tf` — zonal cluster, on-demand static nodes, HPA disabled, 2 unused IPs
- `storage.tf` — multi-region buckets, no lifecycle rules, 3 orphaned SSD disks
- `k8s-deployments.yaml` — 10+8 hardcoded replicas, 3 LoadBalancers, broken HPA, always-on batch worker

The AI produces the `after/` files — which are already included in this package.

---

## PART 9 — Deploy the AFTER infrastructure

Open PowerShell and navigate to the `after\` folder:
```powershell
cd path\to\gcp-k8s-demo\after
```

### 9.1 Initialize Terraform
```powershell
terraform init
```

### 9.2 Preview
```powershell
terraform plan
```
You should see: VPC, subnet, Cloud NAT, service account, IAM bindings,
regional GKE cluster, 2 node pools (spot + on-demand), 1 static IP, 3 GCS buckets.

### 9.3 Deploy
```powershell
terraform apply
```
Type `yes` when prompted.

> ⏱ This takes **15–20 minutes** — regional cluster has 3 control plane zones.

### 9.4 Configure kubectl
```powershell
gcloud container clusters get-credentials prod-cluster --region southamerica-east1 --project YOUR-PROJECT-ID
```

### 9.5 Install NGINX Ingress Controller
```powershell
# Get the reserved ingress IP from Terraform output
$INGRESS_IP = terraform output -raw ingress_ip

# Add helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install
helm install ingress-nginx ingress-nginx/ingress-nginx `
  --namespace ingress-nginx --create-namespace `
  --set controller.service.loadBalancerIP=$INGRESS_IP `
  --wait
```

### 9.6 Deploy the optimized k8s workloads
```powershell
kubectl apply -f k8s-deployments.yaml
```
Verify:
```powershell
kubectl get pods -n production
kubectl get hpa -n production
kubectl get cronjobs -n production
```

---

## PART 10 — Destroy everything after the demo

> Do this to avoid charges after the demo is done.

### Destroy after/ first
```powershell
cd path\to\gcp-k8s-demo\after
terraform destroy
```
Type `yes` when prompted.

### Then destroy before/
```powershell
cd path\to\gcp-k8s-demo\before
terraform destroy
```
Type `yes` when prompted.

### Optionally delete the tfstate bucket
In the GCP Console → Cloud Storage → Buckets → select `YOUR-PROJECT-ID-tfstate` → Delete.

---

## Cost comparison

| Resource | Before | After | Saving |
|---|---|---|---|
| GKE nodes | 5× n1-standard-8 on-demand, static | e2-standard-4 spot, autoscales 3–12 | ~$988/mo |
| Cluster HA | Zonal (no HA) | Regional (3 zones) | — |
| HPA | Disabled | v2, min=2, CPU+memory | ~$200/mo |
| Static IPs | 3 reserved (2 unused) | 1 reserved | $15/mo |
| GCS storage | Multi-region, no lifecycle | Single-region, tiered, expires | ~$390/mo |
| Orphaned disks | 900 GB pd-ssd unattached | Deleted | $153/mo |
| Load balancers | 3 individual (one per service) | 1 NGINX Ingress | $36/mo |
| Batch worker | 4 replicas, always-on Deployment | CronJob, runs 2h/night | $171/mo |
| Secrets | Hardcoded in YAML | Kubernetes Secrets | security |
| Node SA | Default compute SA (overprivileged) | Least-privilege SA | security |
| **Total** | **~$2,625/mo** | **~$348/mo** | **$2,277/mo (87%)** |
