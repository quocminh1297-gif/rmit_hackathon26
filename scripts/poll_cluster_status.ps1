$keyJson = Get-Content "scripts\.api_key.json" -Raw | ConvertFrom-Json
$apiKey = $keyJson.full_key
$clusterId = "7db75287-9f08-42a5-b68c-984e886c535f"

$headers = @{
    "API-Key" = $apiKey
    "API-Version" = "2026-06-01.beta"
}

for ($i = 1; $i -le 60; $i++) {
    try {
        $res = Invoke-RestMethod -Uri "https://api.skycloak.io/clusters/$clusterId" -Headers $headers -Method Get
        Write-Output "Attempt $i (wait 10s): status = $($res.status), url = $($res.url)"
        if ($res.status -eq "available") {
            $res | ConvertTo-Json -Depth 5 | Set-Content "scripts\.cluster_available.json"
            Write-Output "SUCCESS: Cluster is available at $($res.url) !"
            exit 0
        } elseif ($res.status -eq "failed") {
            Write-Output "FATAL: Cluster provisioning failed."
            exit 1
        }
    } catch {
        Write-Output "Poll error: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds 10
}

Write-Output "TIMEOUT: Cluster still not available."
exit 1
