#!/usr/local/bin/pwsh
#WANT_JSON
<#
.SYNOPSIS
  Ansible module to query for a client resource in a NetWorker instance by hostname.

.DESCRIPTION
  This module connects to the NetWorker REST API and sends a GET request to the
  /clients endpoint with a hostname filter. It returns the details of the client
  if found.

.PARAMETER api_url
  The base URL for the NetWorker REST API (e.g., http://networker-prod.f3.lan:8001).

.PARAMETER hostname
  The Fully Qualified Domain Name (FQDN) of the client to query for.

.NOTES
  This module treats an HTTP 404 (Not Found) response from the API as a valid,
  successful outcome (found = false), not a module failure. Any other error
  will cause the module to fail.
#>

#region --- Ansible-Specific Argument Parsing ---
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

$argument_path = $args[0]
$params = Get-Content -Raw -Path $argument_path | ConvertFrom-Json
#endregion

# --- Module Parameters ---
$api_url = $params.api_url
$hostname = $params.hostname

# --- Final JSON Output Object ---
$output = @{
    changed = $false
    failed = $false
    found = $false
    msg = ""
    client_details = $null
}

# --- Parameter Validation ---
if (-not $api_url) {
    $output.failed = $true
    $output.msg = "Missing required argument: api_url"
    Write-Output (ConvertTo-Json -InputObject $output -Depth 5)
    exit 1
}
if (-not $hostname) {
    $output.failed = $true
    $output.msg = "Missing required argument: hostname"
    Write-Output (ConvertTo-Json -InputObject $output -Depth 5)
    exit 1
}

# --- Main Module Logic ---
try {
    # 1. Construct the API endpoint URI with the hostname filter.
    $uri = "$($api_url)/nwrestapi/v3/global/clients?hostname=$($hostname)"

    # 2. Call the NetWorker API.
    $response = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -NoProxy

    # 3. Process the response.
    if ($null -ne $response.clients -and $response.clients.Count -gt 0) {
        $output.found = $true
        $output.client_details = $response.clients[0]
        $output.msg = "Client '$($hostname)' found successfully."
    }
    else {
        $output.found = $false
        $output.msg = "Client '$($hostname)' not found."
    }
}
catch {
    # 4. Handle errors. A '404 Not Found' is an expected outcome, not a failure.
    # Any other API or network error is treated as a failure.
    if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::NotFound) {
        $output.failed = $true
        $output.msg = "An error occurred while querying for client '$($hostname)': $($_.Exception.Message)"
    }
    else {
        # This handles the case where the API returns a 404.
        $output.found = $false
        $output.msg = "Client '$($hostname)' not found."
    }
}

# 5. Return the final result to Ansible.
Write-Output (ConvertTo-Json -InputObject $output -Depth 5)