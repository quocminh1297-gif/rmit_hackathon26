$creds = Get-Content "scripts\.cluster_creds.json" -Raw | ConvertFrom-Json
$tidecloakUrl = ([System.Uri]$creds.token_url).GetLeftPart([System.UriPartial]::Authority)
$realmName = "legacyvault"

$res = Invoke-RestMethod -Uri $creds.token_url -Method Post -Body @{
    grant_type = "client_credentials"
    client_id = $creds.client_id
    client_secret = $creds.client_secret
}
$token = $res.access_token

$comps = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/components" -Headers @{ Authorization = "Bearer $token" }
$vk = $comps | Where-Object { $_.providerId -eq "tide-vendor-key" }
Write-Output "tide-vendor-key component:"
$vk | ConvertTo-Json -Depth 5 | Write-Output

$keys = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/keys" -Headers @{ Authorization = "Bearer $token" }
Write-Output "Keys active in realm:"
$keys.keys | Select-Object kid, providerId, type, algorithm, status | Format-Table | Out-String | Write-Output
