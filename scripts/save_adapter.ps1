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

$adapter = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/clients/$($client.id)/installation/providers/keycloak-oidc-keycloak-json" -Headers @{ Authorization = "Bearer $token" }

$adapter | Add-Member -NotePropertyName "vendorId" -NotePropertyValue "legacyvault" -Force
$adapter | Add-Member -NotePropertyName "homeOrkUrl" -NotePropertyValue "https://ork5.tideprotocol.com" -Force

New-Item -ItemType Directory -Force -Path "data" | Out-Null
$adapter | ConvertTo-Json -Depth 10 | Set-Content "data\tidecloak.json"
Write-Output "Successfully written data\tidecloak.json:"
Get-Content "data\tidecloak.json"
