$keyJson = Get-Content "scripts\.api_key.json" -Raw | ConvertFrom-Json
$apiKey = $keyJson.full_key
$oldClusterId = "3c9734e9-71f5-4562-af0d-9ee93d8f5438"

$headers = @{
    "API-Key" = $apiKey
    "API-Version" = "2026-06-01.beta"
}

Write-Output "==> Deleting old cluster $oldClusterId..."
try {
    Invoke-RestMethod -Uri "https://api.skycloak.io/clusters/$oldClusterId" -Headers $headers -Method Delete
    Write-Output "    Delete request sent."
} catch {
    Write-Output "    Delete error: $($_.Exception.Message)"
}

Start-Sleep -Seconds 5

Write-Output "==> Creating new cluster with version 0.14.17..."
$body = @{
    type = "tidecloak"
    name = "legacyvault-auth"
    size = "small"
    location = "us"
    version = "0.14.17"
} | ConvertTo-Json

$res = Invoke-RestMethod -Uri "https://api.skycloak.io/clusters" -Headers $headers -Method Post -Body $body -ContentType "application/json"
$newId = $res.id
Write-Output "SUCCESS: New cluster created with ID: $newId (version 0.14.17)!"
$res | ConvertTo-Json -Depth 5 | Set-Content "scripts\.cluster_created.json"

Write-Output "==> Polling until available..."
for ($i = 1; $i -le 60; $i++) {
    Start-Sleep -Seconds 10
    try {
        $statusRes = Invoke-RestMethod -Uri "https://api.skycloak.io/clusters/$newId" -Headers $headers -Method Get
        Write-Output "Attempt ${i}: status = $($statusRes.status)"
        if ($statusRes.status -eq "available") {
            $statusRes | ConvertTo-Json -Depth 5 | Set-Content "scripts\.cluster_available.json"
            Write-Output "SUCCESS: Cluster $newId is available at $($statusRes.url)!"
            break
        }
    } catch {
        Write-Output "Poll note: $($_.Exception.Message)"
    }
}

Write-Output "==> Fetching credentials for cluster $newId..."
$creds = Invoke-RestMethod -Uri "https://api.skycloak.io/clusters/$newId/credentials" -Headers $headers -Method Get
$creds | ConvertTo-Json -Depth 5 | Set-Content "scripts\.cluster_creds.json"
Write-Output "Automation credentials saved to scripts\.cluster_creds.json!"
