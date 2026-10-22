$ErrorActionPreference = "Stop"

$creds = Get-Content "scripts\.cluster_creds.json" -Raw | ConvertFrom-Json
$tidecloakUrl = ([System.Uri]$creds.token_url).GetLeftPart([System.UriPartial]::Authority)
$realmName = "legacyvault"
$licenseEmail = "quocminh1297@gmail.com"

function Get-AdminToken {
    $res = Invoke-RestMethod -Uri $creds.token_url -Method Post -Body @{
        grant_type = "client_credentials"
        client_id = $creds.client_id
        client_secret = $creds.client_secret
    }
    return $res.access_token
}

Write-Output "==> TideCloak URL: $tidecloakUrl"
$token = Get-AdminToken
Write-Output "==> Obtained Admin Token."

# Check if realm exists
$realms = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms" -Headers @{ Authorization = "Bearer $token" }
Write-Output "==> Existing realms: $(($realms | ForEach-Object { $_.realm }) -join ', ')"

if ($realms | Where-Object { $_.realm -eq $realmName }) {
    Write-Output "==> Realm $realmName exists, deleting for clean setup..."
    Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName" -Method Delete -Headers @{ Authorization = "Bearer $token" }
    Write-Output "    Realm deleted."
    Start-Sleep -Seconds 2
}

Write-Output "==> Creating realm $realmName from scripts/realm.json..."
$realmJson = Get-Content "scripts\realm.json" -Raw
$token = Get-AdminToken
Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms" -Method Post -Headers @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
} -Body $realmJson
Write-Output "    Realm created successfully."

Write-Output "==> Disabling idp-review-profile..."
$token = Get-AdminToken
$flows = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/authentication/flows/first%20broker%20login/executions" -Headers @{ Authorization = "Bearer $token" }
$rpItem = $flows | Where-Object { $_.providerId -eq "idp-review-profile" } | Select-Object -First 1
if ($rpItem -and $rpItem.authenticationConfig) {
    $cfgBody = '{"alias":"review profile config","config":{"update.profile.on.first.login":"off"}}'
    Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/authentication/config/$($rpItem.authenticationConfig)" -Method Put -Headers @{
        Authorization = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body $cfgBody | Out-Null
    Write-Output "    Profile review disabled."
}

Write-Output "==> Calling setUpTideRealm..."
$token = Get-AdminToken
$targetUrl = "$tidecloakUrl/admin/realms/$realmName/vendorResources/setUpTideRealm"
Write-Output "    Target: $targetUrl"

& curl.exe -i -X POST $targetUrl `
    -H "Authorization: Bearer $token" `
    -H "Content-Type: application/x-www-form-urlencoded" `
    --data-urlencode "email=$licenseEmail" `
    --data-urlencode "isRagnarokEnabled=true"
