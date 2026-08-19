# Handoff — Snowpipe provisioning

**Status:** Feature complete, proven end to end, and torn down. `terraform state list` is
empty — no provisioned resources remain in AWS or Snowflake. The repo is ready for the next
request YAML.

## What was built

An optional `snowpipe:` block in a request YAML provisions the whole S3 → Snowflake ingest
path: landing bucket, IAM role + read-only policy, storage integration, schema, landing
table, external stage, auto-ingest pipe, and the S3 event notification — alongside the
database/warehouse/roles a request already created. Requests without the block provision no
AWS resources.

## Proven end to end

A file dropped at `s3://projectx-landing-.../raw/sample.json` was ingested by
`PROJECTX_DB.RAW.EVENTS_PIPE` and both records landed in the table. Confirmed working:

- **The IAM ↔ storage-integration cycle break.** Terraform wrote the real Snowflake IAM user
  ARN and external ID into the role's trust policy from `describe_output`.
- **S3 → SQS → pipe → table.** The bucket notification points at Snowflake's own SQS queue
  (in account `652630300277`) with the `raw/` prefix filter.
- **The approval gate.** Applies park at `waiting` and require a reviewer click.
- OIDC auth with GitHub's immutable-ID subject format; S3 backend with native locking.

## Teardown (complete)

PR #7 removed `requests/product-team/projectx.yaml`; `for_each` dropped the key and all 23
resources were destroyed across both providers. The landing bucket was emptied by hand first,
since `force_destroy` is read from state at destroy time and so can't be added in the same PR
that triggers the destroy.

The destroy path is now proven, but it took two runs — the first failed on a missing
`iam:ListInstanceProfilesForRole`. See *Gotchas*.

An opt-in `force_destroy` variable (default `false`) is now on the snowpipe module for future
requests.

### What survives — all free or negligible

- State bucket `snowflake-cicd-tfstate-8681d5e4` (~15KB, versioned)
- IAM role `CICD_Terraform`, the GitHub OIDC provider
- GitHub secrets and the `snowflake-production` environment
- Snowflake role `CICD_PROVISIONER_ROLE` and user `TF_CICD_SVC_USER`

To rebuild, drop a new YAML into `requests/<team>/<name>.yaml` and open a PR.

## Still unproven

- **Backstage template** — parses and is structurally correct, but has never been rendered by
  a real scaffolder. Run one request through the form before trusting it.
- Only `file_format: JSON` has been used; CSV and PARQUET are untested.
- Only the default single-`VARIANT` table; explicit `columns:` untested.

## Reference

| | |
|---|---|
| AWS account / region | `002948695886` / `us-west-1` |
| CI role | `CICD_Terraform` (policy `CICD_TerraformPolicy`) |
| State | `s3://snowflake-cicd-tfstate-8681d5e4/snowflake-cicd/terraform.tfstate` |
| Backend config | `terraform/backend.hcl` (gitignored; see `backend.hcl.example`) |
| Secrets | `AWS_REGION`, `TF_STATE_BUCKET` are **secrets**, not variables |

## Gotchas learned the hard way

- **The CI role needs create *and* destroy permissions, and they differ.** Three separate
  pipeline failures came from an incomplete IAM list: `iam:ListRolePolicies` (read path),
  `s3:ListBucket` (create path), `iam:ListInstanceProfilesForRole` (delete path). The README
  now carries the full verified policy. Derive actions from each resource's whole CRUD
  surface and simulate them — don't add them as failures appear.
- **`s3:ListBucket` is not covered by `s3:Get*`.** Without it `aws_s3_bucket` hangs ~20min on
  the provider's `HeadBucket` readiness poll while the bucket plainly exists. Fixed on the CI
  role by adding `s3:List*`.
- **Breaking the IAM/integration cycle removes the ordering the pipe needs.** Because nothing
  in the Snowflake chain references `aws_iam_role`, Terraform builds them in parallel, and
  `CREATE PIPE` (which assumes the role) races IAM's eventual consistency.
  `time_sleep.iam_propagation` restores it. `CREATE STAGE` does *not* validate credentials, so
  it passes and hides the problem.
- **GitHub OIDC subjects carry immutable numeric IDs** —
  `repo:owner@648425/snowflake-cicd@1338611526:pull_request`. A name-only trust policy fails
  with an unhelpful `Not authorized to perform sts:AssumeRoleWithWebIdentity`. CloudTrail's
  `AssumeRoleWithWebIdentity` event shows the exact `sub` sent.
- `iam simulate-principal-policy` is only as good as the action list you feed it. Derive
  actions from each resource's CRUD path, not intuition.
- Workflow logs don't publish until a job ends — cancel a stuck run to see why it hung.
- Adding an environment protection rule does **not** bump the environment's `updated_at`.
- Local `aws` checks written as `... || echo "gone"` report deleted resources when the session
  has merely expired. Check `sts get-caller-identity` first.
