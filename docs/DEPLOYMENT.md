# Deployment Guide: GitHub Actions → Azure (OIDC)

This guide covers the **one-time setup** required so that pushing to `main`
automatically deploys this Function App to Azure — with no client secrets,
publish profiles, or passwords stored anywhere in GitHub.

## Why OIDC instead of a publish profile or service principal secret?

| Method | Secrets stored in GitHub? | Expires / needs rotation? |
|---|---|---|
| Publish profile | Yes (contains a password) | Yes, manually |
| Service principal + client secret | Yes | Yes, typically every 6–24 months |
| **OIDC (federated credential)** | **No** — only non-secret IDs | No — tokens are minted per-run and expire in minutes |

With OIDC, GitHub's OIDC provider issues a short-lived JSON Web Token to the
workflow run. Azure trusts that token because you've configured a
**federated credential** that says "trust tokens from this specific GitHub
repo/branch/environment." No long-lived secret ever has to be generated,
stored, or rotated. This is Microsoft's documented recommended approach for
`azure/login` and `Azure/functions-action`.

## Overview of the one-time setup

1. Create (or reuse) an Azure resource group and deploy the Function App (see [docs/INFRASTRUCTURE.md](INFRASTRUCTURE.md) if you haven't done this yet).
2. Create a Microsoft Entra **app registration** (an identity GitHub will authenticate as).
3. Create a **federated credential** on that app registration that trusts this specific GitHub repo.
4. Grant that app registration the **Contributor** role, scoped to just the resource group containing the Function App.
5. Create a **GitHub Environment** named `production` (matches the workflow).
6. Add three **repository secrets** and one **repository variable** in GitHub.
7. Push to `main` and watch it deploy.

---

## Step 1: Gather your Azure IDs

```bash
az login

# Note your subscription ID
az account show --query id -o tsv

# Note your tenant ID
az account show --query tenantId -o tsv
```

## Step 2: Create the Entra app registration

```bash
az ad app create --display-name "github-actions-<your-repo-name>-deploy"
```

From the output, note the `appId` — this is your **Client ID**. Then create
a service principal for that app (required before role assignment):

```bash
APP_ID="<paste-the-appId-here>"
az ad sp create --id "$APP_ID"
```

## Step 3: Create the federated credential

This tells Azure: "trust GitHub OIDC tokens that come specifically from this
repo's `production` environment." Replace `<OWNER>/<REPO>` with your actual
GitHub org/user and repository name.

```bash
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-production-environment",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<OWNER>/<REPO>:environment:production",
    "description": "GitHub Actions - production environment deploys",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

> **Why `environment:production` and not `ref:refs/heads/main`?** The
> included `deploy.yml` workflow's `deploy` job specifies
> `environment: production`. The federated credential's `subject` claim must
> exactly match how the job that calls `azure/login` is configured. If you
> remove the `environment: production` line from the workflow, use
> `"subject": "repo:<OWNER>/<REPO>:ref:refs/heads/main"` instead.

If you also want pull requests to be able to authenticate (e.g., for a
plan/validate-only job that needs Azure read access), you can add a second
federated credential with `"subject": "repo:<OWNER>/<REPO>:pull_request"`.
The included `validate-pr.yml` does **not** require this — it never logs into
Azure — but it's documented here in case you extend it later.

## Step 4: Grant Contributor on the resource group only

Scope the role assignment as narrowly as possible — to the resource group
containing the Function App, not the whole subscription.

```bash
SUBSCRIPTION_ID="<your-subscription-id>"
RESOURCE_GROUP="rg-myfunction"

az role assignment create \
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
```

## Step 5: Create the `production` GitHub Environment

In your GitHub repo: **Settings → Environments → New environment**, name it
`production`. This must match exactly what's in `deploy.yml` and in the
federated credential subject from Step 3.

Optionally, add a required reviewer here if you want a manual approval gate
before every deployment.

## Step 6: Add GitHub secrets and variables

In your GitHub repo: **Settings → Secrets and variables → Actions**.

Under **Secrets** (these are IDs, not passwords, but GitHub secrets are still
the right place for them since they shouldn't appear in logs):

| Secret name | Value |
|---|---|
| `AZURE_CLIENT_ID` | The `appId` from Step 2 |
| `AZURE_TENANT_ID` | Your tenant ID from Step 1 |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID from Step 1 |

Under **Variables**:

| Variable name | Value |
|---|---|
| `AZURE_FUNCTIONAPP_NAME` | The exact name of your deployed Function App (e.g., what you passed as `functionAppName` in Step 1 of infra setup) |

> Secrets vs. variables: none of these four values are actually secret in
> the traditional sense (you couldn't authenticate with just a client ID),
> but `AZURE_FUNCTIONAPP_NAME` is the only one that's genuinely fine to be
> visible in logs, so it's a variable, while the three IDs are stored as
> secrets to avoid them showing up in workflow run logs.

## Step 7: Deploy

Push a commit to `main`, or trigger manually from the **Actions** tab using
the **"Run workflow"** button (the workflow has `workflow_dispatch` enabled).

The pipeline (`.github/workflows/deploy.yml`) does the following:

1. **`build` job:** checks out the repo, validates `host.json` exists, runs
   Pester tests if `tests/` exists, and packages everything (excluding `.git`,
   `.github`, `.vscode`, `tests`, `docs`) into an artifact.
2. **`deploy` job:** downloads that artifact, authenticates to Azure via
   OIDC (`azure/login@v2` using the three secrets), then deploys using
   `Azure/functions-action@v1`.

Watch progress under the **Actions** tab in GitHub. On success, your function
will be live at:

```
https://<your-function-app-name>.azurewebsites.net/api/HttpExample
```

## Calling the deployed function

Unlike local testing, the deployed function enforces its `authLevel:
"function"` setting, so requests need a function key:

```bash
# Get the default function key
az functionapp function keys list \
  --resource-group rg-myfunction \
  --name <your-function-app-name> \
  --function-name HttpExample \
  --query default -o tsv
```

```bash
curl "https://<your-function-app-name>.azurewebsites.net/api/HttpExample?Name=World&code=<the-key-from-above>"
```

## Rolling back

GitHub Actions doesn't automatically version Azure deployments for you. To
roll back:

- **Quick fix:** revert the offending commit on `main` and let the pipeline
  redeploy the previous code.
- **Azure-native:** if you enable deployment slots (not included in this
  starter's Bicep template, since slots aren't available on the Consumption
  plan — they require Premium or Dedicated plans), you can swap slots
  instead.

## Extending this pipeline

Common next steps people add:

- A **staging** environment/slot with its own federated credential subject (`environment:staging`) that deploys on every push to a `develop` branch, promoting to `production` only on merge to `main`.
- Required PR reviews and status checks (`validate-pr.yml` passing) before merge, configured under **Settings → Branches → Branch protection rules**.
- Slack/Teams notifications on deployment success/failure using a notification action step.

See [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) if the workflow fails.
