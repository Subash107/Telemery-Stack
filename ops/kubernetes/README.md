# Kubernetes

This directory contains a repo-managed Kubernetes deployment for the BBP mock
API and the simulation pipeline.

## What This Layout Does

- runs the mock API as a long-lived `Deployment`
- exposes the mock API over HTTP and gRPC through one `Service`
- runs the simulation workflow as a batch `Job`
- keeps local dev access separate from Docker Compose by using host ports
  `28080` for HTTP and `25061` for gRPC on the kind cluster

The layout uses Kustomize, so you deploy it with `kubectl apply -k`.

## Structure

- `base/`: transport-agnostic Kubernetes resources
- `overlays/kind/`: local kind overlay with dev credentials and NodePort access
- `overlays/k3s/`: Kali VM k3s overlay with the same service shape and credentials
- `kind/cluster.yaml`: kind cluster definition with host port mappings

## Local Kind Workflow

1. Build the project images:

```bash
docker compose -f docker-compose.yml build
```

2. Create the cluster:

```bash
kind create cluster --config ops/kubernetes/kind/cluster.yaml
```

3. Load the local images into kind:

```bash
kind load docker-image bbp_final_pro_framework-mock-api:latest --name bbp-dev
kind load docker-image bbp_final_pro_framework-pipeline:latest --name bbp-dev
```

4. Apply the manifests:

```bash
kubectl apply -k ops/kubernetes/overlays/kind
```

5. Verify:

```bash
kubectl get all -n bbp-dev
kubectl logs -n bbp-dev deployment/bbp-mock-api
kubectl logs -n bbp-dev job/bbp-pipeline-simulation
```

HTTP and gRPC from your host:

- HTTP health: `http://127.0.0.1:28080/mock-six-api/health`
- gRPC target: `127.0.0.1:25061`

## Re-running The Pipeline Job

The simulation is modeled as a `Job`, so to run it again:

```bash
kubectl delete job -n bbp-dev bbp-pipeline-simulation
kubectl apply -k ops/kubernetes/overlays/kind
```

## Notes About Kali

Your Kali VM currently has Docker available but no Kubernetes runtime or CLI:

- no `kubectl`
- no `k3s`
- no `microk8s`
- no `kind`
- no `minikube`

That means the cleanest professional dev path today is:

- use Docker Compose for local containerized checks
- use the local kind cluster from this machine for Kubernetes validation

If you later want a dedicated Kubernetes runtime on Kali, `k3s` is the most
practical next step for that VM.
