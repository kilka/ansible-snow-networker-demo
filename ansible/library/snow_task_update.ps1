#!/usr/local/bin/pwsh
#WANT_JSON
<#
.SYNOPSIS
  Ansible module to update a ServiceNow Catalog Task (SCTask) record.

.DESCRIPTION
  This module connects to the ServiceNow REST API and sends a PATCH request to update
  a specific sc_task record identified by its sys_id. It dynamically builds the
  request body to only include the parameters (state, assigned_to, work_notes)
  that are explicitly passed from the Ansible playbook.

.PARAMETER api_url
  The base URL for the ServiceNow REST API (e.g., http://localhost:8000).

.PARAMETER sys_id
  The unique 32-character sys_id of the SCTask record to update.

.PARAMETER state
  (Optional) The new state for the task (e.g., "work in progress" or "3").

.PARAMETER assigned_to
  (Optional) The user or queue to assign the task to.

.PARAMETER work_notes
  (Optional) The notes to add to the ticket.
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
    msg     = ""
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
    # 1. Dynamically build the request body with only the parameters that were provided from the playbook.
    #    This makes the module highly reusable for different kinds of updates.
    $body = @{}
    if ($params.PSObject.Properties.Name -contains 'state') { $body.Add("state", $params.state) }
    if ($params.PSObject.Properties.Name -contains 'assigned_to') { $body.Add("assigned_to", $params.assigned_to) }
    if ($params.PSObject.Properties.Name -contains 'work_notes') { $body.Add("work_notes", $params.work_notes) }

    if ($body.Count -eq 0) {
        throw "No update parameters were provided (state, assigned_to, work_notes)."
    }

    $json_body = $body | ConvertTo-Json
    $uri = "$($api_url)/api/now/v2/table/sc_task/$($sys_id)"

    # 2. Call the ServiceNow API with a PATCH request to perform the partial update.
    Invoke-RestMethod -Uri $uri -Method Patch -Body $json_body -ContentType "application/json" -NoProxy

    $output.changed = $true
    $output.msg = "Task $($sys_id) updated successfully."
}
catch {
    # 3. Handle any errors during the API call.
    $output.failed = $true
    $output.msg = "An error occurred while updating task $($sys_id): $($_.Exception.Message)"
}

# 4. Return the final result to Ansible.
Write-Output (ConvertTo-Json -InputObject $output -Depth 5)