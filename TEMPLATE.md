# Using This Template

This is a GitHub template repository for an Azure Function written in
PowerShell. Click **"Use this template"** at the top of the repo page to
generate a new, independent repository from it — fresh history, no link
back to this one, fully yours to diverge from immediately.

This document is the only thing you need to read to go from "I just
generated a new repo from this" to "it's deploying to Azure on every push
to `main`."

---

## What this template gives you

- A working HTTP-triggered PowerShell function (`HttpExample/`)
- Local testing via Azure Functions Core Tools + Pester unit tests
- Infrastructure-as-code (Bicep) to provision the Azure resources
- A GitHub Actions pipeline that deploys to Azure using OIDC — no Azure secrets stored in GitHub
- A PR validation workflow that lints and tests without touching Azure

## File map

| Path | What it is | Rename/replace when adapting? |
|---|---|---|
| `HttpExample/run.ps1` | The function's actual code | **Yes** — this is the example to replace with your logic |
| `HttpExample/function.json` | Trigger/binding config (route, methods, auth level) | **Yes**, if you rename the function or change its route |
| `host.json` | Function App host-level config | No, unless you have a specific reason to |
| `profile.ps1` | Runs once per cold start (module imports, managed identity auth) | Only if your function needs startup logic |
| `requirements.psd1` | Declares PowerShell module dependencies (e.g. `Az`) | Yes, if your function needs additional modules |
| `local.settings.json.example` | Template for local-only config | No — copy it to `local.settings.json`, which is gitignored |
| `tests/HttpExample.Tests.ps1` | Example Pester test | **Yes** — rename and adapt alongside the function it tests |
| `infra/main.bicep` | Provisions Storage Account, App Insights, App Service Plan, Function App | Update `functionAppName` parameter and `tags` |
| `infra/main.parameters.json` | Parameter values for the Bicep deploy | **Yes** — replace the placeholder Function App name |
| `.github/workflows/deploy.yml` | Builds, tests, and deploys to Azure on push to `main` | Only if you change branch names or add environments |
| `.github/workflows/validate-pr.yml` | Lint + test on every PR, no Azure access | Rarely needs changes |
| `docs/LOCAL_DEVELOPMENT.md` | Local setup and `func start` walkthrough | No |
| `docs/DEPLOYMENT.md` | Full OIDC setup with exact `az` commands | No (you'll substitute your own values when running the commands) |
| `docs/INFRASTRUCTURE.md` | Bicep deployment walkthrough | No |
| `docs/TESTING.md` | Pester usage, manual HTTP testing | No |
| `docs/TROUBLESHOOTING.md` | Common errors mapped to fixes | No |
| `LICENSE` | MIT License | **Yes** — replace the placeholder name in the copyright line |

Everything under `docs/` is reference material you read, not files you
edit. The files you actually touch when adapting this template are the
function code itself, the two `infra/` files, and (just once, by hand, in
Azure/GitHub — not in a file) the values described below.

## Setup checklist

Work through this top to bottom once, right after generating the repo.

### 1. Pick two names

- **Azure Function App name** — must be globally unique across all of Azure (e.g. `func-acmewidgets-prod`). It becomes part of `<name>.azurewebsites.net`.
- **GitHub repo identity** (`<OWNER>/<REPO>`) — already set correctly if you used "Use this template," since GitHub created the repo under whatever owner/name you chose. You'll type this string into a couple of `az` CLI commands by hand later — it isn't read from any file.

### 2. Replace placeholders

| File | Change |
|---|---|
| `infra/main.parameters.json` | Replace `REPLACE-WITH-GLOBALLY-UNIQUE-NAME` with your Function App name. Adjust `location` if not `eastus2`. |
| `infra/main.bicep` | Optional: update the `tags` parameter default away from `azure-function-powershell-starter`. |
| `LICENSE` | Replace `<your-github-username>` in the copyright line with your own name or username. |

### 3. Rename the example function

`HttpExample` is a placeholder name. When you know what your function does:

```bash
git mv HttpExample MyRealFunctionName
git mv tests/HttpExample.Tests.ps1 tests/MyRealFunctionName.Tests.ps1
```

Then update:
- `MyRealFunctionName/function.json` — change `"route": "HttpExample"` if you want the URL to match the new name
- `tests/MyRealFunctionName.Tests.ps1` — update the `Describe` block name and the dot-sourced path to point at the renamed `run.ps1`

It's fine to leave `HttpExample` in place temporarily and rename later once the shape of your real function is clearer.

### 4. Provision Azure resources

```bash
az group create --name rg-myfunction --location eastus2

az deployment group create \
  --resource-group rg-myfunction \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json
```

Full detail, including `what-if` previews and teardown: [docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md).

### 5. Set up GitHub → Azure authentication (OIDC)

This is the step that makes `deploy.yml` actually work. It's a one-time
identity setup in Azure plus four values in GitHub — no files in this repo
to edit, just settings in two different places.

**In Azure**, create an app registration, a federated credential trusting
this specific repo, and a Contributor role assignment scoped to your
resource group. Exact `az` commands: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

**In GitHub**, under **Settings → Environments**, create an environment
named `production` (must match `deploy.yml`'s `environment: production`).

Then under **Settings → Secrets and variables → Actions**, set:

| Name | Type | Value |
|---|---|---|
| `AZURE_CLIENT_ID` | Secret | App registration's Application (Client) ID |
| `AZURE_TENANT_ID` | Secret | Your Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Secret | Your Azure subscription ID |
| `AZURE_FUNCTIONAPP_NAME` | Variable | The Function App name from Step 1 |

None of these four values are secret in the sense that they'd let someone
authenticate on their own (OIDC means there's no password or key here at
all) — the three IDs are stored as secrets mainly to keep them out of
workflow logs, while the Function App name is a variable since it's fine
for that one to be visible.

### 6. Push and verify

Push to `main` (or use **Actions → Run workflow** for a manual trigger).
`deploy.yml` builds, tests, and deploys. On success:

```
https://<your-function-app-name>.azurewebsites.net/api/<your-function-route>
```

Calling it requires a function key (locally it doesn't) — see
[docs/TESTING.md](docs/TESTING.md) for retrieving and using it.

### 7. Delete this file's job, not the file

Once deployed, `TEMPLATE.md` has done its job for this instance. You can
delete it, or leave it as historical context — your call. It has no effect
on the pipeline either way.

---

## How the pieces connect

```
Developer machine          GitHub                                Azure
------------------         ------                                -----
func start (local)
git push  ───────────►  validate-pr.yml  (PRs only, no Azure)
                         deploy.yml       (push to main)
                            │
                            │ OIDC token exchange — no stored secret
                            ▼
                         azure/login  →  Azure/functions-action
                                              │
                                              ▼
                                         Function App
                                         Storage Account
                                         Application Insights
```

## Keeping this repo itself as a clean template

If you're maintaining *this* repo as the template (rather than a generated
instance of it), enable the behavior under **Settings → General → Template
repository**. That's the only setting required — it adds the "Use this
template" button for anyone with access and makes every generation a fresh,
independent repo with no ongoing link back here.
