using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$name = $Request.Query.Name
if (-not $name) {
    $name = $Request.Body.Name
}

if ($name) {
    $status = [HttpStatusCode]::OK
    $body = @{
        message   = "Hello, $name. This HTTP triggered function executed successfully."
        timestamp = (Get-Date -AsUTC).ToString("o")
    }
}
else {
    $status = [HttpStatusCode]::OK
    $body = @{
        message   = "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response."
        timestamp = (Get-Date -AsUTC).ToString("o")
    }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
#
# [HttpResponseContext] is provided by the Azure Functions PowerShell worker
# at runtime. When this script is dot-sourced outside the worker (e.g. under
# Pester in tests/HttpExample.Tests.ps1), that type isn't loaded, so we fall
# back to a plain hashtable with the same shape - Push-OutputBinding and the
# real Functions host both accept either form.
$responseType = 'HttpResponseContext' -as [type]
$response = if ($responseType) {
    New-Object $responseType -Property @{
        StatusCode = $status
        Headers    = @{ "Content-Type" = "application/json" }
        Body       = ($body | ConvertTo-Json)
    }
}
else {
    @{
        StatusCode = $status
        Headers    = @{ "Content-Type" = "application/json" }
        Body       = ($body | ConvertTo-Json)
    }
}

Push-OutputBinding -Name Response -Value $response
