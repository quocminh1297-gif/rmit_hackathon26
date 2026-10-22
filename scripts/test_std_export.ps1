$creds = Get-Content "scripts\.cluster_creds.json" -Raw | ConvertFrom-Json
$tidecloakUrl = ([System.Uri]$creds.token_url).GetLeftPart([System.UriPartial]::Authority)
$realmName = "legacyvault"

$res = Invoke-RestMethod -Uri $creds.token_url -Method Post -Body @{
    grant_type = "client_credentials"
    client_id = $creds.client_id
    client_secret = $creds.client_secret
}
$token = $res.access_token

$clients = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/clients" -Headers @{ Authorization = "Bearer $token" }
$client = $clients | Where-Object { $_.clientId -eq "legacyvault-client" }

$stdExportUrl = "$tidecloakUrl/admin/realms/$realmName/clients/$($client.id)/installation/providers/keycloak-oidc-keycloak-json"
Write-Output "Standard Export URL: $stdExportUrl"

try {
    $adapter = Invoke-RestMethod -Uri $stdExportUrl -Headers @{ Authorization = "Bearer $token" }
    Write-Output "Standard Keycloak Adapter JSON exported successfully!"
    $adapter | ConvertTo-Json -Depth 5 | Write-Output
} catch {
    Write-Output "Standard export error: $($_.Exception.Message)"
}
