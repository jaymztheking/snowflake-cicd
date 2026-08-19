# Snowflake Provisioning POC

A pull request provisions Snowflake infrastructure. Add a request YAML file under
`requests/`, open a PR, and:

1. **On PR open/update** — GitHub Actions runs `terraform plan` and comments the
   plan on the PR.
2. **On merge to `main`** — GitHub Actions runs `terraform apply`, but the job is
   gated behind a required-reviewer approval on the `snowflake-production`
   environment, so nothing is created until someone approves the run.

Each request provisions a **database**, a **warehouse**, a **database role**
(scoped to that database, with configurable grants), and a **functional role**
(an account-level role that gets the database role plus warehouse `USAGE`).

A request can optionally add a **Snowpipe ingest path** — an S3 landing bucket, the
IAM role and policy Snowflake assumes to read it, a storage integration, and a
schema / landing table / external stage / auto-ingest pipe, wired together with an
S3 event notification. See [Snowpipe ingest](#snowpipe-ingest).

## Repo layout

```
requests/<team>/<name>.yaml   # one file per request — see requests/product-team/projectx.yaml
terraform/                    # root config + modules/{database,warehouse,database_role,functional_role,snowpipe}
.github/workflows/            # terraform-plan.yml (PR), terraform-apply.yml (push to main)
backstage/                    # optional self-service UI that opens request PRs for you
```

## How a request works

Copy `requests/product-team/projectx.yaml` to `requests/<your-team>/<name>.yaml` and
fill in:

```yaml
team: analytics
name: analytics
database:
  name: ANALYTICS_DB
  comment: "Analytics team database"
warehouse:
  name: ANALYTICS_WH
  size: XSMALL
  auto_suspend: 60
  auto_resume: true
database_role:
  name: ANALYTICS_DB_ROLE
  grants:
    # "on" must stay quoted -- unquoted, YAML parses it as boolean true.
    - privilege: USAGE
      "on": DATABASE
    - privilege: CREATE SCHEMA
      "on": DATABASE
functional_role:
  name: ANALYTICS_FUNCTIONAL_ROLE
  warehouse_usage: true
```

`terraform/main.tf` reads every `requests/**/*.yaml` file and `for_each`s the
modules over them — one file is one fully self-contained request.

### Snowpipe ingest

Adding an optional `snowpipe:` block to a request provisions the whole S3 → Snowflake
ingest path alongside the objects above. Requests without the block provision no AWS
resources at all.

```yaml
snowpipe:
  bucket_prefix: analytics-landing  # bucket becomes <prefix>-<aws account id>
  path: raw/                        # key prefix Snowpipe watches; omit for the whole bucket
  iam_role_name: SNOWFLAKE_ANALYTICS_ROLE
  file_format: JSON                 # JSON | CSV | PARQUET
  schema:
    name: RAW
  table:
    name: EVENTS
    # columns is optional -- omitted, the table gets a single VARIANT column named RAW.
    # columns:
    #   - name: EVENT_ID
    #     type: VARCHAR
  stage:
    name: EVENTS_STAGE
  pipe:
    name: EVENTS_PIPE
```

Bucket names are globally unique across all of AWS, so the account ID is appended to
`bucket_prefix` automatically. The bucket is created private (public access blocked,
SSE-S3 on), and the IAM role is scoped to read-only access on `path` only.

The request's database role is also granted `USAGE` on the schema, `READ` on the stage,
and `SELECT`/`INSERT` on the table, so the requesting team can actually use what was
provisioned.

**How the IAM trust is established.** Snowflake generates the IAM user ARN and external
ID *after* the storage integration exists, but the integration needs the IAM role ARN up
front — a circular dependency. `modules/snowpipe/main.tf` breaks it by building the role
ARN as a string from the account ID rather than referencing `aws_iam_role`, so the trust
policy can depend on the integration without a cycle. Snowflake doesn't verify the role
until the stage is first used, by which point the role exists.

**Preview resources.** `snowflake_pipe` and `snowflake_table` are still preview features
in the Snowflake provider and are opted into by name in `terraform/providers.tf`. The
provider warns that they may change without a major version bump; the `~> 2.19`
constraint and the committed lock file limit the exposure.

## One-time setup

### 1. Snowflake: create the automation user

Run this in Snowflake as an admin (`ACCOUNTADMIN` or similar). Generate an RSA key
pair locally first:

```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out snowflake_tf_key.p8 -nocrypt
openssl rsa -in snowflake_tf_key.p8 -pubout -out snowflake_tf_key.pub
```

```sql
CREATE ROLE IF NOT EXISTS CICD_PROVISIONER_ROLE;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE CICD_PROVISIONER_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE CICD_PROVISIONER_ROLE;
GRANT CREATE ROLE ON ACCOUNT TO ROLE CICD_PROVISIONER_ROLE;
-- Only needed for Snowpipe requests. Must be run as ACCOUNTADMIN.
GRANT CREATE INTEGRATION ON ACCOUNT TO ROLE CICD_PROVISIONER_ROLE;
GRANT ROLE CICD_PROVISIONER_ROLE TO ROLE SYSADMIN;

CREATE USER IF NOT EXISTS TF_CICD_SVC_USER
  RSA_PUBLIC_KEY = '<paste the contents of snowflake_tf_key.pub, header/footer stripped>'
  DEFAULT_ROLE = CICD_PROVISIONER_ROLE
  MUST_CHANGE_PASSWORD = FALSE;
GRANT ROLE CICD_PROVISIONER_ROLE TO USER TF_CICD_SVC_USER;
```

Privileges above cover creating the objects this repo provisions. If a specific
grant (e.g. granting a database role to an account role) needs `MANAGE GRANTS`
depending on your account edition, add it — the first real `apply` will tell you.

### 2. AWS: create the OIDC provider and provisioning role

Only needed if you plan to use `snowpipe:` blocks. The workflows authenticate to AWS
with GitHub's OIDC token rather than long-lived access keys, so there is no AWS secret
to rotate.

First, register GitHub as an OIDC identity provider (once per AWS account):

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Then create a role Terraform assumes, trusting only this repo:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike": { "token.actions.githubusercontent.com:sub": "repo:<owner>@<owner-id>/snowflake-cicd@<repo-id>:*" }
    }
  }]
}
```

Create a private, versioned bucket to hold Terraform state:

```bash
aws s3api create-bucket --bucket <your-state-bucket> --region <region>
aws s3api put-bucket-versioning --bucket <your-state-bucket> \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket <your-state-bucket> \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Versioning matters: it's your undo button if a state write goes wrong.

GitHub now issues OIDC subjects containing **immutable numeric IDs**, not just names —
`repo:owner@648425/snowflake-cicd@1338611526:pull_request`, not
`repo:owner/snowflake-cicd:pull_request`. A trust policy written against the old
name-only format silently fails to match, and `configure-aws-credentials` reports only
`Not authorized to perform sts:AssumeRoleWithWebIdentity`. Get your IDs with:

```bash
gh api repos/<owner>/snowflake-cicd --jq '{repo_id: .id, owner_id: .owner.id}'
```

If a run still fails to assume the role, CloudTrail's `AssumeRoleWithWebIdentity` event
shows the exact `sub` GitHub sent, which is the fastest way to see what to match.

Attach a permissions policy allowing the role to manage the resources this repo creates:
`s3:CreateBucket`, `s3:DeleteBucket`, `s3:Get*`/`s3:Put*` on bucket configuration and
notifications, plus `iam:CreateRole`, `iam:DeleteRole`, `iam:GetRole`, `iam:UpdateAssumeRolePolicy`,
`iam:PutRolePolicy`, `iam:DeleteRolePolicy`, `iam:GetRolePolicy`, `iam:TagRole`, and
`sts:GetCallerIdentity`. Scope it to your naming convention rather than `Resource: "*"`
if you can.

The role also needs `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` on
`arn:aws:s3:::<your-state-bucket>/*` plus `s3:ListBucket` on the bucket itself, so it can
read and lock state.

### 3. GitHub: add secrets and variables

Repo Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `SNOWFLAKE_ORGANIZATION_NAME` | Your Snowflake organization name |
| `SNOWFLAKE_ACCOUNT_NAME` | Your Snowflake account name |
| `SNOWFLAKE_USER` | `TF_CICD_SVC_USER` |
| `SNOWFLAKE_PRIVATE_KEY` | Full contents of `snowflake_tf_key.p8` |
| `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` | Only if you encrypted the key (omit `-nocrypt` above) |
| `AWS_TF_ROLE_ARN` | ARN of the role created in step 2 |
| `AWS_REGION` | Region for state and landing buckets, e.g. `us-west-1` |
| `TF_STATE_BUCKET` | The state bucket created in step 2 |

`AWS_REGION` and `TF_STATE_BUCKET` aren't sensitive in themselves, but they're stored as
secrets rather than variables so GitHub masks them in workflow logs — which are public on
a public repo.

### 4. GitHub: create the protected environment

Repo Settings → Environments → New environment → name it `snowflake-production` →
add yourself (or another maintainer) as a required reviewer. This is what makes
the apply job pause for approval after every merge.

**Note:** required reviewers on environments are free only on **public** repos;
private repos need GitHub Team/Enterprise. This repo is public specifically so
this stays free.

Because state now lives in S3, the apply workflow no longer pushes to `main` and runs
with `contents: read`. Branch protection rules need no special allowance for
`github-actions[bot]`.

## Local development

```bash
cd terraform
cp backend.hcl.example backend.hcl   # fill in your state bucket and region
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan   # requires the SNOWFLAKE_* env vars and AWS credentials
```

`backend.hcl` is gitignored. `terraform validate` runs without credentials and is the
fastest check that a request YAML and the module wiring are sound.

## Backstage (self-service front end)

`backstage/` is a standard Backstage app (via `@backstage/create-app`) with a
`snowflake-request` software template that fills in a request YAML from a form and
opens the PR for you via the built-in `publish:github:pull-request` scaffolder
action. See [backstage/README.md](backstage/README.md) for setup — it runs locally
(`yarn start`) with no hosting cost.

## Verifying a Snowpipe request

After the apply is approved, `terraform output snowpipe` prints the bucket, stage,
pipe, and SQS notification channel for each request. Drop a file and check it lands:

```bash
aws s3 cp sample.json s3://<bucket>/raw/sample.json
```

```sql
-- confirms the IAM trust policy resolved correctly
SELECT SYSTEM$VALIDATE_STORAGE_INTEGRATION('<INTEGRATION>', 's3://<bucket>/raw/', 'sample.json', 'read');
-- confirms the SQS notification wiring; expect executionState RUNNING
SELECT SYSTEM$PIPE_STATUS('PROJECTX_DB.RAW.EVENTS_PIPE');
-- the row should appear within about a minute
SELECT * FROM PROJECTX_DB.RAW.EVENTS;
```

## Cost

Everything here is free at POC scale: GitHub Actions and environment protection
are free on public repos, Terraform and its Snowflake provider are open source,
state is committed in-repo (no external backend account), and Backstage runs
locally. The real dollar costs are Snowflake compute — the warehouse defaults
to `XSMALL` with a 60-second auto-suspend to keep credit usage minimal — and, for
Snowpipe requests, S3 storage/requests plus Snowflake's per-file Snowpipe charge.
Both are negligible for a POC but are not zero.

## Terraform state

State lives in a private S3 bucket, configured in `terraform/backend.tf` as a *partial*
backend — the bucket and region are passed at `init` time so this public repo never
names the state location. Locking uses the S3 backend's native `use_lockfile` (Terraform
1.10+), so there's no DynamoDB table to run.

State is **not** committed to this repo, and that's deliberate. Snowpipe state contains
your AWS account ID, bucket names, IAM role ARNs, and — most importantly — the storage
integration's **external ID**. That external ID is the only thing in the IAM trust policy
that distinguishes your account from every other Snowflake tenant (the Snowflake IAM user
ARN is shared region-wide), so it's the one value that genuinely shouldn't be published.

Earlier versions of this repo committed state to `state/terraform.tfstate`. That was safe
only because pre-Snowpipe state held nothing but object names.
