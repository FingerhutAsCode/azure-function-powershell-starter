# Azure Functions profile.ps1
#
# This profile.ps1 runs every time a new PowerShell worker process starts up, if one exists.
# "cold start" is a term that refers to the first time a function app executes after
# a period of inactivity, and is the only time this script is guaranteed to run.
#
# This is the recommended location for:
#   - Importing modules
#   - Authenticating to Azure with the Function App's Managed Identity (if your
#     function code itself needs to call other Azure services)
#
# By default, this profile will only authenticate to Azure using the Function App's
# system-assigned managed identity when running in Azure (not locally). It is not used
# for *deployment* authentication - that is handled separately by GitHub Actions OIDC.
# See docs/DEPLOYMENT.md for details on how the GitHub Actions workflow authenticates.

if ($env:MSI_SECRET -and (Test-Path -Path "$PSScriptRoot\Modules\Az.Accounts")) {
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity
}

# Uncomment the next line to enable verbose function logging during local testing.
# $VerbosePreference = "Continue"
