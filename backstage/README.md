# Backstage — Snowflake request front end

Self-service UI for opening Snowflake provisioning request PRs against the
`snowflake-cicd` repo. Scaffolded with `@backstage/create-app`; the only addition
on top of the default app is the `snowflake-request` software template under
[`templates/snowflake-request/`](templates/snowflake-request/) and its
registration in [`app-config.yaml`](app-config.yaml) (`catalog.locations`).

## Prerequisites

- **Node 22 or 24** (pinned in `package.json` `engines`). This repo was built in
  an environment with Node 20, which is below that floor — install a matching
  Node version before running this app (e.g. via `nvm`/`fnm`).
- A **GitHub Personal Access Token** with `repo` scope, for opening PRs against
  `snowflake-cicd`. `app-config.yaml` reads it from `GITHUB_TOKEN`.

## Setup

```sh
cd backstage
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx   # PowerShell: $env:GITHUB_TOKEN = "ghp_..."

# Yarn is pinned via .yarnrc.yml (Yarn Berry 4.13.0) and vendored under .yarn/ —
# no global Yarn install needed, just invoke the pinned release directly:
node .yarn/releases/yarn-4.13.0.cjs install
node .yarn/releases/yarn-4.13.0.cjs start
```

Then open http://localhost:3000, go to **Create...**, and pick **Snowflake
Provisioning Request**. Fill in the team/name and the four Snowflake object names,
point the repository picker at your `snowflake-cicd` GitHub repo, and submit — it
opens a PR adding `requests/<team>/<name>.yaml`, which the `Terraform Plan` workflow
picks up automatically.

## What the template does

1. `fetch:template` renders
   [`templates/snowflake-request/content/`](templates/snowflake-request/content/)
   — a single YAML file matching the schema documented in the root
   [README.md](../README.md) — using the form values.
2. `publish:github:pull-request` opens a PR against the repo you pick, adding that
   rendered file at `requests/<team>/<name>.yaml`.

No new repo is created and nothing is registered in the Backstage catalog — this
template's only job is opening the request PR.
