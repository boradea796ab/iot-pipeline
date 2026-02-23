# Terraform Bootstrap State Stack

This stack creates remote state infrastructure for Terraform:

- S3 state bucket with versioning, server-side encryption, lifecycle rules, and public access block
- Bucket policy to deny non-TLS access
- Optional DynamoDB lock table for state locking

## Usage

Create a `terraform.tfvars` file in this directory:

```hcl
aws_region               = "ap-northeast-1"
project_name             = "smart-meter-iot"
environment              = "shared"
state_bucket_name        = "smart-meter-iot-tfstate-<unique-suffix>"
enable_dynamodb_lock_table = true
```

Then run:

```bash
terraform init
terraform plan
terraform apply
```

After apply, use `backend_s3_example` output as a template for the main stack backend config.

## How this backend works

```text
                 (once)
      terraform/bootstrap/state
                apply
                   |
                   v
        +------------------------+
        |   S3 bucket (state)    |
        | terraform.tfstate file |
        | versioning + encryption|
        +------------------------+
                   ^
                   |
      +------------+------------+
      |                         |
dev laptop / CI runner A   dev laptop / CI runner B
terraform plan/apply       terraform plan/apply
      |                         |
      +-----------+-------------+
                  |
                  v
      +---------------------------+
      | DynamoDB lock table       |
      | LockID = state file lock  |
      +---------------------------+
```

### State maintenance flow

1. The bootstrap stack creates the shared S3 state bucket and optional DynamoDB lock table.
2. The main Terraform stack is configured to use backend `s3` with that bucket.
3. Before `plan`/`apply`, Terraform acquires a lock in DynamoDB.
4. If another run already holds the lock, a second run cannot write state at the same time.
5. After successful or failed execution, Terraform releases the lock.

### Why this helps

- Prevents state corruption from concurrent applies.
- Keeps one shared source of truth instead of local state drift.
- S3 versioning preserves state history for rollback and audit.
- Encryption and bucket policy harden state storage.
