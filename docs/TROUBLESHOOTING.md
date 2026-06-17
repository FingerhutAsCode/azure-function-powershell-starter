# Troubleshooting

## Local development issues

### `func: command not found`

Azure Functions Core Tools isn't installed or isn't on your `PATH`. See
[docs/LOCAL_DEVELOPMENT.md](LOCAL_DEVELOPMENT.md) for install instructions.
Verify with `func --version` — it should print a `4.x` version. If you
installed via npm, confirm the global npm bin directory is on your `PATH`.

### `func start` fails with a storage-related error

You likely don't have Azurite running, or `local.settings.json` doesn't
point at it. Start Azurite in a separate terminal:

```bash
azurite --silent --location ./.azurite --debug ./.azurite/debug.log
```

And confirm `local.settings.json` has:

```json
"AzureWebJobsStorage": "UseDevelopmentStorage=true"
```

### `local.settings.json` not found

This file is gitignored intentionally (it can hold secrets) and won't exist
after a fresh clone. Copy the template:

```bash
cp local.settings.json.example local.settings.json
```

### PowerShell worker fails to start / wrong PowerShell version

Azure Functions PowerShell apps expect PowerShell 7.x. Run `pwsh --version`
to confirm you have 7.4+. If `func start` is picking up an older Windows
PowerShell 5.1 instead, make sure `pwsh` (not `powershell`) resolves first on
your `PATH`.

## GitHub Actions / deployment issues

### `AADSTS70021: No matching federated identity record found`

The `subject` claim on your federated credential doesn't match how the
workflow job is configured. This is the single most common OIDC setup
mistake. Double-check:

- Does your `deploy.yml` job have `environment: production`? Then the
  federated credential subject must be exactly
  `repo:<OWNER>/<REPO>:environment:production`.
- If you removed the `environment:` line from the job, the subject must
  instead be `repo:<OWNER>/<REPO>:ref:refs/heads/main` (or whatever branch
  triggers the job).
- Org/repo name casing and spelling must match exactly.

List your existing federated credentials to check:

```bash
az ad app federated-credential list --id "$APP_ID"
```

### `Insufficient privileges to complete the operation` during deploy

The app registration's service principal doesn't have the `Contributor`
role on the target resource group. Re-run Step 4 from
[docs/DEPLOYMENT.md](DEPLOYMENT.md), double-checking the `--scope` matches
your actual resource group's resource ID.

### `Login failed` / `AADSTS700016: Application not found`

Usually means `AZURE_CLIENT_ID` or `AZURE_TENANT_ID` GitHub secrets don't
match the app registration you actually created, or you copied the
**Object ID** instead of the **Application (Client) ID**. Re-check with:

```bash
az ad app show --id "$APP_ID" --query "{appId:appId, displayName:displayName}"
```

### Workflow succeeds but the function 404s after deployment

- Confirm `AZURE_FUNCTIONAPP_NAME` (GitHub variable) exactly matches the
  deployed Function App's name in Azure — not the resource group name, not
  the full hostname, just the app name.
- Confirm the function's route. This starter uses the default route
  `HttpExample` (from `function.json`'s `"route": "HttpExample"`), reachable
  at `/api/HttpExample`.
- Check **Deployment Center** in the Azure portal for the Function App to
  see the deployment history and any errors during the Kudu zip-deploy step.

### Deployment succeeds but calling the function returns 401/403

You're missing the function key. Locally, `authLevel: function` isn't
enforced, but in Azure it is. See [docs/TESTING.md](TESTING.md) for how to
retrieve and use the key.

### GitHub Actions workflow runs on `windows-latest` and feels slow

PowerShell Azure Functions need a Windows runner because PowerShell function
apps in Azure run on the Windows worker. `windows-latest` runners are
generally slower to provision than `ubuntu-latest`. This is expected and not
a misconfiguration — there isn't a faster supported alternative for this
particular language/runtime combination.

### `az bicep` not found / Bicep CLI errors

Install or update Bicep via the Azure CLI:

```bash
az bicep install
# or, if already installed:
az bicep upgrade
```

### `functionAppName` already taken during Bicep deployment

The name must be globally unique across all Azure customers (it becomes
`<name>.azurewebsites.net`). Pick a more specific name and redeploy.

## Where to look for more detail

- **GitHub Actions logs:** every step's output is visible under the
  **Actions** tab → select the failed run → expand the failing step.
- **Azure Function logs:** Azure Portal → your Function App → **Log stream**
  (near-real-time) or **Application Insights → Logs** (queryable history).
- **Deployment history:** Azure Portal → your Function App → **Deployment
  Center** shows each deployment attempt and its Kudu logs.

If none of the above resolves it, capture the exact error message and the
relevant workflow step name — that's almost always enough to search
Microsoft's [Azure Functions troubleshooting docs](https://learn.microsoft.com/azure/azure-functions/functions-recover-storage-account)
or the [`Azure/functions-action`](https://github.com/Azure/functions-action)
and [`azure/login`](https://github.com/Azure/login) GitHub issue trackers for
a matching report.
