$keyJson = Get-Content "scripts\.api_key.json" -Raw | ConvertFrom-Json
$apiKey = $keyJson.full_key
$clusterId = "7db75287-9f08-42a5-b68c-984e886c535f"

$headers = @{
    "API-Key" = $apiKey
    "API-Version" = "2026-06-01.beta"
}

Write-Output "==> Fetching cluster events..."
try {
    $events = Invoke-RestMethod -Uri "https://api.skycloak.io/clusters/$clusterId/events" -Headers $headers -Method Get
    $events | ConvertTo-Json -Depth 5 | Write-Output
} catch {
    Write-Output "Events error: $($_.Exception.Message)"
}

Write-Output "==> Fetching cluster logs..."
try {
    $logs = Invoke-RestMethod -Uri "https://api.skycloak.io/clusters/$clusterId/logs" -Headers $headers -Method Get
    $logs | ConvertTo-Json -Depth 5 | Write-Output
} catch {
    Write-Output "Logs error: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Output "Details: $($reader.ReadToEnd())"
    }
}
