$keyJson = Get-Content "scripts\.api_key.json" -Raw | ConvertFrom-Json
$apiKey = $keyJson.full_key

$headers = @{
    "API-Key" = $apiKey
    "API-Version" = "2026-06-01.beta"
}

try {
    $res = Invoke-WebRequest -Uri "https://api.skycloak.io/clusters/supported-versions?type=tidecloak" -Headers $headers -Method Get
    Write-Output "Supported versions: $($res.Content)"
} catch {
    Write-Output "Status: $($_.Exception.Response.StatusCode.value__)"
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    Write-Output "Body: $($reader.ReadToEnd())"
}
