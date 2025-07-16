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
$sys_id = $params.sys_id

# --- Final JSON Output Object ---
$output = @{
    changed = $false
    found = $false
    task_details = $null
}

# --- Module Logic ---
try {
    $uri = "$($api_url)/api/now/v2/table/sc_task/$($sys_id)"
    $response = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -NoProxy

    if ($null -ne $response.result) {
        $output.found = $true
        $output.task_details = $response.result
    }
}
catch {
    if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::NotFound) {
        $output.failed = $true
        $output.msg = "An error occurred: $($_.Exception.Message)"
    }
}

Write-Output (ConvertTo-Json -InputObject $output -Depth 5)