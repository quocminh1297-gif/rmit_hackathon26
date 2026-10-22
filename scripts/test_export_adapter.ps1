$creds = Get-Content "scripts\.cluster_creds.json" -Raw | ConvertFrom-Json
$tidecloakUrl = ([System.Uri]$creds.token_url).GetLeftPart([System.UriPartial]::Authority)
$realmName = "legacyvault"

$res = Invoke-RestMethod -Uri $creds.token_url -Method Post -Body @{
    grant_type = "client_credentials"
    client_id = $creds.client_id
    client_secret = $creds.client_secret
}
$token = $res.access_token

# Get clientId UUID for legacyvault-client
$clients = Invoke-RestMethod -Uri "$tidecloakUrl/admin/realms/$realmName/clients" -Headers @{ Authorization = "Bearer $token" }
$client = $clients | Where-Object { $_.clientId -eq "legacyvault-client" }
Write-Output "Client UUID: $($client.id)"

$exportUrl = "$tidecloakUrl/admin/realms/$realmName/vendorResources/get-installations-provider?clientId=$($client.id)&providerId=keycloak-oidc-keycloak-json"
Write-Output "Export URL: $exportUrl"

try {
    $adapter = Invoke-RestMethod -Uri $exportUrl -Headers @{ Authorization = "Bearer $token" }
    Write-Output "Adapter successfully exported!"
    $adapter | ConvertTo-Json -Depth 5 | Write-Output
    
    # Save to data/tidecloak.json
    New-Item -ItemType Directory -Force -Path "data" | Out-Null
    $adapter | ConvertTo-Json -Depth 10 | Set-Content "data\tidecloak.json"
    Write-Output "Saved to data/tidecloak.json !"
} catch {
    Write-Output "Export error: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Output "Details: $($reader.ReadToEnd())"
    }
}
