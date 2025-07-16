#!/usr/local/bin/pwsh
#WANT_JSON
<#
.SYNOPSIS
  Ansible module to create a new client resource in a NetWorker instance via its REST API.

.DESCRIPTION
  This module connects to the NetWorker REST API and sends a POST request to the
  /clients endpoint to create a new client record with a specified hostname, tags,
  and backup configuration. It returns the new client's ID upon success.

.PARAMETER api_url
  The base URL for the NetWorker REST API (e.g., http://networker-prod.f3.lan:8001).

.PARAMETER hostname
  The Fully Qualified Domain Name (FQDN) of the client to create.

.PARAMETER tags
  An array of strings to tag the client with (e.g., ["mssql"]).

.PARAMETER scheduledBackup
  A boolean that enables or disables scheduled backups for the client.

.PARAMETER clientDirectEnabled
  A boolean that enables or disables Client Direct backups.

.EXAMPLE
  - name: Create client record in NetWorker
    networker_client_create:
      api_url: "http://networker.example.com:8001"
      hostname: "db01.example.com"
      tags: ["mssql"]
      scheduledBackup: true
      clientDirectEnabled: true
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
$tags = $params.tags
$scheduledBackup = $params.scheduledBackup
$clientDirectEnabled = $params.clientDirectEnabled

# --- Final JSON Output Object ---
$output = @{
    changed = $false
    failed  = $false
    msg     = ""
    networker_details = $null
}

# --- Parameter Validation ---
# Best practice: Fail early if required parameters are missing.
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
    # 1. Construct the request body and API endpoint URI.
    $body = @{
        hostname = $hostname
        tags = $tags
        scheduledBackup = $scheduledBackup
        clientDirectEnabled = $clientDirectEnabled
    } | ConvertTo-Json

    $uri = "$($api_url)/nwrestapi/v3/global/clients"

    # 2. Call the NetWorker API to create the client.
    $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" -NoProxy

    $output.changed = $true
    $output.msg = "Client '$($hostname)' created successfully."
    $output.networker_details = @{
        clientId = $response.clientId
    }
}
catch {
    # 3. Handle any errors, attempting to get a specific message from the API response.
    $output.failed = $true
    if ($_.Exception.Response) {
        # This block extracts the detailed error message from the API's response body.
        $error_response = $_.Exception.Response.GetResponseStream()
        $stream_reader = New-Object System.IO.StreamReader($error_response)
        $error_text = $stream_reader.ReadToEnd()
        $output.msg = "Failed to create client '$($hostname)': $($error_text)"
    } else {
        # Fallback to the generic exception message if there's no API response (e.g., a network error).
        $output.msg = "Failed to create client '$($hostname)': $($_.Exception.Message)"
    }
}

# 4. Return the final result to Ansible.
Write-Output (ConvertTo-Json -InputObject $output -Depth 5)