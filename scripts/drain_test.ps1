$creds = Get-Content "scripts\.cluster_creds.json" -Raw | ConvertFrom-Json
$tidecloakUrl = ([System.Uri]$creds.token_url).GetLeftPart([System.UriPartial]::Authority)
$realmName = "legacyvault"

$res = Invoke-RestMethod -Uri $creds.token_url -Method Post -Body @{
    grant_type = "client_credentials"
    client_id = $creds.client_id
    client_secret = $creds.client_secret
}
$token = $res.access_token

$pending = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/iga/change-requests?status=PENDING" -Headers @{ Authorization = "Bearer $token" }
Write-Output "Pending Change Requests count: $($pending.Count)"

$byType = $pending | Group-Object actionType
foreach ($g in $byType) {
    Write-Output "  $($g.Name): $($g.Count)"
}
