## Terraform usage

Always tell Terraform which AWS region to use so it talks to the same region where the IoT stack was provisioned. The IoT Core APIs that manage certificates/policy attachments are region-scoped, so running `terraform destroy` with the wrong region (for example defaulting to `us-east-1` while the certificate lives in `ap-northeast-1`) produces `InvalidRequestException: Invalid Target` errors while reading `aws_iot_policy_attachment` resources.

You can provide the region by:

- exporting an environment variable before running Terraform:

  ```bash
  export TF_VAR_aws_region=ap-northeast-1
  ```

- or creating a `terraform.tfvars` file in this directory:

  ```hcl
  aws_region = "ap-northeast-1"
  ```

Make sure the same value is used for every `terraform apply`/`destroy` so Terraform can read and delete the existing IoT resources without errors.
