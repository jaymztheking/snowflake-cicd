# Handoff — Snowpipe provisioning

**Status:** 12 of 14 Snowpipe resources are applied and tracked in state. Two remain:
`snowflake_pipe` and `aws_s3_bucket_notification`. The bug that blocked them is fixed in
code but **not yet applied** — it needs a PR, plan review, merge, and approval.

## Where the last apply got to

Run `32210642200` (2026-08-19) applied everything except the pipe, then failed:

```
Error: 003167 (42601): Error assuming AWS_ROLE:
User: arn:aws:iam::652630300277:user/pnh3-s-p2st1272 is not authorized to perform:
sts:AssumeRole on resource: arn:aws:iam::002948695886:role/SNOWFLAKE_PROJECTX_ROLE
  with module.snowpipe["product-team/projectx"].snowflake_pipe.this
```

State **was** written (unlike the earlier cancelled run) — no orphans, lock released.
Nothing to clean up.

### Root cause

Two compounding issues:

1. **No dependency between the Snowflake objects and the IAM role.** The cycle-breaking
   trick (building the role ARN as a string so the storage integration doesn't reference
   `aws_iam_role`) means nothing downstream depends on the role either. Terraform built
   them in parallel.
2. **IAM is eventually consistent.** `CREATE STAGE` doesn't validate credentials, so it
   passed. `CREATE PIPE` with `AUTO_INGEST` *does* assume the role — 4 seconds after the
   trust policy was written.

### Fix (in the working tree, uncommitted)

`time_sleep.iam_propagation` in `terraform/modules/snowpipe/main.tf`: depends on
`aws_iam_role_policy.s3_read`, and `snowflake_pipe` depends on it. Default `60s`, tunable
via `iam_propagation_delay`. Adds `hashicorp/time` to both `providers.tf` and the module's
`versions.tf`; lock file updated for `linux_amd64` + `darwin_arm64`.

## Next steps

1. Branch off `main`, commit the working-tree changes, open a PR.
2. **Review the plan carefully.** Expect **2 to add** (`snowflake_pipe`,
   `aws_s3_bucket_notification`) plus `time_sleep.iam_propagation`, and **0 to change /
   0 to destroy**. If it wants to replace the stage, integration, or role, stop — adding
   `depends_on` should not force replacement.
3. Merge, approve the `snowflake-production` gate, apply. Expect ~60s (the sleep).
4. Smoke test:
   ```bash
   aws s3 cp sample.json s3://projectx-landing-002948695886/raw/sample.json
   ```
   ```sql
   SELECT SYSTEM$VALIDATE_STORAGE_INTEGRATION('PROJECTX_DB_RAW_INT',
          's3://projectx-landing-002948695886/raw/', 'sample.json', 'read');
   SELECT SYSTEM$PIPE_STATUS('PROJECTX_DB.RAW.EVENTS_PIPE');  -- expect RUNNING
   SELECT * FROM PROJECTX_DB.RAW.EVENTS;
   ```

## Verified working — do not re-litigate

- **The IAM ↔ integration cycle break.** Terraform wrote the real Snowflake IAM user ARN
  (`arn:aws:iam::652630300277:user/pnh3-s-p2st1272`) and external ID into the trust policy
  from `describe_output`. Correct values, no cycle.
- **All Snowflake objects create in 1–3s**: integration, schema, table, external stage
  (accepted *with* the storage integration), 3 grants.
- **S3 + IAM**: bucket, public access block, SSE, and the `s3_read` inline policy all apply
  cleanly now that `s3:List*` is on the CI role.
- **OIDC** with GitHub's immutable-ID subject format.
- **The approval gate works** — run `32210642200` parked at `waiting` and required a
  reviewer click. Confirmed with an email + approval screen.

## Still unproven

- `snowflake_pipe` create path — failed both attempts, for different reasons.
- `aws_s3_bucket_notification` — never attempted. It's the only resource depending on
  Snowflake's SQS queue policy accepting the bucket.
- End-to-end ingest (file → SQS → pipe → table).
- **Backstage template** — parses, never rendered by a real scaffolder.

## Reference

| | |
|---|---|
| AWS account / region | `002948695886` / `us-west-1` |
| CI role | `CICD_Terraform` (policy `CICD_TerraformPolicy`) |
| State | `s3://snowflake-cicd-tfstate-8681d5e4/snowflake-cicd/terraform.tfstate` |
| Backend config | `terraform/backend.hcl` (gitignored; see `backend.hcl.example`) |
| Secrets | `AWS_REGION`, `TF_STATE_BUCKET` are **secrets**, not variables |
| Landing bucket | `projectx-landing-002948695886` |

## Gotchas learned the hard way

- `s3:ListBucket` is **not** covered by `s3:Get*`. Without it, `aws_s3_bucket` hangs ~20min
  on the provider's `HeadBucket` readiness poll while the bucket plainly exists. Already
  fixed on the CI role.
- `iam simulate-principal-policy` is only as good as the action list you feed it. Derive
  actions from each resource's CRUD path, not intuition.
- Workflow logs don't publish until a job ends — cancel a stuck run to see why it hung.
- Adding an environment protection rule does **not** bump the environment's `updated_at`.
- Local `aws` checks written as `... || echo "gone"` will report deleted resources when the
  session has merely expired. Check `sts get-caller-identity` first.
