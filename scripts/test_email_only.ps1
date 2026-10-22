$ErrorActionPreference = "Stop"

$creds = Get-Content "scripts\.cluster_creds.json" -Raw | ConvertFrom-Json
$tidecloakUrl = ([System.Uri]$creds.token_url).GetLeftPart([System.UriPartial]::Authority)
$realmName = "legacyvault"

function Get-AdminToken {
    $res = Invoke-RestMethod -Uri $creds.token_url -Method Post -Body @{
        grant_type = "client_credentials"
        client_id = $creds.client_id
        client_secret = $creds.client_secret
    }
    return $res.access_token
}

$token = Get-AdminToken
Write-Output "==> 1. Deleting realm $realmName..."
try {
    Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName" -Method Delete -Headers @{ Authorization = "Bearer $token" }
    Write-Output "    Deleted."
} catch {
    Write-Output "    Note: $($_.Exception.Message)"
}

Start-Sleep -Seconds 3

Write-Output "==> 2. Re-creating realm $realmName..."
$realmJson = Get-Content "scripts\realm.json" -Raw
$token = Get-AdminToken
Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms" -Method Post -Headers @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
} -Body $realmJson
Write-Output "    Created fresh realm."

Write-Output "==> 3. Disabling idp-review-profile..."
$token = Get-AdminToken
$flows = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/authentication/flows/first%20broker%20login/executions" -Headers @{ Authorization = "Bearer $token" }
$rpItem = $flows | Where-Object { $_.providerId -eq "idp-review-profile" } | Select-Object -First 1
if ($rpItem -and $rpItem.authenticationConfig) {
    $cfgBody = '{"alias":"review profile config","config":{"update.profile.on.first.login":"off"}}'
    Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/authentication/config/$($rpItem.authenticationConfig)" -Method Put -Headers @{
        Authorization = "Bearer $token"
        "Content-Type" = "application/json"
    } -Body $cfgBody | Out-Null
    Write-Output "    Disabled."
}

Write-Output "==> 4. Calling setUpTideRealm with ONLY email (no isRagnarokEnabled)..."
$token = Get-AdminToken
$targetUrl = "$tidecloakUrl/admin/realms/$realmName/vendorResources/setUpTideRealm"

& curl.exe -i -X POST $targetUrl `
    -H "Authorization: Bearer $token" `
    -H "Content-Type: application/x-www-form-urlencoded" `
    --data-urlencode "email=quocminh1297@gmail.com"
