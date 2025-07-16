#!/usr/local/bin/pwsh
#WANT_JSON
#
# Name: networker_client_create.ps1
#
# Ansible module to create a new client record in NetWorker.
#

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
    clientId = $null
}

# --- Module Logic ---
try {
    # Build the request body from the parameters
    $body = @{
        hostname = $hostname
        tags = $tags
        scheduledBackup = $scheduledBackup
        clientDirectEnabled = $clientDirectEnabled
    } | ConvertTo-Json

    $uri = "$($api_url)/nwrestapi/v3/global/clients"

    # Call the NetWorker API with a POST request
    $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" -NoProxy

    $output.changed = $true
    $output.msg = "Client '$($hostname)' created successfully."
    $output.clientId = $response.clientId
}
catch {
    $output.failed = $true
    # Try to get a more specific error message from the API response if it exists
    if ($_.Exception.Response) {
        $error_response = $_.Exception.Response.GetResponseStream()
        $stream_reader = New-Object System.IO.StreamReader($error_response)
        $error_text = $stream_reader.ReadToEnd()
        $output.msg = "Failed to create client '$($hostname)': $($error_text)"
    } else {
        $output.msg = "Failed to create client '$($hostname)': $($_.Exception.Message)"
    }
}

Write-Output (ConvertTo-Json -InputObject $output -Depth 5)