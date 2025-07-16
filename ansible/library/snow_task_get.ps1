#!/usr/local/bin/pwsh
#WANT_JSON
<#
.SYNOPSIS
  Ansible module to get a single ServiceNow Catalog Task (SCTask) by its sys_id.

.DESCRIPTION
  This module connects to the ServiceNow REST API and sends a GET request to retrieve
  a specific sc_task record. It is used for verification steps to check the final
  state of a ticket.

.PARAMETER api_url
  The base URL for the ServiceNow REST API (e.g., http://localhost:8000).

.PARAMETER sys_id
  The unique 32-character sys_id of the SCTask record to retrieve.

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
$sys_id = $params.sys_id

# --- Final JSON Output Object ---
$output = @{
    changed = $false
    failed  = $false
    found   = $false
    msg     = ""
    task_details = $null
}

# --- Parameter Validation ---
if (-not $api_url) {
    $output.failed = $true
    $output.msg = "Missing required argument: api_url"
    Write-Output (ConvertTo-Json -InputObject $output -Depth 5)
    exit 1
}
if (-not $sys_id) {
    $output.failed = $true
    $output.msg = "Missing required argument: sys_id"
    Write-Output (ConvertTo-Json -InputObject $output -Depth 5)
    exit 1
}

# --- Main Module Logic ---
try {
    # 1. Construct the API endpoint URI for a specific task.
    $uri = "$($api_url)/api/now/v2/table/sc_task/$($sys_id)"

    # 2. Call the ServiceNow API.
    $response = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -NoProxy

    # 3. Process the response.
    if ($null -ne $response.result) {
        $output.found = $true
        $output.task_details = $response.result
        $output.msg = "Task '$($sys_id)' found successfully."
    }
    else {
        $output.found = $false
        $output.msg = "Task '$($sys_id)' not found."
    }
}
catch {
    # 4. Handle errors, treating '404 Not Found' as an expected outcome.
    if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::NotFound) {
        $output.failed = $true
        $output.msg = "An error occurred while getting task '$($sys_id)': $($_.Exception.Message)"
    }
    else {
        $output.found = $false
        $output.msg = "Task '$($sys_id)' not found (404)."
    }
}

# 5. Return the final result to Ansible.
Write-Output (ConvertTo-Json -InputObject $output -Depth 5)