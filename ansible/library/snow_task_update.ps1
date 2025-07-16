#!/usr/local/bin/pwsh
#WANT_JSON
#
# Name: snow_task_update.ps1
#
# Ansible module to update a ServiceNow SCTask record.
#

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

# --- Module Logic ---
try {
    if (-not $sys_id) {
        throw "sys_id parameter is required."
    }

    # 1. Build the request body with only the parameters that were provided.
    $body = @{}
    if ($params.PSObject.Properties.Name -contains 'state') { $body.Add("state", $params.state) }
    if ($params.PSObject.Properties.Name -contains 'assigned_to') { $body.Add("assigned_to", $params.assigned_to) }
    if ($params.PSObject.Properties.Name -contains 'work_notes') { $body.Add("work_notes", $params.work_notes) }

    if ($body.Count -eq 0) {
        throw "No update parameters were provided (state, assigned_to, work_notes)."
    }

    $json_body = $body | ConvertTo-Json
    $uri = "$($api_url)/api/now/v2/table/sc_task/$($sys_id)"

    # 2. Call the ServiceNow API with a PATCH request.
    $response = Invoke-RestMethod -Uri $uri -Method Patch -Body $json_body -ContentType "application/json" -NoProxy

    $output.changed = $true
    $output.msg = "Task $($sys_id) updated successfully."
}
catch {
    $output.failed = $true
    $output.msg = "An error occurred while updating task $($sys_id): $($_.Exception.Message)"
}

Write-Output (ConvertTo-Json -InputObject $output -Depth 5)