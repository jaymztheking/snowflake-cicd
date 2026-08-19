# Handoff — Snowpipe provisioning

**Status:** Feature complete and proven end to end. The `product-team/projectx` request is
being decommissioned to avoid standing cost — see *Teardown in progress* below.

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

## Teardown in progress

Branch `chore/teardown-projectx` (PR open) removes `requests/product-team/projectx.yaml`.
`for_each` drops the key, so the plan destroys all 14 Snowpipe resources plus the database,
warehouse, and roles. The landing bucket was emptied by hand first.

Same PR adds an opt-in `force_destroy` variable to the snowpipe module (default `false`) so
future teardowns don't wedge on `BucketNotEmpty`. Note it does **not** help this teardown —
`force_destroy` is read from state at destroy time, so it must be applied *before* the
destroy, not in the same PR.

### After the teardown applies

Nothing is left with a standing cost. What survives, all free or negligible:

- State bucket `snowflake-cicd-tfstate-8681d5e4` (~15KB, versioned)
- IAM role `CICD_Terraform`, the GitHub OIDC provider
- GitHub secrets and the `snowflake-production` environment
- Snowflake role `CICD_PROVISIONER_ROLE` and user `TF_CICD_SVC_USER`

To rebuild, drop a new YAML into `requests/<team>/<name>.yaml` and open a PR.

## Still unproven

- **Backstage template** — parses and is structurally correct, but has never been rendered by
  a real scaffolder. Run one request through the form before trusting it.
- **Destroy path** — being exercised for the first time by this teardown.
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
