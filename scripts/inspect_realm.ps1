$creds = Get-Content "scripts\.cluster_creds.json" -Raw | ConvertFrom-Json
$tidecloakUrl = ([System.Uri]$creds.token_url).GetLeftPart([System.UriPartial]::Authority)
$realmName = "legacyvault"

$res = Invoke-RestMethod -Uri $creds.token_url -Method Post -Body @{
    grant_type = "client_credentials"
    client_id = $creds.client_id
    client_secret = $creds.client_secret
}
$token = $res.access_token

Write-Output "==> Identity Providers:"
$idps = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/identity-provider/instances" -Headers @{ Authorization = "Bearer $token" }
$idps | ConvertTo-Json -Depth 3 | Write-Output

Write-Output "==> Components:"
$comps = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/components" -Headers @{ Authorization = "Bearer $token" }
$comps | Select-Object name, providerId, providerType | Format-Table | Out-String | Write-Output

Write-Output "==> Client Scopes:"
$scopes = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/client-scopes" -Headers @{ Authorization = "Bearer $token" }
$scopes | Select-Object name, protocol | Format-Table | Out-String | Write-Output

Write-Output "==> Testing toggle-iga:"
try {
    $iga = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/tide-admin/toggle-iga" -Method Post -Headers @{
        Authorization = "Bearer $token"
        "Content-Type" = "application/x-www-form-urlencoded"
    } -Body "isIGAEnabled=true"
    Write-Output "toggle-iga result:"
    $iga | ConvertTo-Json -Depth 3 | Write-Output
} catch {
    Write-Output "toggle-iga error: $($_.Exception.Message)"
}
