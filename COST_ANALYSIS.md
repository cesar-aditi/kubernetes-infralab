# Infrastructure Cost Analysis — BEFORE Optimization
> Last infrastructure review: **Never**
> Deployed: 2021 | Current date: 2024

---

## Estimated Monthly Cost Breakdown

| Resource | Config | Est. Cost/Month |
|---|---|---|
| GKE Cluster (management fee) | 1 zonal cluster | $72 |
| Node Pool — general-workload | 5× n1-standard-8 on-demand, 24/7 | $1,168 |
| Default node pool node | 1× n1-standard-8 (wasted) | $234 |
| Static IP addresses (unused) | 3× reserved, idle | $22 |
| Cloud Storage — assets | Multi-region STANDARD | $180 |
| Cloud Storage — logs (3yr acc.) | ~4TB STANDARD, no lifecycle | $106 |
| Cloud Storage — backups (3yr acc.) | ~8TB STANDARD, no expiry | $208 |
| Orphaned SSD PD — legacy-db | 500GB pd-ssd unattached | $85 |
| Orphaned SSD PDs — workers | 2× 200GB pd-ssd unattached | $68 |
| Load Balancers | 3× individual LBs (frontend, backend, batch) | $54 |
| Inter-zone egress | Uncontrolled pod-to-pod cross-zone | ~$200 |
| **TOTAL** | | **~$2,397/month** |

---

## Key Problems Identified

### 1. Oversized Nodes, No Autoscaling
- All nodes are `n1-standard-8` (8 vCPU / 30GB RAM)
- Node count is **static at 5** — paying for full capacity 24/7
- No Cluster Autoscaler configured
- No use of **Spot/Preemptible VMs** (would save 60–91%)

### 2. Oversized Pod Resource Requests
- Frontend pods request `2Gi RAM / 1000m CPU` — actual usage: `~200Mi / 100m`
- Over-provisioning means nodes appear "full" while mostly idle
- Cluster cannot bin-pack efficiently → more nodes needed than actually required

### 3. Always-On Batch Workloads
- `batch-worker` Deployment runs **4 replicas 24/7**
- Jobs only execute for ~2 hours at night
- Should be a **CronJob** — would reduce cost by ~95% for this workload

### 4. HPA Misconfigured
- `minReplicas` equals current replica count → HPA can only **scale up, never down**
- Defeats the entire purpose of autoscaling

### 5. Self-Hosted Monitoring (Prometheus)
- Running 2 Prometheus replicas in-cluster
- GCP Cloud Monitoring + Managed Prometheus available at no extra infra cost
- Consuming ~8Gi RAM and 2 vCPU for redundant functionality

### 6. Storage Waste
- 3 years of logs and backups in STANDARD storage (no lifecycle rules)
- 3 orphaned persistent disks from deleted VMs
- Multi-region buckets where single-region would suffice
- Versioning enabled with no expiry policy

### 7. Load Balancer Per Service
- 3 individual Cloud Load Balancers ($18/month each, idle)
- Should use 1 Ingress controller with path-based routing

### 8. Wrong Region
- Deployed in `us-east1` — team and users are primarily in **Latin America**
- `southamerica-east1` (São Paulo) or `northamerica-south1` (Mexico) would reduce latency
- Some committed use discounts available per region

---

## Optimization Potential

| Category | Potential Savings |
|---|---|
| Spot VMs for stateless workloads | ~$850/month |
| Cluster autoscaler + right-sized nodes | ~$400/month |
| Right-sized pod requests | Enables above savings |
| CronJob for batch workers | ~$180/month |
| Storage lifecycle policies | ~$250/month |
| Delete orphaned disks | ~$153/month |
| Managed monitoring (remove Prometheus) | ~$120/month |
| Single Ingress vs 3 LBs | ~$36/month |
| **Total potential savings** | **~$1,989/month (~83%)** |
