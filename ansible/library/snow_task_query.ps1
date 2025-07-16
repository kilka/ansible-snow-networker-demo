#!/usr/local/bin/pwsh
#WANT_JSON

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
    task_list = @() # Initialize an empty array for the list of tasks
}

# --- Module Logic ---
try {
    $query = "state=$state`^assignment_group=$assignment_group"
    if ($assigned_to_is_empty) {
        $query += "`^assigned_toISEMPTY"
    }
    $uri = "$($api_url)/api/now/v2/table/sc_task?sysparm_query=$query"

    $response = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -NoProxy

    if ($null -ne $response.result -and $response.result.Count -gt 0) {
        $output.changed = $true
        $output.msg = "Found $($response.result.Count) new task(s) to process."
        # Assign the entire list of tasks to the output
        $output.task_list = $response.result
    }
    else {
        $output.changed = $false
        $output.msg = "No new tasks found in the queue."
    }
}
catch {
    $output.failed = $true
    $output.msg = "An error occurred: $($_.Exception.Message)"
}

Write-Output (ConvertTo-Json -InputObject $output -Depth 5)