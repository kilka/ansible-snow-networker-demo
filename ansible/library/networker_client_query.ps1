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
$hostname = $params.hostname

# --- Final JSON Output Object ---
$output = @{
    changed = $false
    found = $false
    client_details = $null
}

# --- Module Logic ---
try {
    $uri = "$($api_url)/nwrestapi/v3/global/clients?hostname=$($hostname)"
    $response = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -NoProxy

    if ($null -ne $response.clients -and $response.clients.Count -gt 0) {
        $output.found = $true
        $output.client_details = $response.clients[0]
    }
}
catch {
    # A 404 Not Found is not a failure in this case, it just means the client wasn't found.
    if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::NotFound) {
        $output.failed = $true
        $output.msg = "An error occurred: $($_.Exception.Message)"
    }
}

Write-Output (ConvertTo-Json -InputObject $output -Depth 5)