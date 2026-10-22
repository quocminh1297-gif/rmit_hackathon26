$keyJson = Get-Content "scripts\.api_key.json" -Raw | ConvertFrom-Json
$apiKey = $keyJson.full_key

$headers = @{
    "API-Key" = $apiKey
    "API-Version" = "2026-06-01.beta"
}

$body = @{
    type = "tidecloak"
    name = "legacyvault-auth"
    size = "small"
    location = "us"
    version = "0.14.20"
} | ConvertTo-Json

try {
    $res = Invoke-RestMethod -Uri "https://api.skycloak.io/clusters" -Headers $headers -Method Post -Body $body -ContentType "application/json"
    Write-Output "SUCCESS: Cluster creation initiated!"
    $res | ConvertTo-Json -Depth 5 | Set-Content "scripts\.cluster_created.json"
    $res | ConvertTo-Json -Depth 5 | Write-Output
} catch {
    Write-Output "Error: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Output "Details: $($reader.ReadToEnd())"
    }
}
