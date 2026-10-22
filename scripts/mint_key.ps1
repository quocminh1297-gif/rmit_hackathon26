$json = Get-Content "scripts\.device_token.json" -Raw | ConvertFrom-Json
$token = $json.access_token

$bodyObj = @{
    name = "tidecloak-legacyvault"
    scopes = @(
        "clusters:write",
        "realms:write",
        "applications:write",
        "realm-users:write",
        "identity-providers:write",
        "clusters:credentials:read",
        "clusters:logs:read",
        "clusters:events:read"
    )
}
$bodyJson = $bodyObj | ConvertTo-Json

try {
    $res = Invoke-RestMethod -Uri "https://app.skycloak.io/api/cli/keys" -Method Post -Headers @{
        "Authorization" = "Bearer $token"
    } -Body $bodyJson -ContentType "application/json"

    $res | ConvertTo-Json | Set-Content "scripts\.api_key.json"
    Write-Output "SUCCESS: API Key minted!"
} catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Output "RESPONSE: $($reader.ReadToEnd())"
    }
}
