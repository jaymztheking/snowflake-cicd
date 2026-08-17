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

## Repo layout

```
requests/<team>/<name>.yaml   # one file per request — see requests/example-team/example.yaml
terraform/                    # root config + modules/{database,warehouse,database_role,functional_role}
state/terraform.tfstate       # committed by the apply workflow — do not edit by hand
.github/workflows/            # terraform-plan.yml (PR), terraform-apply.yml (push to main)
backstage/                    # optional self-service UI that opens request PRs for you
```

## How a request works

Copy `requests/example-team/example.yaml` to `requests/<your-team>/<name>.yaml` and
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
    - privilege: USAGE
      on: DATABASE
    - privilege: CREATE SCHEMA
      on: DATABASE
functional_role:
  name: ANALYTICS_FUNCTIONAL_ROLE
  warehouse_usage: true
```

`terraform/main.tf` reads every `requests/**/*.yaml` file and `for_each`s the four
modules over them — one file is one fully self-contained request. The repo ships
with `requests/example-team/example.yaml` already in place, so the very first
merge to `main` will actually provision `EXAMPLE_DB` / `EXAMPLE_WH` / etc. as a
working demonstration; delete it once you've verified the pipeline.

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

### 2. GitHub: add secrets

Repo Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `SNOWFLAKE_ORGANIZATION_NAME` | Your Snowflake organization name |
| `SNOWFLAKE_ACCOUNT_NAME` | Your Snowflake account name |
| `SNOWFLAKE_USER` | `TF_CICD_SVC_USER` |
| `SNOWFLAKE_PRIVATE_KEY` | Full contents of `snowflake_tf_key.p8` |
| `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` | Only if you encrypted the key (omit `-nocrypt` above) |

### 3. GitHub: create the protected environment

Repo Settings → Environments → New environment → name it `snowflake-production` →
add yourself (or another maintainer) as a required reviewer. This is what makes
the apply job pause for approval after every merge.

**Note:** required reviewers on environments are free only on **public** repos;
private repos need GitHub Team/Enterprise. This repo is public specifically so
this stays free.

**Branch protection note:** the apply workflow pushes the updated
`state/terraform.tfstate` straight to `main` after every apply. If you add branch
protection rules to `main`, make sure they allow `github-actions[bot]` to push
(e.g. exclude it from "restrict who can push," or the state commit will fail).

## Local development

```bash
cd terraform
terraform init
terraform validate
terraform plan   # requires the SNOWFLAKE_* env vars set locally
```

## Backstage (self-service front end)

`backstage/` is a standard Backstage app (via `@backstage/create-app`) with a
`snowflake-request` software template that fills in a request YAML from a form and
opens the PR for you via the built-in `publish:github:pull-request` scaffolder
action. See [backstage/README.md](backstage/README.md) for setup — it runs locally
(`yarn start`) with no hosting cost.

## Cost

Everything here is free at POC scale: GitHub Actions and environment protection
are free on public repos, Terraform and its Snowflake provider are open source,
state is committed in-repo (no external backend account), and Backstage runs
locally. The only real dollar cost is Snowflake compute — the warehouse defaults
to `XSMALL` with a 60-second auto-suspend to keep credit usage minimal.
