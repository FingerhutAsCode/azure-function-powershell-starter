# Testing Guide

This project supports two layers of testing: automated unit tests with
[Pester](https://pester.dev) (PowerShell's standard testing framework), and
manual HTTP testing against a running function (local or deployed).

## Automated tests (Pester)

### Install Pester

Windows PowerShell ships with an old Pester version; install a current one
explicitly:

```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0.0
```

### Run the test suite

From the repository root:

```powershell
Invoke-Pester -Path ./tests -Output Detailed
```

This runs `tests/HttpExample.Tests.ps1`, which validates the response-shaping
logic in `HttpExample/run.ps1` (personalized greeting when a name is
supplied via query string or body, generic message when it isn't) **without**
needing a running Functions host. It does this by stubbing out
`Push-OutputBinding` and dot-sourcing `run.ps1` directly with a fake
`$Request` object.

### How the tests work

```powershell
function Push-OutputBinding {
    param($Name, $Value)
    $script:LastPushedOutput = $Value
}
```

Because `run.ps1` calls `Push-OutputBinding` to return its response (rather
than `return`-ing a value, which is how Azure Functions PowerShell bindings
work), the test file defines a local stand-in for that function before
dot-sourcing the script. This lets you assert on what *would have* been sent
back to the caller, fast and without any Azure dependency.

### Writing new tests

When you add a new function (e.g., via `func new`), add a matching test file
under `tests/`, following the same pattern:

```powershell
Describe "MyNewFunction" {
    BeforeAll {
        function Push-OutputBinding {
            param($Name, $Value)
            $script:LastPushedOutput = $Value
        }
    }

    It "does the thing you expect" {
        $Request = [PSCustomObject]@{ Query = @{}; Body = $null }
        . "$PSScriptRoot/../MyNewFunction/run.ps1" -Request $Request -TriggerMetadata $null
        $script:LastPushedOutput.StatusCode | Should -Be 200
    }
}
```

### CI integration

Both `.github/workflows/validate-pr.yml` (on every pull request) and
`.github/workflows/deploy.yml` (before every deployment) run this same
`Invoke-Pester` step. A failing test blocks deployment.

### Linting with PSScriptAnalyzer

`validate-pr.yml` also runs
[PSScriptAnalyzer](https://learn.microsoft.com/powershell/module/psscriptanalyzer/)
against the whole repo to catch common PowerShell issues (unused variables,
unapproved verbs, etc.). Run it locally before pushing:

```powershell
Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning -ExcludeRule PSAvoidUsingWriteHost
```

(`PSAvoidUsingWriteHost` is excluded because `Write-Host` is the normal,
recommended way to emit log output inside Azure Functions PowerShell code —
it gets captured by the Functions logging pipeline.)

## Manual HTTP testing

### Locally

With `func start` running (see [docs/LOCAL_DEVELOPMENT.md](LOCAL_DEVELOPMENT.md)):

```bash
curl "http://localhost:7071/api/HttpExample?Name=World"
```

No function key is needed locally — `authLevel: function` is not enforced
by the local host.

### Against the deployed function

The deployed function **does** enforce its function key. Retrieve it once:

```bash
az functionapp function keys list \
  --resource-group rg-myfunction \
  --name <your-function-app-name> \
  --function-name HttpExample \
  --query default -o tsv
```

Then call it:

```bash
curl "https://<your-function-app-name>.azurewebsites.net/api/HttpExample?Name=World&code=<key>"
```

Or pass the key as a header instead of a query parameter:

```bash
curl "https://<your-function-app-name>.azurewebsites.net/api/HttpExample?Name=World" \
  -H "x-functions-key: <key>"
```

### Testing POST requests

```bash
curl -X POST "http://localhost:7071/api/HttpExample" \
  -H "Content-Type: application/json" \
  -d '{"Name": "World"}'
```

## Load/smoke testing after deployment

For a quick post-deploy smoke test, a simple repeated curl loop is often
enough for a starter project:

```bash
for i in $(seq 1 5); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    "https://<your-function-app-name>.azurewebsites.net/api/HttpExample?Name=Test&code=<key>"
done
```

All five responses should print `200`. For anything beyond a basic smoke
test (sustained load, latency percentiles), use a dedicated tool like
[Azure Load Testing](https://learn.microsoft.com/azure/load-testing/) or
`k6`/`hey` rather than scripting it by hand.

## Monitoring after deployment

Application Insights is provisioned by `infra/main.bicep` and wired up
automatically via the `APPLICATIONINSIGHTS_CONNECTION_STRING` app setting.
After deployment, the **Application Insights → Live Metrics** and
**Application Insights → Logs** views in the Azure portal will show
incoming requests, exceptions, and anything written with `Write-Host` /
`Write-Error` inside `run.ps1`.
