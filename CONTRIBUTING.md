# Contributing

## Workflow

1. Create a branch off `main`.
2. Make your changes. If you're adding a new function, scaffold it with
   `func new` (see [docs/LOCAL_DEVELOPMENT.md](docs/LOCAL_DEVELOPMENT.md)) and
   add a matching Pester test under `tests/` (see
   [docs/TESTING.md](docs/TESTING.md)).
3. Run tests and linting locally before pushing:
   ```powershell
   Invoke-Pester -Path ./tests -Output Detailed
   Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning -ExcludeRule PSAvoidUsingWriteHost
   ```
4. Open a pull request against `main`. The `validate-pr.yml` workflow will
   automatically run structure checks, linting, and tests — it does **not**
   deploy anything or touch Azure.
5. Once merged, `deploy.yml` automatically builds and deploys to Azure.

## Commit messages

No strict format is enforced, but clear, present-tense summaries
("Add Name validation to HttpExample", not "added stuff") make the deploy
history easier to scan when troubleshooting a bad release.

## Adding new Azure resources

If a change requires new infrastructure (a new storage container, a Key
Vault, a second function app, etc.), update `infra/main.bicep` in the same
PR as the code that depends on it, and call out the required manual
`az deployment group create` step in the PR description — this starter does
not currently auto-apply infrastructure changes via the pipeline (see the
note at the bottom of [docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md)).

## Reporting issues

Open a GitHub issue describing what you expected vs. what happened, and
include the relevant GitHub Actions run link or Azure Log stream output if
the problem is deployment-related. See
[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) first — many common
failures are already documented there.
