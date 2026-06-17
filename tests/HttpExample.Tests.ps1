#Requires -Module Pester

<#
.SYNOPSIS
    Example Pester tests for the HttpExample function.

.DESCRIPTION
    These tests validate the response-shaping logic of HttpExample/run.ps1
    without needing a running Functions host. They mock the $Request object
    that Azure Functions would normally inject, and call the script directly.

    Run locally with:  Invoke-Pester -Path ./tests
#>

Describe "HttpExample function" {

    BeforeAll {
        # Stub Push-OutputBinding and Write-Host so the script can run outside
        # of the Azure Functions PowerShell worker, and capture what gets pushed.
        function Push-OutputBinding {
            param($Name, $Value)
            $script:LastPushedOutput = $Value
        }
    }

    Context "When a Name is supplied via query string" {
        It "Returns a personalized greeting with HTTP 200" {
            $Request = [PSCustomObject]@{
                Query = @{ Name = "Taylor" }
                Body  = $null
            }

            . "$PSScriptRoot/../HttpExample/run.ps1" -Request $Request -TriggerMetadata $null

            $script:LastPushedOutput.StatusCode | Should -Be 200
            $bodyObject = $script:LastPushedOutput.Body | ConvertFrom-Json
            $bodyObject.message | Should -Match "Taylor"
        }
    }

    Context "When no Name is supplied" {
        It "Returns the generic message with HTTP 200" {
            $Request = [PSCustomObject]@{
                Query = @{}
                Body  = $null
            }

            . "$PSScriptRoot/../HttpExample/run.ps1" -Request $Request -TriggerMetadata $null

            $script:LastPushedOutput.StatusCode | Should -Be 200
            $bodyObject = $script:LastPushedOutput.Body | ConvertFrom-Json
            $bodyObject.message | Should -Match "executed successfully"
        }
    }

    Context "When Name is supplied in the request body instead of query string" {
        It "Falls back to the body and returns a personalized greeting" {
            $Request = [PSCustomObject]@{
                Query = @{}
                Body  = @{ Name = "Morgan" }
            }

            . "$PSScriptRoot/../HttpExample/run.ps1" -Request $Request -TriggerMetadata $null

            $bodyObject = $script:LastPushedOutput.Body | ConvertFrom-Json
            $bodyObject.message | Should -Match "Morgan"
        }
    }
}
