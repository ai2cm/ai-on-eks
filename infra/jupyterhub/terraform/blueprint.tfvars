name                       = "workshop-jhub"
region                     = "us-west-2"
enable_aws_efs_csi_driver  = true
enable_jupyterhub          = true
enable_external_dns        = true

# Auth
jupyter_hub_auth_mechanism = "cognito"
cognito_custom_domain      = "workshop-jhub-384484"  # globally unique Cognito hosted-UI prefix
jupyterhub_domain          = "jupyter.wandre.dev"
acm_certificate_domain     = "jupyter.wandre.dev"    # must match Route53 zone name exactly

huggingface_token          = "DUMMY_TOKEN_REPLACE_ME"
# eks_cluster_version       = "1.34"

# -------------------------------------------------------------------------------------
# EKS Addons Configuration
#
# These are the EKS Cluster Addons managed by Terraform stack.
# You can enable or disable any addon by setting the value to `true` or `false`.
#
# If you need to add a new addon that isn't listed here:
# 1. Add the addon name to the `enable_cluster_addons` variable in `base/terraform/variables.tf`
# 2. Update the `locals.cluster_addons` logic in `eks.tf` to include any required configuration
#
# -------------------------------------------------------------------------------------

# enable_cluster_addons = {
#   coredns                         = true
#   kube-proxy                      = true
#   vpc-cni                         = true
#   eks-pod-identity-agent          = true
#   aws-ebs-csi-driver              = true
#   metrics-server                  = true
#   eks-node-monitoring-agent       = false
#   amazon-cloudwatch-observability = true
# }
