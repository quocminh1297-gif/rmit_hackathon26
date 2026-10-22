$keyJson = Get-Content "scripts\.api_key.json" -Raw | ConvertFrom-Json
$apiKey = $keyJson.full_key

$headers = @{
    "API-Key" = $apiKey
    "API-Version" = "2026-06-01.beta"
}

try {
    $res = Invoke-RestMethod -Uri "https://api.skycloak.io/clusters" -Headers $headers -Method Get
    Write-Output "Clusters response:"
    $res | ConvertTo-Json -Depth 5 | Write-Output
} catch {
    Write-Output "Error: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Output "Details: $($reader.ReadToEnd())"
    }
}
