$creds = Get-Content "scripts\.cluster_creds.json" -Raw | ConvertFrom-Json
$tidecloakUrl = ([System.Uri]$creds.token_url).GetLeftPart([System.UriPartial]::Authority)

$res = Invoke-RestMethod -Uri $creds.token_url -Method Post -Body @{
    grant_type = "client_credentials"
    client_id = $creds.client_id
    client_secret = $creds.client_secret
}
$token = $res.access_token

$info = Invoke-RestMethod -Uri "$tidecloakUrl/admin/serverinfo" -Headers @{
    Authorization = "Bearer $token"
}

Write-Output "System Info:"
$info.systemInfo | ConvertTo-Json | Write-Output

Write-Output "Features:"
$info.features | ConvertTo-Json -Depth 3 | Write-Output

Write-Output "Component Types:"
$info.componentTypes.Keys | Write-Output
