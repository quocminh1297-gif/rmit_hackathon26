$keyJson = Get-Content "scripts\.api_key.json" -Raw | ConvertFrom-Json
$apiKey = $keyJson.full_key
$clusterId = "7db75287-9f08-42a5-b68c-984e886c535f"

$headers = @{
    "API-Key" = $apiKey
    "API-Version" = "2026-06-01.beta"
}

$logs = Invoke-RestMethod -Uri "https://api.skycloak.io/clusters/$clusterId/logs" -Headers $headers
Write-Output "Total logs: $($logs.Count)"
$logs | Select-Object -First 15 | ForEach-Object {
    Write-Output "[$($_.timestamp)] [$($_.level)] [$($_.category)] $($_.message)"
}
