# Design decisions: Kubernetes GitOps Platform

### 1. k3s on one EC2 instance instead of EKS
- **Why:** the EKS control plane costs about $73 a month before nodes. k3s is CNCF-certified Kubernetes, so manifests, Helm, Argo CD and Kyverno behave the same. The README lists what changes on EKS.

### 2. Argo CD with automated sync, prune and self-heal
- **Why:** pull-based GitOps: the cluster pulls from Git, so CI never needs cluster credentials. Self-heal undoes drift; prune removes resources deleted from Git.
- **Alternative:** Flux, equally valid.

### 3. Sync waves: policies before workloads
- **Why:** the guardrails must exist before anything they should check is created.

### 4. Kyverno instead of OPA Gatekeeper
- **Why:** policies are plain Kubernetes YAML, easier to read and test with the Kyverno CLI. Gatekeeper uses Rego, more powerful but steeper.

### 5. Defense in depth for the workload
- Pod Security `restricted` label on the namespace, Kyverno policies, a hardened pod spec (non-root, read-only root, drop ALL, seccomp RuntimeDefault, no service account token), default-deny NetworkPolicy.

### 6. HPA plus PDB
- **Why:** HPA scales on CPU (k3s ships metrics-server); PDB keeps at least one pod during voluntary disruptions like node drains.

### 7. SSM Session Manager instead of SSH
- **Why:** no inbound ports, no SSH keys, IAM-controlled and logged sessions.

### 8. IMDSv2 required, hop limit 1
- **Why:** blocks the classic SSRF path to instance credentials and stops pods from reaching the node's metadata.

### 9. Public subnet for egress only
- **Why:** cheaper than NAT; the security group has no inbound rules, so a public IP alone exposes nothing.
