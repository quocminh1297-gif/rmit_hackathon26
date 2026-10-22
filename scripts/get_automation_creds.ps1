$keyJson = Get-Content "scripts\.api_key.json" -Raw | ConvertFrom-Json
$apiKey = $keyJson.full_key
$clusterId = "7db75287-9f08-42a5-b68c-984e886c535f"

$headers = @{
    "API-Key" = $apiKey
    "API-Version" = "2026-06-01.beta"
}

try {
    $creds = Invoke-RestMethod -Uri "https://api.skycloak.io/clusters/$clusterId/credentials" -Headers $headers -Method Get
    $creds | ConvertTo-Json -Depth 5 | Set-Content "scripts\.cluster_creds.json"
    Write-Output "Retrieved automation credentials!"
    
    # Get master admin token
    $tokenRes = Invoke-RestMethod -Uri $creds.token_url -Method Post -Body @{
        grant_type = "client_credentials"
        client_id = $creds.client_id
        client_secret = $creds.client_secret
    }
    
    $adminToken = $tokenRes.access_token
    Write-Output "Admin Token obtained successfully!"

    # Probe vendor surface / master realms
    $tidecloakUrl = "https://$clusterId.us.skycloak.io"
    $probe = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms" -Headers @{
        Authorization = "Bearer $adminToken"
    } -Method Get
    Write-Output "TideCloak /admin/realms reachable! Found realms: $($probe.realm -join ', ')"

    # Read-only IGA probe (GAP-066 check)
    try {
        $igaCheck = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/master/iga/change-requests?status=PENDING" -Headers @{
            Authorization = "Bearer $adminToken"
        } -Method Get
        Write-Output "TideCloak IGA vendor surface VERIFIED: HTTP 200 OK!"
    } catch {
        Write-Output "IGA probe result: $($_.Exception.Message)"
    }
} catch {
    Write-Output "Error: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Output "Details: $($reader.ReadToEnd())"
    }
}
