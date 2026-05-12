#!/bin/bash
set -e

# Copy the shared base into _LOCAL
mkdir -p ./terraform/_LOCAL
cp -r ../base/terraform/* ./terraform/_LOCAL

# Apply workshop-specific overrides on top of the base
cp ./terraform/overrides/backend.tf \
   ./terraform/_LOCAL/backend.tf
cp ./terraform/overrides/cognito.tf \
   ./terraform/_LOCAL/cognito.tf
cp ./terraform/overrides/eks.tf \
   ./terraform/_LOCAL/eks.tf
cp ./terraform/overrides/helm-values/jupyterhub-values-cognito.yaml \
   ./terraform/_LOCAL/helm-values/jupyterhub-values-cognito.yaml
cp ./terraform/overrides/karpenter-resources/templates/nodepool.tpl \
   ./terraform/_LOCAL/karpenter-resources/templates/nodepool.tpl

echo "Ready. Run:"
echo "  cd terraform/_LOCAL"
echo "  ./deploy.sh bootstrap  # one-time: creates S3 state bucket"
echo "  ./deploy.sh init"
echo "  ./deploy.sh plan"
echo "  ./deploy.sh apply"
