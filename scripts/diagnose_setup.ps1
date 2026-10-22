$creds = Get-Content "scripts\.cluster_creds.json" -Raw | ConvertFrom-Json
$clusterId = "3c9734e9-71f5-4562-af0d-9ee93d8f5438"
$tidecloakUrl = "https://$clusterId.us.skycloak.io"

$res = Invoke-RestMethod -Uri $creds.token_url -Method Post -Body @{
    grant_type = "client_credentials"
    client_id = $creds.client_id
    client_secret = $creds.client_secret
}
$token = $res.access_token

Write-Output "Testing setUpTideRealm..."
$targetUrl = "$tidecloakUrl/admin/realms/legacyvault/vendorResources/setUpTideRealm"

& curl.exe -i -X POST $targetUrl `
    -H "Authorization: Bearer $token" `
    -H "Content-Type: application/x-www-form-urlencoded" `
    --data-urlencode "email=quocminh1297@gmail.com" `
    --data-urlencode "isRagnarokEnabled=true"
