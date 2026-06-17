# Local Development Guide

This guide walks through installing the required tools and running this
function on your own machine before anything touches Azure.

## 1. Prerequisites

You need four things installed locally:

1. **PowerShell 7.4 or later**
2. **Azure Functions Core Tools v4** (the `func` CLI)
3. **Azurite** (local Azure Storage emulator) — Functions need a storage
   connection even to run locally
4. **Visual Studio Code** with the Azure Functions and PowerShell extensions
   (optional but strongly recommended)

> **Note on Core Tools versions:** Microsoft has a newer "Azure Functions CLI
> v5" in preview, but as of this writing it does **not** support PowerShell.
> Use Core Tools **v4** for this project.

### Install PowerShell 7.4+

- **Windows:** `winget install --id Microsoft.PowerShell --source winget`
- **macOS:** `brew install powershell/tap/powershell`
- **Linux:** Follow the [official install docs](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux) for your distribution.

Verify with:

```bash
pwsh --version
```

### Install Azure Functions Core Tools v4

**Windows (npm):**
```powershell
npm install -g azure-functions-core-tools@4 --unsafe-perm true
```

**macOS (Homebrew):**
```bash
brew tap azure/functions
brew install azure-functions-core-tools@4
```

**Linux (npm, all distros):**
```bash
npm install -g azure-functions-core-tools@4 --unsafe-perm true
```

Verify with:

```bash
func --version
# should print a 4.x version
```

### Install Azurite (local storage emulator)

```bash
npm install -g azurite
```

Run it in its own terminal window before starting the function (leave it running):

```bash
azurite --silent --location ./.azurite --debug ./.azurite/debug.log
```

> Alternative: if you use VS Code, the **Azurite extension** can start/stop
> the emulator for you instead of a separate terminal.

### (Optional) VS Code extensions

This repo includes `.vscode/extensions.json` which will prompt you to install:

- `ms-azuretools.vscode-azurefunctions`
- `ms-vscode.powershell`
- `ms-azuretools.vscode-azurestorage`

## 2. Configure local settings

Local-only configuration lives in `local.settings.json`, which is **never
committed to git** (it's in `.gitignore`) because it can contain secrets and
is specific to your machine.

Copy the example file:

```bash
cp local.settings.json.example local.settings.json
```

The default values point `AzureWebJobsStorage` at Azurite
(`UseDevelopmentStorage=true`), which is correct as long as Azurite is
running. If you'd rather use a real Azure Storage account for local testing,
replace that value with the account's connection string — but most people
should stick with Azurite.

## 3. Run the function locally

From the repository root, with Azurite running in another terminal:

```bash
func start
```

You should see output ending with something like:

```
Functions:

        HttpExample: [GET,POST] http://localhost:7071/api/HttpExample

For detailed output, run func with --verbose flag.
```

### Call the function

```bash
# GET with a query string parameter
curl "http://localhost:7071/api/HttpExample?Name=World"

# POST with a JSON body
curl -X POST "http://localhost:7071/api/HttpExample" \
  -H "Content-Type: application/json" \
  -d '{"Name": "World"}'
```

Both should return a JSON response like:

```json
{"message":"Hello, World. This HTTP triggered function executed successfully.","timestamp":"2026-06-17T18:32:01.123Z"}
```

> **Note on auth level:** `function.json` sets `"authLevel": "function"`,
> which means in Azure (not locally) callers would need a function key. Locally,
> `func start` does not enforce this — all requests succeed without a key.
> See [docs/TESTING.md](TESTING.md) for how keys work once deployed.

## 4. Debugging in VS Code

1. Open the repository folder in VS Code.
2. Install the recommended extensions if prompted.
3. Press `F5`, or use the **Run and Debug** panel and select **"Attach to
   PowerShell Functions host"** (defined in `.vscode/launch.json`).
4. VS Code will run `func start` for you and attach the debugger, letting you
   set breakpoints directly in `HttpExample/run.ps1`.

## 5. Editing the function

The function code lives in `HttpExample/run.ps1`. The HTTP route, allowed
methods, and auth level are defined in `HttpExample/function.json`. After
editing either file, stop and restart `func start` to pick up the changes
(binding changes in `function.json` require a restart; PowerShell script
changes are usually picked up automatically, but restarting is the reliable
option).

To add a **new** function:

```bash
func new --name MyNewFunction --template "HTTP trigger" --authlevel "function"
```

This scaffolds a new folder with its own `function.json` and `run.ps1`.

## 6. Running tests

See [docs/TESTING.md](TESTING.md) for full details on the Pester test suite
in `tests/`. Quick version:

```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0.0
Invoke-Pester -Path ./tests -Output Detailed
```

## Next step

Once the function behaves the way you want locally, head to
[docs/INFRASTRUCTURE.md](INFRASTRUCTURE.md) to provision the Azure resources,
then [docs/DEPLOYMENT.md](DEPLOYMENT.md) to set up automated deployment.
