# Environment layout

This repository keeps one Terraform root module in `terraform/` and separates environment values under `terraform/envs/`.

## Files

- `common.tfvars`: shared values across all environments
- `dev/terraform.tfvars`, `stage/terraform.tfvars`, `prod/terraform.tfvars`: environment-specific overrides
- `dev/backend.hcl.example`, `stage/backend.hcl.example`, `prod/backend.hcl.example`: backend templates with environment-specific state keys

## Usage

From `terraform/`, choose environment and run:

```bash
ENV=dev
cp "envs/${ENV}/backend.hcl.example" "envs/${ENV}/backend.hcl"
# edit envs/${ENV}/backend.hcl with real bucket and lock table values

terraform init -backend-config="envs/${ENV}/backend.hcl"
terraform plan \
  -var-file="envs/common.tfvars" \
  -var-file="envs/${ENV}/terraform.tfvars"
terraform apply \
  -var-file="envs/common.tfvars" \
  -var-file="envs/${ENV}/terraform.tfvars"
```

Use `ENV=stage` and `ENV=prod` for higher environments.
