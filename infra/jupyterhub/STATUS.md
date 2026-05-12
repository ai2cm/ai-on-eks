# AWS JupyterHub Infrastructure Status

_Last updated: 2026-05-09_

---

## EKS Cluster

- **Name:** `workshop-jhub`
- **Region:** `us-west-2`
- **Account:** `384484506514`
- **Status:** ACTIVE
- **Kubernetes version:** 1.34
- **Endpoint:** `https://BAA0FEF1E8724B78760279BBA480EB97.yl4.us-west-2.eks.amazonaws.com`
- **Created:** 2026-05-05

## Nodes

Two managed core nodes currently running (Bottlerocket OS 1.60.0, containerd 2.1.6):

| Node | Internal IP |
|------|-------------|
| `ip-100-64-120-253.us-west-2.compute.internal` | 100.64.120.253 |
| `ip-100-64-145-184.us-west-2.compute.internal` | 100.64.145.184 |

Managed node groups: `core-node-group-*`, `nvidia-gpu-*`

## Karpenter Node Pools

All pools are `Ready`, currently provisioned to **0 nodes** (scale-to-zero):

| Pool | Instance Family | GPU / Accelerator | Capacity Type |
|------|----------------|-------------------|---------------|
| `g5-nvidia` | g5 | NVIDIA A10G (24 GB) | on-demand |
| `g6-nvidia` | g6 | NVIDIA L4 (24 GB) | on-demand |
| `g6e-nvidia` | g6e | NVIDIA L40S (46 GB) | on-demand |
| `inf2-neuron` | inf2 | AWS Inferentia2 | on-demand |
| `m6i-cpu` | m6i | CPU only | on-demand |
| `trn1-neuron` | trn1 | AWS Trainium | on-demand |

All GPU pools carry a `nvidia.com/gpu:NoSchedule` taint. Node expiry: 720h. Consolidation: WhenEmpty after 300s.

## EC2 Quota

| Quota | Limit |
|-------|-------|
| Running On-Demand G and VT instances | **128 vCPUs** |
| Running On-Demand P instances | 0 vCPUs |

A `g6e.xlarge` uses 4 vCPUs → capacity for up to 32 concurrent GPU nodes within quota.

## JupyterHub

**Namespace:** `jupyterhub`

| Component | Status |
|-----------|--------|
| `hub` | Running (1/1) |
| `proxy` | Running (1/1) |
| `user-scheduler` | Running (2/2) |

**Load balancer:** `k8s-jupyterh-proxypub-23d5d8f25e-a3a54b8d6a723b9a.elb.us-west-2.amazonaws.com` (ports 80/443)

**Domain:** `jupyter.wandre.dev`

**Auth:** AWS Cognito via `GenericOAuthenticator` (Cognito hosted-UI prefix: `workshop-jhub-384484`)

## Container Image

- **Registry:** ECR — `384484506514.dkr.ecr.us-west-2.amazonaws.com/workshop/jupyter:v0.2`
- **Size:** ~4.1 GB
- **Pushed:** 2026-05-05

## Storage

| PVC | Size | Access | Storage Class | Mount |
|-----|------|--------|---------------|-------|
| `efs-persist` | 123 Gi | RWX | efs-sc-dynamic | `/home/{username}` (per-user) |
| `efs-persist-shared` | 123 Gi | RWX | efs-sc-dynamic | `/home/shared` (all users) |
| `hub-db-dir` | 50 Gi | RWO | gp3 | Hub SQLite DB |

---

## GKE vs AWS Gap Analysis

Reference GKE cluster: `csu-workshop-cluster` (us-central1, `vcm-ml` project)
Source of truth: `~/repos/workshop-gke/jupyter/AWS_MIGRATION_NOTES.md`

### Profiles

| Profile | GKE | AWS (current) | Status |
|---------|-----|---------------|--------|
| CPU (default) | n1-standard-4, 4/2 CPU, 16/8 GB | — | **MISSING** |
| T4 GPU (16 GB) | n1-standard-16, 8/4 CPU, 32/16 GB, 1× T4 | — | **MISSING** — no g4dn nodepool exists |
| L4 GPU (24 GB) | g2-standard-16, 8/4 CPU, 32/16 GB, 1× L4 | — | **MISSING from profile list** (g6-nvidia pool exists) |
| L40S GPU (46 GB) | — (AWS-only addition) | g6e.xlarge, 4/2 CPU, 32/16 GB, 1× L40S | Configured (only current profile) |

Action items:
1. Add CPU profile targeting `m6i-cpu` nodepool (make it default)
2. Add L4 profile targeting `g6-nvidia` nodepool (g6.xlarge, 8/4 CPU, 32/16 GB)
3. Add T4 profile — either add a `g4dn` Karpenter nodepool (T4) or substitute `g5` (A10G, same VRAM as L4)
4. Demote L40S to highest-tier / optional profile

### Storage

| Feature | GKE | AWS (current) | Status |
|---------|-----|---------------|--------|
| Per-user home | 50 Gi PVC per user at `claim-{username}` | 123 Gi EFS at `/{username}` | Functional (larger on AWS) |
| Shared data volume | GCSFuse → `vcm-jupyterhub-store` GCS bucket, mounted at `/data` | EFS shared at `/home/shared` | **PATH MISMATCH** — GKE uses `/data`, AWS uses `/home/shared` |
| `/dev/shm` (shared memory) | 8 Gi emptyDir `medium: Memory` at `/dev/shm` | Not configured | **MISSING — CRITICAL** |

`/dev/shm` note: Default Kubernetes `/dev/shm` is 64 MB. PyTorch DataLoader with `num_workers > 0` will crash or silently corrupt without the 8 GB tmpfs mount. This must be added to every singleuser pod.

Data volume note: The GCS bucket (`vcm-jupyterhub-store`) contains workshop data served by the ACE-Viz cors_proxy at `/data/`. The AWS equivalent is an S3 bucket mounted via the Mountpoint for S3 CSI driver at `/data`. This requires:
- Mountpoint for S3 CSI driver installed on the cluster
- An S3 bucket with workshop data
- `extraVolumes`/`extraVolumeMounts` in JupyterHub Helm values

### Notebook Image

| Component | GKE image v0.5.14 | AWS image v0.2 | Status |
|-----------|-------------------|----------------|--------|
| Base | `quay.io/jupyter/pytorch-notebook:cuda12-python-3.11` | Unknown | Verify |
| Code-Server | v4.117.0 (VS Code in browser) | Unknown | Verify |
| ACE-Viz | Next.js + 2 Go binaries (`aceviz-proxy`, `cors_proxy`) | Unknown | Verify |
| FME climate model | `ai2cm/ace` cloned at build time | Unknown | Verify |
| torch-harmonics | 0.8.0 (pinned) | Unknown | Verify |
| jupyter-server-proxy | v4.1+ | Unknown | Verify |
| ffmpeg, nodejs 20.x | Present | Unknown | Verify |

The GKE Dockerfile in the repo (`jupyter/modules/jupyter/jupyter_image/notebook_image/Dockerfile`) is only a placeholder (`FROM jupyter/tensorflow-notebook`). The real build for v0.5.14 is a multi-stage Docker build — source is in the `ai2cm/ace` or a separate private repo. Need to locate it.

### ACE-Viz Data Path

ACE-Viz's `cors_proxy` serves:
- `/data/` → the GCSFuse mount (GCS bucket)
- `/home/` → user home directory

On AWS, `/data/` needs to point to the S3 Mountpoint volume, not GCS. The proxy binary itself should not need changes — only the underlying mount target changes.

---

## What's Done

- [x] EKS cluster up and healthy (K8s 1.34)
- [x] Karpenter installed with GPU/CPU/Neuron node pools (all Ready)
- [x] JupyterHub deployed — hub + proxy running
- [x] Cognito auth configured (replaces GCP IAP)
- [x] EFS per-user and shared storage provisioned and bound
- [x] ECR image `v0.2` pushed (~4.1 GB)
- [x] G/VT quota raised to 128 vCPUs
- [x] HTTPS via ACM + NLB (replaces GCP managed cert + ingress)

## What's Pending

### High priority (blocks GPU spawning)
- [ ] **`/dev/shm` 8 GB tmpfs** — add `emptyDir medium: Memory sizeLimit: 8Gi` to JupyterHub Helm values
- [ ] **Profile list** — add CPU (default), L4, and T4/A10G profiles; demote L40S to optional tier
- [ ] **End-to-end GPU spawn test** — no user servers have launched yet

### Medium priority (feature parity)
- [ ] **S3 data mount at `/data`** — install Mountpoint for S3 CSI, create/populate S3 bucket, wire into Helm values
- [ ] **Image audit** — confirm v0.2 has Code-Server, ACE-Viz, FME model, torch-harmonics; rebuild as needed
- [ ] **T4 node pool** — decide: add `g4dn` Karpenter nodepool, or substitute `g5` (A10G) as the mid-tier GPU

### Lower priority
- [ ] Pre-puller evaluation (currently disabled; GKE had it enabled — adds startup latency vs. cold pull)
- [ ] Network policy review
- [ ] Verify IRSA permissions cover all required S3/ECR access
