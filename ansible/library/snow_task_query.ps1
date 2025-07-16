#!/usr/local/bin/pwsh
#WANT_JSON
<#
.SYNOPSIS
  Ansible module to query for all open and unassigned ServiceNow Catalog Tasks (SCTasks).

.DESCRIPTION
  This module connects to the ServiceNow REST API and queries the sc_task table
  for all records that match the specified state and assignment group, and that
  do not have an individual assigned. It returns a list of all matching tasks.

.PARAMETER api_url
  The base URL for the ServiceNow REST API (e.g., http://localhost:8000).

.PARAMETER state
  The state of the tasks to query for (e.g., "new").

.PARAMETER assignment_group
  The name of the assignment group to query (e.g., "backup team").

.PARAMETER assigned_to_is_empty
  A boolean that, if true, adds a condition to find only unassigned tasks.
#>

#region --- Ansible-Specific Argument Parsing ---
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

$argument_path = $args[0]
$params = Get-Content -Raw -Path $argument_path | ConvertFrom-Json
#endregion

# --- Module Parameters ---
$api_url = $params.api_url
$state = $params.state
$assignment_group = $params.assignment_group
$assigned_to_is_empty = $params.assigned_to_is_empty

# --- Final JSON Output Object ---
$output = @{
    changed = $false
    failed  = $false
    msg     = ""
    task_list = @()
}

# --- Parameter Validation ---
if (-not $api_url) {
    $output.failed = $true
    $output.msg = "Missing required argument: api_url"
    Write-Output (ConvertTo-Json -InputObject $output -Depth 5)
    exit 1
}

# --- Main Module Logic ---
try {
    # 1. Build the ServiceNow sysparm_query string. The backtick ` is used
    #    to escape the ^ character for PowerShell.
    $query = "state=$state`^assignment_group=$assignment_group"
    if ($assigned_to_is_empty) {
        $query += "`^assigned_toISEMPTY"
    }
    $uri = "$($api_url)/api/now/v2/table/sc_task?sysparm_query=$query"

    # 2. Call the ServiceNow API.
    $response = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -NoProxy

    # 3. Process the response.
    if ($null -ne $response.result -and $response.result.Count -gt 0) {
        $output.changed = $true
        $output.msg = "Found $($response.result.Count) new task(s) to process."
        $output.task_list = $response.result
    }
    else {
        $output.changed = $false
        $output.msg = "No new tasks found in the queue."
    }
}
catch {
    # 4. Handle any errors during the API call.
    $output.failed = $true
    $output.msg = "An error occurred while querying ServiceNow: $($_.Exception.Message)"
}

# 5. Return the final result to Ansible.
Write-Output (ConvertTo-Json -InputObject $output -Depth 5)